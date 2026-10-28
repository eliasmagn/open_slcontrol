'use strict';
'require view';
'require fs';

function el(tag, attrs, children) {
  var n = document.createElement(tag);
  if (attrs) Object.keys(attrs).forEach(function(k) {
    if (k === 'class') n.className = attrs[k];
    else if (k === 'html') n.innerHTML = attrs[k];
    else n.setAttribute(k, attrs[k]);
  });
  (children || []).forEach(function(c) {
    if (typeof c === 'string') n.appendChild(document.createTextNode(c));
    else if (c) n.appendChild(c);
  });
  return n;
}

function clampPollInterval(ms) {
  var v = parseInt(ms, 10);
  if (isNaN(v)) return 500;
  if (v < 250) return 250;
  if (v > 10000) return 10000;
  return v;
}

function pad20(s) {
  return String(s || '').padEnd(20, ' ').slice(0, 20);
}

function hex2dec(h) {
  var v = parseInt(h, 16);
  return isNaN(v) ? -1 : v;
}

function lcdIndex(off) {
  if (off >= 0x00 && off <= 0x13) return off;
  if (off >= 0x40 && off <= 0x53) return 20 + (off - 0x40);
  return -1;
}

function byteToChar(h) {
  h = String(h || '').toUpperCase();
  if (h === 'DF') return '°';
  if (h === 'E2') return 'ß';
  if (h === 'F5') return 'ü';
  if (h === 'E1') return 'ä';
  if (h === 'EF') return 'ö';
  var v = hex2dec(h);
  if (v >= 32 && v <= 126) return String.fromCharCode(v);
  return ' ';
}


function normalizeCanId(id) {
  var n = String(id || '').toUpperCase().replace(/^0+/, '');
  return n || '0';
}

