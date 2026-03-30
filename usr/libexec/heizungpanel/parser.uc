//#!/usr/bin/ucode
'use strict';

import { fdopen } from "fs";

let CAN_IF      = getenv("CAN_IF") || "can0";
let CAN_BITRATE = getenv("CAN_BITRATE") || "";
let EMIT_MS     = int(getenv("EMIT_MS") || "50");   // 50ms => 20 Hz

// stdin (fd 0) is the pipe stream when invoked as: candump ... | ucode parser.uc
let input = fdopen(0, "r");
let out   = fdopen(1, "w");

let state = {
    ts_ms: 0,
    can_if: CAN_IF,
    can_bitrate: CAN_BITRATE,
    line1: "                ",
    line2: "                ",
    flags16: "----",
    last_1f5: ""
};

let last_emit_ms = 0;

// clock() returns [seconds, microseconds] on OpenWrt ucode builds
function now_ms() {
    let t = clock();
    if (!t) return 0;
    return (t[0] * 1000) + int(t[1] / 1000);
}

function emit(force) {
    let tms = now_ms();
    if (!force && EMIT_MS > 0 && (tms - last_emit_ms) < EMIT_MS)
        return;

    state.ts_ms = tms;

    // newline is CRITICAL for mosquitto_pub -l (line mode)
    out.write(sprintf("%J\n", state));
    if (out.flush) out.flush();

    last_emit_ms = tms;
}

function hexbyte_to_char(h) {
    let v = int("0x" + h);
    if (v >= 32 && v <= 126)
        return chr(v);
    return " ";
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

    let id = f.id;
    let data = f.hex;

    // ---- FLAGS (0x321) ----
    if (id == "321" && length(data) >= 4) {
        state.flags16 = substr(data, 0, 4);
        emit(false);
        continue;
    }

    // ---- DEBUG (0x1F5) ----
    if (id == "1F5") {
        state.last_1f5 = data;
        emit(false);
        continue;
    }

    // ---- LCD sniff (0x320) ----
    if (id == "320" && length(data) >= 8) {
        // use bytes 2..4 => positions 2,4,6 in the hex string
        let b1 = substr(data, 2, 2);
        let b2 = substr(data, 4, 2);
        let b3 = substr(data, 6, 2);

        let txt =
            hexbyte_to_char(b1) +
            hexbyte_to_char(b2) +
            hexbyte_to_char(b3);

        state.line1 = substr(state.line1 + txt, -16);
        emit(false);
        continue;
    }

    // Optional: heartbeat even on other frames (still rate-limited)
    // emit(false);
}

// EOF
emit(true);
