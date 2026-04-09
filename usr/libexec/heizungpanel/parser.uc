//#!/usr/bin/ucode
'use strict';

import { fdopen } from "fs";

let CAN_IF      = getenv("CAN_IF") || "can0";
let CAN_BITRATE = getenv("CAN_BITRATE") || "";
let EMIT_MS     = int(getenv("EMIT_MS") || "50");   // 50ms => 20 Hz
let PAIR_WINDOW = int(getenv("PAIR_WINDOW") || "80"); // frames between 0x258 and matching 0x259

// stdin (fd 0) is the pipe stream when invoked as: candump ... | ucode parser.uc
let input = fdopen(0, "r");
let out   = fdopen(1, "w");

let lcd = [];
for (let i = 0; i < 32; i++)
    lcd[i] = " ";

let flag_stats = {};
for (let i = 0; i < 16; i++) {
    flag_stats[sprintf("%02d", i)] = {
        total_hits: 0,
        episodes: 0,
        max_streak: 0,
        current_streak: 0,
        last_active: false
    };
}

let pending_258 = {};
let latest_pairs = [];
let pair_seen = {};

let state = {
    ts_ms: 0,
    can_if: CAN_IF,
    can_bitrate: CAN_BITRATE,
    source_frame: 0,
    line1: "                ",
    line2: "                ",
    flags16: "----",
    active_bits: [],
    bit_roles: {},
    pairing_258_259: {
        observed_indices: [],
        latest_pairs: []
    },
    confidence: {
        lcd_320: "likely",
        flags_321: "likely",
        pairing_258_259: "likely"
    },
    invariants: {
        flags_single_active_low_ratio: 0,
        offsets_outside_expected: 0,
        unmatched_258: 0
    },
    anomalies: [],
    last_1f5: ""
};

let metrics = {
    frame_no: 0,
    flags_frames: 0,
    flags_single_active: 0,
    offsets_outside_expected: 0,
    unmatched_258: 0
};

let last_emit_ms = 0;

// clock() returns [seconds, microseconds] on OpenWrt ucode builds
function now_ms() {
    let t = clock();
    if (!t) return 0;
    return (t[0] * 1000) + int(t[1] / 1000);
}

function active_bits_from_flags(hex16) {
    let bits = [];
    let v = int("0x" + hex16);

    for (let b = 0; b < 16; b++) {
        // Active low: bit = 0 is active
        if ((v & (1 << b)) == 0)
            push(bits, b);
    }

    return bits;
}

function role_from_stats(s) {
    if (s.total_hits == 0)
        return { role: "unknown", confidence: "unknown" };

    if (s.max_streak <= 2)
        return { role: "event_button", confidence: "likely" };

    return { role: "status_latch", confidence: "likely" };
}

function refresh_bit_roles() {
    let out_roles = {};

    for (let i = 0; i < 16; i++) {
        let key = sprintf("%02d", i);
        let s = flag_stats[key];
        let r = role_from_stats(s);
        out_roles[key] = {
            role: r.role,
            confidence: r.confidence,
            total_hits: s.total_hits,
            episodes: s.episodes,
            max_streak: s.max_streak
        };
    }

    state.bit_roles = out_roles;
}

function refresh_lcd_lines() {
    state.line1 = "";
    state.line2 = "";

    for (let i = 0; i < 16; i++)
        state.line1 += lcd[i];
    for (let i = 16; i < 32; i++)
        state.line2 += lcd[i];
}

function refresh_invariants() {
    state.invariants.flags_single_active_low_ratio =
        metrics.flags_frames > 0 ? (metrics.flags_single_active / metrics.flags_frames) : 0;
    state.invariants.offsets_outside_expected = metrics.offsets_outside_expected;
    state.invariants.unmatched_258 = metrics.unmatched_258;
}

function refresh_pairing_state() {
    let idx = [];
    for (let k in pair_seen)
        push(idx, k);

    // stable-ish order for UI/debug readability
    idx = sort(idx);

    state.pairing_258_259 = {
        observed_indices: idx,
        latest_pairs: latest_pairs
    };
}

function emit(force) {
    let tms = now_ms();
    if (!force && EMIT_MS > 0 && (tms - last_emit_ms) < EMIT_MS)
        return;

    state.ts_ms = tms;
    state.source_frame = metrics.frame_no;

    refresh_lcd_lines();
    refresh_bit_roles();
    refresh_pairing_state();
    refresh_invariants();

    // newline is CRITICAL for mosquitto_pub -l (line mode)
    out.write(sprintf("%J\n", state));
    if (out.flush) out.flush();

    last_emit_ms = tms;
}

function hexbyte_to_char(h) {
    let v = int("0x" + h);

    // seen in dumps as degree/special char
    if (h == "DF")
        return "°";

    // observed LCD charset extensions in field dumps
    if (h == "E2")
        return "ß";
    if (h == "F5")
        return "ü";
    if (h == "E1")
        return "ä";
    if (h == "EF")
        return "ö";

    if (v >= 32 && v <= 126)
        return chr(v);

    return " ";
}