function parseCandump(line) {
  var m = line.match(/(?:^|\s)([0-9A-Fa-f]{1,8})#((?:[0-9A-Fa-f]{2}){1,8})(?=\s|$)/);
  if (m) return { id: normalizeCanId(m[1]), data: m[2].toUpperCase() };

  m = line.match(/(^|[ \t])([0-9A-Fa-f]+)[ \t]+\[[ \t]*(\d+)[ \t]*\][ \t]+(.+)[ \t]*$/);
  if (!m) return null;

  var id = normalizeCanId(m[2]);
  var want = parseInt(m[3], 10) || 0;
  var tail = m[4] || '';
  var q = tail.indexOf("'");
  if (q >= 0) tail = tail.slice(0, q);
  var payload = tail.trim();
  if (!/^[0-9A-Fa-f]{2}(?:\s+[0-9A-Fa-f]{2})*$/.test(payload)) return null;
  var bytes = payload.split(/\s+/);
  if (want < 1 || want > 8 || bytes.length !== want) return null;

  return { id: id, data: bytes.join('').toUpperCase() };
}

function parseLedMap83(rawMap) {
  var out = {};
  var src = String(rawMap || '');
  src.split(',').forEach(function(entry) {
    var s = String(entry || '').trim();
    if (!s) return;
    var m = s.match(/^([0-9A-Fa-f]{2})\s*:\s*([0-9A-Fa-f]{4})$/);
    if (!m) return;
    out[m[1].toUpperCase()] = m[2].toUpperCase();
  });
  return out;
}

/* Einzige Wahrheit fuer Modus-Flags -> Name/Klasse. Welche 83xx-Statusbytes auf
 * welche Flags mappen, steht ausschliesslich in UCI (led_map_83); welche
 * Sende-Codes welche Flags erwarten, ausschliesslich in UCI (mapping_*).
 * Defaults leben nur in der ausgelieferten /etc/config/heizungpanel. */
var MODE_META = {
  '7FFF': { screenClass: 'dauer', modeName: 'Dauerbetrieb' },
  'BFFF': { screenClass: 'uhr', modeName: 'Uhrzeitbetrieb' },
  'DFFF': { screenClass: 'boiler', modeName: 'Boilerbetrieb' },
  'EFFF': { screenClass: 'uhr_boiler', modeName: 'Uhr+Boilerbetrieb' },
  'F7FF': { screenClass: 'aussen_reg', modeName: 'Außentemperatur-Regelung' },
  'FBFF': { screenClass: 'pruef', modeName: 'Prüfbetrieb' },
  'FDFF': { screenClass: 'hand', modeName: 'Handbetrieb' }
};

function decodeDisplayStatus83(payloadHex, ledMap83, powerEinWhenBit7Clear) {
  var raw = String(payloadHex || '').toUpperCase();
  var modeFlags16 = (ledMap83 && ledMap83[raw.slice(0, 2)]) ? ledMap83[raw.slice(0, 2)] : null;
  var d = (modeFlags16 && MODE_META[modeFlags16]) ? MODE_META[modeFlags16] : {};

  /* Status-First-Byte: Bit 7 entscheidet Ein/Aus (kein Folgebyte). */
  var statusByte = hex2dec(raw.slice(0, 2));
  var inferredPower = { powerEin: 'unknown', powerAus: 'unknown' };
  if (statusByte >= 0) {
    var bit7Set = (statusByte & 0x80) === 0x80;
    if ((powerEinWhenBit7Clear && !bit7Set) || (!powerEinWhenBit7Clear && bit7Set)) {
      inferredPower.powerEin = 'on';
      inferredPower.powerAus = 'off';
    } else {
      inferredPower.powerEin = 'off';
      inferredPower.powerAus = 'on';
    }
  }

  return {
    raw: raw || '--',
    screenClass: d.screenClass || 'unknown',
    modeFlags16: modeFlags16,
    modeName: d.modeName || null,
    powerEin: inferredPower.powerEin,
    powerAus: inferredPower.powerAus,
    note: 'LEDs/Modus werden live aus 0x320 83xx gelesen (UCI-konfigurierbar); Ein/Aus via Bit7-Mapping.'
  };
}

/* mapping_*: leer ODER fehlend deaktiviert den Sende-Code (kein Fallback-Truth
 * im UI). Gueltige Werte sind exakt 4 Hex-Zeichen. */
function normMapping(v) {
  var s = String(v == null ? '' : v).toUpperCase();
  return (/^[0-9A-F]{4}$/.test(s)) ? s : '';
}

/* Explizite 0/1-Werte aus config.sh duerfen nicht durch ||-Fallbacks
 * ueberschrieben werden; nur fehlende/ungueltige Werte fallen auf den
 * sicheren Default (write_mode=0, publish_raw=1). */
function normBool(v, dflt) {
  if (v === 0 || v === '0') return 0;
  if (v === 1 || v === '1') return 1;
  return dflt;
}

return view.extend({
  load: function() {
    return fs.exec('/usr/libexec/heizungpanel/config.sh', []).then(function(res) {
      if (!res || res.code !== 0)
        return { poll_interval_ms: 500, write_mode: 0, publish_raw: 1, stream_token: '', led_map_83: '', led_power_ein_when_bit7_clear: 1 };

      try {
        var cfg = JSON.parse((res.stdout || '').trim() || '{}');
        return {
          poll_interval_ms: clampPollInterval(cfg.poll_interval_ms),
          write_mode: normBool(cfg.write_mode, 0),
          publish_raw: normBool(cfg.publish_raw, 1),
          stream_token: cfg.stream_token || '',
          led_map_83: cfg.led_map_83 || '',
          led_power_ein_when_bit7_clear: normBool(cfg.led_power_ein_when_bit7_clear, 1),
          mapping_dauer: normMapping(cfg.mapping_dauer),
          mapping_uhr: normMapping(cfg.mapping_uhr),
          mapping_boiler: normMapping(cfg.mapping_boiler),
          mapping_uhr_boiler: normMapping(cfg.mapping_uhr_boiler),
          mapping_aussen_reg: normMapping(cfg.mapping_aussen_reg),
          mapping_pruef: normMapping(cfg.mapping_pruef),
          mapping_hand: normMapping(cfg.mapping_hand)
        };
      } catch (e) {
        return {
          poll_interval_ms: 500,
          write_mode: 0,
          publish_raw: 1,
          stream_token: '',
          led_map_83: '',
          led_power_ein_when_bit7_clear: 1
        };
      }
    }).catch(function() {
      return {
        poll_interval_ms: 500,
        write_mode: 0,
        publish_raw: 1,
        stream_token: '',
        led_map_83: '',
        led_power_ein_when_bit7_clear: 1
      };
    });
  },

  render: function(cfg) {
    cfg = cfg || {};
    var self = this;

    /* LuCI ruft render einmal pro Seitenleben; falls die View dennoch erneut
     * gerendert wird, gibt der alte Render-Durchlauf seine Ressourcen ab. */
    if (self && typeof self._heizungDispose === 'function') {
      self._heizungDispose();
    }
    var alive = true;

    var streamToken = cfg.stream_token || '';
    var sendEnabled = Number(cfg.write_mode) === 1;
    var publishRawEnabled = Number(cfg.publish_raw) !== 0;
    var ledMap83 = parseLedMap83(cfg.led_map_83 || '');
    var powerEinWhenBit7Clear = Number(cfg.led_power_ein_when_bit7_clear) !== 0;

    var style = el('style', { html: '.hp-wrap{max-width:760px}.hp-panel{background:#3b3b3b;border-radius:10px;padding:18px;color:#eee}.hp-display{background:#0b0f16;border:2px solid #cfcfcf;border-radius:8px;padding:10px 12px;margin:0 auto 14px auto;width:96%;font-family:monospace}.l{white-space:pre;color:#74d3ff;font-size:18px}.l.dim{color:#2f4b5f}.hp-status,.hp-sub{font-size:12px}.hp-grid{display:grid;grid-template-columns:1fr 1.2fr;gap:14px}.hp-left,.hp-right{background:rgba(255,255,255,.04);border-radius:10px;padding:12px}.hp-key{background:#d9d9d9;color:#222;border-radius:6px;border:1px solid #bfbfbf;cursor:pointer;font-weight:700}.hp-keygrid{display:grid;grid-template-columns:70px 70px 70px;grid-template-rows:44px 44px 44px;gap:10px;justify-content:center}.hp-power{display:flex;flex-direction:column;gap:8px;margin-top:10px}.hp-power-row{display:flex;justify-content:center;align-items:center;gap:10px}.hp-power .hp-key{min-width:110px;height:36px}.hp-modes{display:flex;flex-direction:column;gap:10px}.hp-mode{display:grid;grid-template-columns:1fr auto;align-items:center;gap:12px;padding:10px;border-radius:8px;background:rgba(255,255,255,.06)}.hp-mode-actions{display:flex;align-items:center;gap:10px;min-width:96px;justify-content:flex-end}.hp-led{width:12px;height:12px;border-radius:50%;background:#555;border:1px solid #999;flex:0 0 12px}.hp-mode-btn{width:74px;height:32px}.hp-led.on{background:#ffd54a}.hp-led.power.on{background:#9fff82}.hp-led.power.unknown{background:#6e7f91}.hp-status.ok{color:#97e493}.hp-status.warn{color:#ffd166}.hp-status.err{color:#ff8a80}.hp-inline-msg{min-height:20px;font-size:12px}.hp-inline-msg.ok{color:#97e493}.hp-inline-msg.warn{color:#ffd166}.hp-inline-msg.err{color:#ff8a80}.hp-key:focus-visible,.hp-mode-btn:focus-visible,.hp-send-switch:focus-visible{outline:2px solid #74d3ff;outline-offset:2px}@media (max-width:640px){.hp-grid{grid-template-columns:1fr}.hp-wrap{max-width:100%}}' }, []);

    var line1 = el('div', { class: 'l dim' }, ['                    ']);
    var line2 = el('div', { class: 'l dim' }, ['                    ']);
    var status = el('div', { class: 'hp-status warn' }, ['Status: Warte auf Live-Daten (raw) ...']);
    var lastUpdate = el('div', { class: 'hp-sub' }, ['Letzte Aktualisierung: n/a']);
    var modeHint = el('div', { class:'hp-sub' }, ['Betriebsart: n/a']);
    var displayStatusHint = el('div', { class:'hp-sub' }, ['Displaystatus: n/a']);
    var transientHint = el('div', { class:'hp-sub' }, ['Letztes Bedienereignis: n/a']);

    var actionFeedback = el('div', { class:'hp-inline-msg', 'aria-live':'polite' }, ['']);

    var display = el('div', { class: 'hp-display' }, [
      el('div', { class: 'hp-sub' }, ['LCD 2x20 Live-Anzeige (Raw-first im Browser)']),
      line1, line2, modeHint, displayStatusHint, transientHint, status, lastUpdate
    ]);

    var expectedModeBySendCode = {
      dauer: normMapping(cfg.mapping_dauer),
      uhr: normMapping(cfg.mapping_uhr),
      boiler: normMapping(cfg.mapping_boiler),
      uhr_boiler: normMapping(cfg.mapping_uhr_boiler),
      aussen_reg: normMapping(cfg.mapping_aussen_reg),
      pruef: normMapping(cfg.mapping_pruef),
      hand: normMapping(cfg.mapping_hand)
    };
    var pendingModeAck = null;

    /* Nachrichten-Slot mit Generations-Schutz: ein alter Clear-Timer darf eine
     * neuere Meldung nicht mehr ausblenden. */
    var feedbackGen = 0;
    function showActionFeedback(level, text, timeoutMs) {
      var gen = ++feedbackGen;
      actionFeedback.className = 'hp-inline-msg ' + (level || 'ok');
      actionFeedback.textContent = text || '';
      if (timeoutMs > 0) {
        window.setTimeout(function() {
          if (gen !== feedbackGen) return;
          actionFeedback.className = 'hp-inline-msg';
          actionFeedback.textContent = '';
        }, timeoutMs);
      }
    }

    /* press.sh Exit-Codes: 2=write_mode aus, 3=Code unbekannt, 4=Mapping fehlt,
     * 5=cansend-Fehler, 6=cansend fehlt, 7=ungueltiges Mapping. */
    function sendFailureText(code, cmd) {
      if (code === 2) return 'Senden verweigert: write_mode=0 (Backend)';
      if (code === 3) return 'Befehl nicht unterstuetzt: ' + cmd;
      if (code === 4) return 'Mapping fuer "' + cmd + '" nicht hinterlegt (uci mapping_' + cmd + ')';
      if (code === 5) return 'CAN-Send fehlgeschlagen (Interface/Bus)';
      if (code === 6) return 'cansend nicht verfuegbar';
      if (code === 7) return 'Ungueltiges Mapping fuer "' + cmd + '" konfiguriert';
      return 'Senden fehlgeschlagen (Exit ' + code + ')';
    }

    var sendButtons = [];
    var sendInFlight = false;
    function setSendControlsEnabled(enabled) {
      sendButtons.forEach(function(b) { b.disabled = !enabled; });
    }

    function runSend(code) {
      if (!sendEnabled || sendInFlight) return;
      pendingModeAck = null;
      sendInFlight = true;
      setSendControlsEnabled(false);
      function finish() {
        sendInFlight = false;
        setSendControlsEnabled(sendEnabled);
      }
      fs.exec('/usr/libexec/heizungpanel/press.sh', [code]).then(function(res) {
        finish();
        if (res && res.code === 0) {
          showActionFeedback('ok', 'Befehl gesendet: ' + code, 1200);
          if (expectedModeBySendCode[code]) {
            pendingModeAck = { code: code, expected_flags: expectedModeBySendCode[code], deadline: Date.now() + 8000, afterStatus: status83Seq };
          }
          return;
        }
        var c = res ? res.code : -1;
        showActionFeedback(c === 4 ? 'warn' : 'err', sendFailureText(c, code), c === 4 ? 2600 : 3500);
      }).catch(function(err) {
        finish();
        showActionFeedback('err', 'Sende-Fehler: ' + err, 3500);
      });
    }

    function btn(txt, code) {
      var b = el('button', { class: 'hp-key', type: 'button' }, [txt]);
      b.disabled = !sendEnabled;
      b.addEventListener('click', function() { if (sendEnabled) runSend(code); });
      sendButtons.push(b);
      return b;
    }

    var keygrid = el('div', { class: 'hp-keygrid' }, [el('div', {}, []), btn('Z','z'), el('div', {}, []), btn('-','minus'), btn('Quit','quit'), btn('+','plus'), el('div', {}, []), btn('V','v'), el('div', {}, [])]);
    var sendSwitch = el('input', { type:'checkbox', class:'hp-send-switch' }, []); sendSwitch.checked = sendEnabled;
    sendSwitch.addEventListener('change', function() {
      var want = sendSwitch.checked;
      sendSwitch.disabled = true;
      sendEnabled = false;
      setSendControlsEnabled(false);
      function restore() {
        sendSwitch.checked = false;
      }
      fs.exec('/usr/libexec/heizungpanel/set_mode.sh', ['write_mode', want ? '1' : '0']).then(function(res) {
        if (res && res.code === 0) {
          showActionFeedback('ok', 'Write-Mode ' + (want ? '1' : '0') + ' gespeichert, Ansicht wird neu geladen ...', 0);
          window.setTimeout(function() { window.location.reload(); }, 500);
          return;
        }
        restore();
        showActionFeedback('err', 'Write-Mode unklar (Exit ' + (res ? res.code : '?') + '). Senden gesperrt; Ansicht neu laden und Konfiguration prüfen.', 0);
      }).catch(function() {
        restore();
        showActionFeedback('err', 'Write-Mode unklar (RPC-Fehler). Senden gesperrt; Ansicht neu laden und Konfiguration prüfen.', 0);
      });
    });

    function mkMode(label, code) {
      var led = el('div', { class:'hp-led' }, []);
      var b = el('button', { class:'hp-key hp-mode-btn', type:'button', 'aria-label': label + ' setzen' }, ['Setzen']);
      b.disabled = !sendEnabled;
      b.addEventListener('click', function() { if (sendEnabled) runSend(code); });
      sendButtons.push(b);
      return { led: led, node: el('div', { class:'hp-mode' }, [el('div', {}, [label]), el('div', { class:'hp-mode-actions' }, [led, b])]) };
    }

    var einLed = el('div', { class: 'hp-led power unknown' }, []);
    var ausLed = el('div', { class: 'hp-led power unknown' }, []);

    var mD = mkMode('Dauerbetrieb', 'dauer');
    var mU = mkMode('Uhrzeitbetrieb', 'uhr');
    var mB = mkMode('Boilerbetrieb', 'boiler');
    var mUB = mkMode('Uhr+Boilerbetrieb', 'uhr_boiler');
    var mA = mkMode('Außentemp. Reg.', 'aussen_reg');
    var mP = mkMode('Prüfbetrieb', 'pruef');
    var mH = mkMode('Handbetrieb', 'hand');
    var modeByFlags = {};
    Object.keys(MODE_META).forEach(function(flags) {
      modeByFlags[flags] = { name: MODE_META[flags].modeName };
    });
    modeByFlags['7FFF'].led = mD.led;
    modeByFlags['BFFF'].led = mU.led;
    modeByFlags['DFFF'].led = mB.led;
    modeByFlags['EFFF'].led = mUB.led;
    modeByFlags['F7FF'].led = mA.led;
    modeByFlags['FBFF'].led = mP.led;
    modeByFlags['FDFF'].led = mH.led;

    function clearLeds() { [mD,mU,mB,mUB,mA,mP,mH].forEach(function(m) { m.led.className = 'hp-led'; }); }
    function setRenderedDisplay(a, b, dim) {
      line1.textContent = pad20(a);
      line2.textContent = pad20(b);
      line1.className = dim ? 'l dim' : 'l';
      line2.className = dim ? 'l dim' : 'l';
    }

    var lcd = []; for (var i = 0; i < 40; i++) lcd[i] = ' ';
    var transient321Flags = '----';
    var displayStatus83 = decodeDisplayStatus83('', ledMap83, powerEinWhenBit7Clear);
    var last83Ts = 0;
    var status83Seq = 0;
    /* Zeitpunkt des zuletzt beobachteten gueltigen Panel-Frames (Ankunftszeit
     * im Browser). Nur dieser Zeitpunkt darf als "Letzte Aktualisierung"
     * angezeigt werden - nie Date.now() vom Timer. */
    var lastPanelFrameTs = 0;
    var status83TtlMs = 1250;
    var last83DeltaMs = 0;

    function updatePowerLed(node, state) {
      if (state === 'on') node.className = 'hp-led power on';
      else if (state === 'off') node.className = 'hp-led power';
      else node.className = 'hp-led power unknown';
    }

    function is83Fresh() {
      return last83Ts > 0 && (Date.now() - last83Ts) <= status83TtlMs;
    }

    function markPanelFrame() {
      lastPanelFrameTs = Date.now();
    }

    function setLiveStatus() {
      status.className = 'hp-status ok';
      status.textContent = 'Status: Live verbunden';
    }

    function renderProtocolModel() {
      clearLeds();
      var modeFrom83 = null;
      if (is83Fresh() && displayStatus83.modeFlags16 && modeByFlags[displayStatus83.modeFlags16]) {
        modeFrom83 = displayStatus83.modeFlags16;
        modeByFlags[modeFrom83].led.className = 'hp-led on';
        modeHint.textContent = 'Betriebsart: ' + modeByFlags[modeFrom83].name + ' (' + modeFrom83 + ', via 0x320 83)';
      } else {
        modeHint.textContent = 'Betriebsart: unbekannt (warte auf frisches 0x320 83)';
      }

      transientHint.textContent = 'Letztes Bedienereignis: ' + transient321Flags + (transient321Flags === 'FFFF' ? ' (Poll/Reply, nicht gelatcht)' : '');
      displayStatusHint.textContent = 'Displaystatus (0x320 83xx): raw=' + displayStatus83.raw + ', klasse=' + displayStatus83.screenClass + ', ttl=' + status83TtlMs + 'ms · ' + displayStatus83.note;

      updatePowerLed(einLed, is83Fresh() ? displayStatus83.powerEin : 'unknown');
      updatePowerLed(ausLed, is83Fresh() ? displayStatus83.powerAus : 'unknown');
      lastUpdate.textContent = lastPanelFrameTs > 0
        ? 'Letzte Aktualisierung: ' + new Date(lastPanelFrameTs).toLocaleString()
        : 'Letzte Aktualisierung: n/a';

      if (pendingModeAck && status83Seq > pendingModeAck.afterStatus && modeFrom83 && modeFrom83 === pendingModeAck.expected_flags) {
        showActionFeedback('ok', 'Passender CAN-Zustand beobachtet: ' + pendingModeAck.code + ' -> ' + modeFrom83 + ' (0x320 83)', 1500);
        pendingModeAck = null;
      }
    }

    function applyRawLine(raw) {
      var f = parseCandump(raw || '');
      if (!f) return;

      if (f.id === '321' && f.data.length >= 4) {
        markPanelFrame();
        transient321Flags = f.data.slice(0, 4).toUpperCase();
        renderProtocolModel();
        setLiveStatus();
        return;
      }

      if (f.id !== '320' || f.data.length < 2) return;
      var lead = f.data.slice(0, 2).toUpperCase();
      if (lead === '81') {
        /* Clear-Frame: Display sofort leerraeumen (sofortiges Rerender). */
        for (var i = 0; i < 40; i++) lcd[i] = ' ';
        markPanelFrame();
        setRenderedDisplay(lcd.slice(0,20).join(''), lcd.slice(20,40).join(''), true);
        renderProtocolModel();
        setLiveStatus();
        return;
      }
      if (lead === '83') {
        if (f.data.length < 4) return;
        var now83 = Date.now();
        if (last83Ts > 0) {
          last83DeltaMs = now83 - last83Ts;
          if (last83DeltaMs < 250) last83DeltaMs = 250;
          if (last83DeltaMs > 2000) last83DeltaMs = 2000;
          status83TtlMs = Math.max(750, Math.min(3000, Math.round(last83DeltaMs * 2.4)));
        }
        last83Ts = now83;
        status83Seq++;
        displayStatus83 = decodeDisplayStatus83(f.data.slice(2), ledMap83, powerEinWhenBit7Clear);
        markPanelFrame();
        setRenderedDisplay(lcd.slice(0,20).join(''), lcd.slice(20,40).join(''), false);
        renderProtocolModel();
        setLiveStatus();
        return;
      }
      if (f.data.length < 4) return;

      var off = hex2dec(lead);
      var idx = lcdIndex(off);
      if (idx < 0) return;

      var rowEnd = idx < 20 ? 20 : 40;
      for (var j = 2; (j + 1) < f.data.length && idx < rowEnd; j += 2) {
        lcd[idx++] = byteToChar(f.data.slice(j, j + 2));
      }

      markPanelFrame();
      setRenderedDisplay(lcd.slice(0,20).join(''), lcd.slice(20,40).join(''), false);
      renderProtocolModel();
      setLiveStatus();
    }

    /* --- Live-Stream: genau eine EventSource + genau ein Watchdog-Timer,
     *     wiederaufnehmbar nach Tab-Wechsel und BFCache-Wiederherstellung. --- */
    var es = null;
    var watchdogTimer = null;
    var tornDown = false;

    function closeStream() {
      if (es) {
        es.close();
        es = null;
      }
    }

    function startRawStream() {
      if (es || typeof EventSource === 'undefined') return false;
      var url = '/cgi-bin/heizungpanel_stream?token=' + encodeURIComponent(streamToken);
      es = new EventSource(url);
      es.onmessage = function(ev) { applyRawLine(ev.data || ''); };
      es.onerror = function() {
        status.className = 'hp-status warn';
        status.textContent = 'Status: Verbindung unterbrochen, Reconnect aktiv';
      };
      return true;
    }

    function stopWatchdog() {
      if (watchdogTimer) {
        window.clearInterval(watchdogTimer);
        watchdogTimer = null;
      }
    }

    function startWatchdog() {
      if (watchdogTimer) return;
      watchdogTimer = window.setInterval(function() {
        if (!alive) return;
        if (pendingModeAck && Date.now() > pendingModeAck.deadline) {
          showActionFeedback('warn', 'Keine CAN-Bestätigung für ' + pendingModeAck.code + ' innerhalb 8s', 2000);
          pendingModeAck = null;
        }
        if (lastPanelFrameTs === 0 || Date.now() - lastPanelFrameTs > 5000) {
          status.className = 'hp-status warn';
          status.textContent = publishRawEnabled
            ? 'Status: Keine Raw-Daten – warte auf Live-Daten'
            : 'Status: Keine Raw-Daten – publish_raw=0 (Raw-Publisher inaktiv)';
        }
        renderProtocolModel();
      }, 500);
    }

    function teardown() {
      tornDown = true;
      closeStream();
      stopWatchdog();
    }

    function resume() {
      if (!tornDown) return;
      tornDown = false;
      renderProtocolModel();
      startRawStream();
      startWatchdog();
    }

    function dispose() {
      alive = false;
      teardown();
      document.removeEventListener('visibilitychange', onVisibilityChange);
      window.removeEventListener('pagehide', teardown);
      window.removeEventListener('pageshow', onPageShow);
    }

    var powerRow = el('div', { class:'hp-power' }, [
      el('div', { class:'hp-sub' }, ['Ein/Aus-Indikator (direkt aus frischen 0x320 83xx-Frames)']),
      el('div', { class:'hp-power-row' }, [einLed, btn('Ein', 'ein')]),
      el('div', { class:'hp-power-row' }, [ausLed, btn('Aus', 'aus')])
    ]);
    var left = el('div', { class:'hp-left' }, [keygrid, powerRow, el('label', {}, ['Send mode ', sendSwitch]), actionFeedback]);
    var right = el('div', { class:'hp-right' }, [el('div', { class:'hp-modes' }, [mD.node,mU.node,mB.node,mUB.node,mA.node,mP.node,mH.node])]);
    var root = el('div', { class:'hp-wrap' }, [style, el('div', { class:'hp-panel' }, [display, el('div', { class:'hp-grid' }, [left, right])])]);

    if (!startRawStream()) {
      status.className = 'hp-status warn';
      status.textContent = 'Status: Live-Stream nicht verfügbar';
    }
    startWatchdog();

    /* Verstecken ruft teardown auf, Wiederanzeigen nimmt genau einen Stream
     * und einen Timer wieder auf. pagehide/pageshow(persisted) deckt die
     * BFCache-Wiederherstellung ab (kein beforeunload: blockiert BFCache). */
    function onVisibilityChange() {
      if (!alive) return;
      if (document.visibilityState === 'hidden') teardown();
      else resume();
    }
    function onPageShow(ev) {
      if (!alive) return;
      if (ev && ev.persisted) resume();
    }
    document.addEventListener('visibilitychange', onVisibilityChange);
    window.addEventListener('pagehide', teardown);
    window.addEventListener('pageshow', onPageShow);

    if (self) self._heizungDispose = dispose;

    return root;
  },

  handleSaveApply: null,
  handleSave: null,
  handleReset: null
});