function lcd_index_from_offset(off) {
    // canonical HD44780 offsets
    if (off >= 0x00 && off <= 0x0F)
        return off;

    if (off >= 0x40 && off <= 0x4F)
        return 16 + (off - 0x40);

    // observed occasional extension chunks (e.g. 0x10..0x1F)
    if (off >= 0x10 && off <= 0x1F)
        return off;

    if (off >= 0x50 && off <= 0x5F)
        return 16 + (off - 0x50);

    return -1;
}

function add_anomaly(msg) {
    // avoid unbounded growth
    if (length(state.anomalies) >= 20)
        shift(state.anomalies);

    push(state.anomalies, {
        frame: metrics.frame_no,
        message: msg
    });
}

// Parse both candump formats and return { id, hex } or null
function parse_frame(line) {
    // Format A: "... 320#0D202E20"
    let m = match(line, /([0-9A-Fa-f]+)#([0-9A-Fa-f]+)/);
    if (m) {
        return {
            id: uc(m[1]),
            hex: uc(m[2])
        };
    }

    // Format B: "can0  320   [4]  09 20 2E 20"
    m = match(line, /^\s*\S+\s+([0-9A-Fa-f]+)\s+\[\s*(\d+)\s*\]\s+(.+)\s*$/);
    if (!m)
        return null;

    let id = uc(m[1]);
    let tail = m[3];

    // Extract hex bytes from tail
    let bytes = [];
    for (let b in matchall(tail, /([0-9A-Fa-f]{2})/g))
        push(bytes, uc(b[1]));

    if (!length(bytes))
        return null;

    // Join into one hex string like "09202E20"
    let hex = "";
    for (let i = 0; i < length(bytes); i++)
        hex += bytes[i];

    return { id: id, hex: hex };
}

let line;
while ((line = input.read("line")) != null) {

    let f = parse_frame(line);
    if (!f)
        continue;

    metrics.frame_no++;

    let id = f.id;
    let data = f.hex;

    // ---- FLAGS (0x321) ----
    if (id == "321" && length(data) >= 4) {
        let flags = substr(data, 0, 4);
        state.flags16 = flags;
        state.active_bits = active_bits_from_flags(flags);

        metrics.flags_frames++;
        if (length(state.active_bits) == 1)
            metrics.flags_single_active++;

        for (let i = 0; i < 16; i++) {
            let key = sprintf("%02d", i);
            let s = flag_stats[key];
            let active = ((int("0x" + flags) & (1 << i)) == 0);

            if (active) {
                s.total_hits++;
                s.current_streak++;
                if (!s.last_active)
                    s.episodes++;
                if (s.current_streak > s.max_streak)
                    s.max_streak = s.current_streak;
            }
            else {
                s.current_streak = 0;
            }

            s.last_active = active;
            flag_stats[key] = s;
        }

        emit(false);
        continue;
    }

    // ---- DEBUG (0x1F5) ----
    if (id == "1F5") {
        state.last_1f5 = data;
        emit(false);
        continue;
    }

    // ---- 0x258 / 0x259 index pairing ----
    if ((id == "258" || id == "259") && length(data) >= 2) {
        let idx = substr(data, 0, 2);

        if (id == "258") {
            pending_258[idx] = {
                frame: metrics.frame_no,
                data: data
            };
            pair_seen[idx] = true;
        }
        else {
            let p = pending_258[idx];
            if (p && (metrics.frame_no - p.frame) <= PAIR_WINDOW) {
                push(latest_pairs, {
                    index: idx,
                    frame_258: p.frame,
                    frame_259: metrics.frame_no,
                    delta_frames: metrics.frame_no - p.frame,
                    data_258: p.data,
                    data_259: data,
                    confidence: "likely"
                });

                if (length(latest_pairs) > 20)
                    shift(latest_pairs);

                delete pending_258[idx];
                pair_seen[idx] = true;
            }
            else {
                metrics.unmatched_258++;
                add_anomaly(sprintf("unmatched 0x259 for index %s", idx));
            }
        }

        emit(false);
        continue;
    }

    // ---- LCD (0x320) ----
    if (id == "320" && length(data) >= 4) {
        let off_hex = substr(data, 0, 2);
        let off = int("0x" + off_hex);
        let base = lcd_index_from_offset(off);

        if (base < 0) {
            metrics.offsets_outside_expected++;
            add_anomaly(sprintf("0x320 offset outside expected set: 0x%s", off_hex));
            emit(false);
            continue;
        }

        let p = 2;
        let pos = base;
        while ((p + 2) <= length(data) && pos < 32) {
            let b = substr(data, p, 2);
            lcd[pos] = hexbyte_to_char(b);
            p += 2;
            pos++;
        }

        emit(false);
        continue;
    }

    // Optional: heartbeat even on other frames (still rate-limited)
    // emit(false);
}

// EOF
emit(true);
