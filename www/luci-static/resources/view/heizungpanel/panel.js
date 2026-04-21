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
  if (off >= 0x14 && off <= 0x1F) return off;
  if (off >= 0x54 && off <= 0x5F) return 20 + (off - 0x54);
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
  var m = line.match(/([0-9A-Fa-f]+)#([0-9A-Fa-f]+)/);
  if (m) return { id: normalizeCanId(m[1]), data: m[2].toUpperCase() };

  m = line.match(/(^|[ \t])([0-9A-Fa-f]+)[ \t]+\[[ \t]*(\d+)[ \t]*\][ \t]+(.+)[ \t]*$/);
  if (!m) return null;

  var id = normalizeCanId(m[2]);
  var want = parseInt(m[3], 10) || 0;
  var tail = m[4] || '';
  var q = tail.indexOf("'");
  if (q >= 0) tail = tail.slice(0, q);
  var bytes = tail.match(/[0-9A-Fa-f]{2}/g) || [];
  if (want > 0) bytes = bytes.slice(0, want);
  if (!bytes.length) return null;

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

function decodeDisplayStatus83(payloadHex, ledMap83, powerEinWhenBit7Clear) {
  var raw = String(payloadHex || '').toUpperCase();
  var modeFlags16 = (ledMap83 && ledMap83[raw]) ? ledMap83[raw] : null;
  var modeMetaByFlags = {
    '7FFF': { screenClass: 'dauer', modeName: 'Dauerbetrieb' },
    'BFFF': { screenClass: 'uhr', modeName: 'Uhrzeitbetrieb' },
    'DFFF': { screenClass: 'boiler', modeName: 'Boilerbetrieb' },
    'EFFF': { screenClass: 'uhr_boiler', modeName: 'Uhr+Boilerbetrieb' },
    'F7FF': { screenClass: 'aussen_reg', modeName: 'Außentemperatur-Regelung' },
    'FBFF': { screenClass: 'pruef', modeName: 'Prüfbetrieb' },
    'FDFF': { screenClass: 'hand', modeName: 'Handbetrieb' }
  };
  var d = (modeFlags16 && modeMetaByFlags[modeFlags16]) ? modeMetaByFlags[modeFlags16] : {};

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

return view.extend({
  load: function() {
    return fs.exec('/usr/libexec/heizungpanel/config.sh', []).then(function(res) {
      if (!res || res.code !== 0)
        return { poll_interval_ms: 500, write_mode: 0, stream_token: '' };

      try {
        var cfg = JSON.parse((res.stdout || '').trim() || '{}');
        return {
          poll_interval_ms: clampPollInterval(cfg.poll_interval_ms),
          write_mode: cfg.write_mode || 0,
          stream_token: cfg.stream_token || '',
          led_map_83: cfg.led_map_83 || '',
          led_power_ein_when_bit7_clear: String(cfg.led_power_ein_when_bit7_clear || '1'),
          mapping_dauer: cfg.mapping_dauer || '7FFF',
          mapping_uhr: cfg.mapping_uhr || 'BFFF',
          mapping_boiler: cfg.mapping_boiler || 'DFFF',
          mapping_uhr_boiler: cfg.mapping_uhr_boiler || 'EFFF',
          mapping_aussen_reg: cfg.mapping_aussen_reg || 'F7FF',
          mapping_pruef: cfg.mapping_pruef || 'FBFF',
          mapping_hand: cfg.mapping_hand || 'FDFF'
        };
      } catch (e) {
        return {
          poll_interval_ms: 500,
          write_mode: 0,
          stream_token: '',
          led_map_83: '',
          led_power_ein_when_bit7_clear: '1'
        };
      }
    }).catch(function() {
      return {
        poll_interval_ms: 500,
        write_mode: 0,
        stream_token: '',
        led_map_83: '',
        led_power_ein_when_bit7_clear: '1'
      };
    });
  },

  render: function(cfg) {
    cfg = cfg || {};
    var streamToken = cfg.stream_token || '';
    var sendEnabled = String(cfg.write_mode || 0) === '1';
    var ledMap83 = parseLedMap83(cfg.led_map_83 || 'BF:7FFF,3F:7FFF,DF:BFFF,5F:BFFF,EF:DFFF,6F:DFFF,FB:EFFF,7B:EFFF,73:F7FF,7E:FDFF');
    var powerEinWhenBit7Clear = String(cfg.led_power_ein_when_bit7_clear || '1') !== '0';

    var style = el('style', { html: '.hp-wrap{max-width:760px}.hp-panel{background:#3b3b3b;border-radius:10px;padding:18px;color:#eee}.hp-display{background:#0b0f16;border:2px solid #cfcfcf;border-radius:8px;padding:10px 12px;margin:0 auto 14px auto;width:96%;font-family:monospace}.l{white-space:pre;color:#74d3ff;font-size:18px}.l.dim{color:#2f4b5f}.hp-status,.hp-sub{font-size:12px}.hp-grid{display:grid;grid-template-columns:1fr 1.2fr;gap:14px}.hp-left,.hp-right{background:rgba(255,255,255,.04);border-radius:10px;padding:12px}.hp-key{background:#d9d9d9;color:#222;border-radius:6px;border:1px solid #bfbfbf;cursor:pointer;font-weight:700}.hp-keygrid{display:grid;grid-template-columns:70px 70px 70px;grid-template-rows:44px 44px 44px;gap:10px;justify-content:center}.hp-power{display:flex;flex-direction:column;gap:8px;margin-top:10px}.hp-power-row{display:flex;justify-content:center;align-items:center;gap:10px}.hp-power .hp-key{min-width:110px;height:36px}.hp-modes{display:flex;flex-direction:column;gap:10px}.hp-mode{display:grid;grid-template-columns:1fr auto;align-items:center;gap:12px;padding:10px;border-radius:8px;background:rgba(255,255,255,.06)}.hp-mode-actions{display:flex;align-items:center;gap:10px;min-width:96px;justify-content:flex-end}.hp-led{width:12px;height:12px;border-radius:50%;background:#555;border:1px solid #999;flex:0 0 12px}.hp-mode-btn{width:74px;height:32px}.hp-led.on{background:#ffd54a}.hp-led.power.on{background:#9fff82}.hp-led.power.unknown{background:#6e7f91}.hp-status.ok{color:#97e493}.hp-status.warn{color:#ffd166}.hp-status.err{color:#ff8a80}.hp-inline-msg{min-height:20px;font-size:12px}.hp-inline-msg.ok{color:#97e493}.hp-inline-msg.warn{color:#ffd166}.hp-inline-msg.err{color:#ff8a80}' }, []);

    var line1 = el('div', { class: 'l dim' }, ['                    ']);
    var line2 = el('div', { class: 'l dim' }, ['                    ']);
    var status = el('div', { class: 'hp-status warn' }, ['Status: Verbinde ...']);
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
      dauer: String(cfg.mapping_dauer || '7FFF').toUpperCase(),
      uhr: String(cfg.mapping_uhr || 'BFFF').toUpperCase(),
      boiler: String(cfg.mapping_boiler || 'DFFF').toUpperCase(),
      uhr_boiler: String(cfg.mapping_uhr_boiler || 'EFFF').toUpperCase(),
      aussen_reg: String(cfg.mapping_aussen_reg || 'F7FF').toUpperCase(),
      pruef: String(cfg.mapping_pruef || 'FBFF').toUpperCase(),
      hand: String(cfg.mapping_hand || 'FDFF').toUpperCase()
    };
    var pendingModeAck = null;

    function showActionFeedback(level, text, timeoutMs) {
      actionFeedback.className = 'hp-inline-msg ' + (level || 'ok');
      actionFeedback.textContent = text || '';
      if (timeoutMs > 0) {
        window.setTimeout(function() {
          actionFeedback.className = 'hp-inline-msg';
          actionFeedback.textContent = '';
        }, timeoutMs);
      }
    }

    function runSend(code) {
      return fs.exec('/usr/libexec/heizungpanel/press.sh', [code]).then(function(res) {
        if (res && res.code === 0) {
          showActionFeedback('ok', 'Befehl gesendet: ' + code, 1200);
          if (expectedModeBySendCode[code]) {
            pendingModeAck = { code: code, expected_flags: expectedModeBySendCode[code], deadline: Date.now() + 8000 };
          }
          return;
        }
        if (res && res.code === 4) {
          showActionFeedback('warn', 'Mapping für "' + code + '" noch nicht hinterlegt.', 2200);
          return;
        }
        showActionFeedback('err', 'Senden fehlgeschlagen', 3000);
      }).catch(function(err) {
        showActionFeedback('err', 'Sende-Fehler: ' + err, 3000);
      });
    }

    function btn(txt, code) {
      var b = el('button', { class: 'hp-key', type: 'button' }, [txt]);
      b.disabled = !sendEnabled;
      b.addEventListener('click', function() { if (sendEnabled) runSend(code); });
      return b;
    }

    var keygrid = el('div', { class: 'hp-keygrid' }, [el('div', {}, []), btn('Z','z'), el('div', {}, []), btn('-','minus'), btn('Quit','quit'), btn('+','plus'), el('div', {}, []), btn('V','v'), el('div', {}, [])]);
    var sendSwitch = el('input', { type:'checkbox' }, []); sendSwitch.checked = sendEnabled;
    sendSwitch.addEventListener('change', function() {
      fs.exec('/usr/libexec/heizungpanel/set_mode.sh', ['write_mode', sendSwitch.checked ? '1' : '0']).then(function() {
        window.setTimeout(function() { window.location.reload(); }, 500);
      });
    });

    function mkMode(label, code) {
      var led = el('div', { class:'hp-led' }, []);
      var b = el('button', { class:'hp-key hp-mode-btn', type:'button' }, ['Setzen']);
      b.disabled = !sendEnabled;
      b.addEventListener('click', function() { if (sendEnabled) runSend(code); });
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
    var modeByFlags = {
      '7FFF': { name: 'Dauerbetrieb', led: mD.led }, 'BFFF': { name: 'Uhrzeitbetrieb', led: mU.led },
      'DFFF': { name: 'Boilerbetrieb', led: mB.led }, 'EFFF': { name: 'Uhr+Boilerbetrieb', led: mUB.led },
      'F7FF': { name: 'Außentemperatur-Regelung', led: mA.led }, 'FBFF': { name: 'Prüfbetrieb', led: mP.led }, 'FDFF': { name: 'Handbetrieb', led: mH.led }
    };

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
      lastUpdate.textContent = 'Letzte Aktualisierung: ' + new Date().toLocaleString();

      if (pendingModeAck && modeFrom83 && modeFrom83 === pendingModeAck.expected_flags) {
        showActionFeedback('ok', 'CAN-Bestätigung: ' + pendingModeAck.code + ' -> ' + modeFrom83 + ' (0x320 83)', 1500);
        pendingModeAck = null;
      }
    }

    function applyRawLine(raw) {
      var f = parseCandump(raw || '');
      if (!f) return;

      if (f.id === '321' && f.data.length >= 4) {
        transient321Flags = f.data.slice(0, 4).toUpperCase();
        renderProtocolModel();
        status.className = 'hp-status ok';
        status.textContent = 'Status: Live verbunden';
        return;
      }

      if (f.id !== '320' || f.data.length < 2) return;
      var lead = f.data.slice(0, 2).toUpperCase();
      if (lead === '81') {
        for (var i = 0; i < 40; i++) lcd[i] = ' ';
        return;
      }
      if (lead === '83') {
        var now83 = Date.now();
        if (last83Ts > 0) {
          last83DeltaMs = now83 - last83Ts;
          if (last83DeltaMs < 250) last83DeltaMs = 250;
          if (last83DeltaMs > 2000) last83DeltaMs = 2000;
          status83TtlMs = Math.max(750, Math.min(3000, Math.round(last83DeltaMs * 2.4)));
        }
        last83Ts = now83;
        displayStatus83 = decodeDisplayStatus83(f.data.slice(2), ledMap83, powerEinWhenBit7Clear);
        setRenderedDisplay(lcd.slice(0,20).join(''), lcd.slice(20,40).join(''), false);
        renderProtocolModel();
        status.className = 'hp-status ok';
        status.textContent = 'Status: Live verbunden';
        return;
      }
      if (f.data.length < 4) return;

      var off = hex2dec(lead);
      var idx = lcdIndex(off);
      if (idx < 0) return;

      for (var j = 2; (j + 1) < f.data.length && idx < 40; j += 2) {
        lcd[idx++] = byteToChar(f.data.slice(j, j + 2));
      }

      setRenderedDisplay(lcd.slice(0,20).join(''), lcd.slice(20,40).join(''), false);
      status.className = 'hp-status ok';
      status.textContent = 'Status: Live verbunden';
    }

    var es = null;
    function closeStream() {
      if (es) {
        es.close();
        es = null;
      }
    }

    function startRawStream() {
      if (typeof EventSource === 'undefined') return false;
      var url = '/cgi-bin/heizungpanel_stream?token=' + encodeURIComponent(streamToken);
      es = new EventSource(url);
      es.onmessage = function(ev) { applyRawLine(ev.data || ''); };
      es.onerror = function() {
        status.className = 'hp-status warn';
        status.textContent = 'Status: Verbindung unterbrochen, Reconnect aktiv';
      };
      return true;
    }

    var powerRow = el('div', { class:'hp-power' }, [
      el('div', { class:'hp-sub' }, ['Ein/Aus-Indikator (direkt aus frischen 0x320 83xx-Frames)']),
      el('div', { class:'hp-power-row' }, [einLed, btn('Ein', 'ein')]),
      el('div', { class:'hp-power-row' }, [ausLed, btn('Aus', 'aus')])
    ]);
    var left = el('div', { class:'hp-left' }, [keygrid, powerRow, el('label', {}, ['Send mode ', sendSwitch]), actionFeedback]);
    var right = el('div', { class:'hp-right' }, [el('div', { class:'hp-modes' }, [mD.node,mU.node,mB.node,mUB.node,mA.node,mP.node,mH.node])]);
    var root = el('div', { class:'hp-wrap' }, [style, el('div', { class:'hp-panel' }, [display, el('div', { class:'hp-grid' }, [left, right])])]);

    var ackTimer = null;

    if (!startRawStream()) {
      status.className = 'hp-status warn';
      status.textContent = 'Status: Live-Stream nicht verfügbar';
    }

    ackTimer = window.setInterval(function() {
      if (pendingModeAck && Date.now() > pendingModeAck.deadline) {
        showActionFeedback('warn', 'Keine CAN-Bestätigung für ' + pendingModeAck.code + ' innerhalb 8s', 2000);
        pendingModeAck = null;
      }
      renderProtocolModel();
    }, 500);

    function teardown() {
      closeStream();
      if (ackTimer) { window.clearInterval(ackTimer); ackTimer = null; }
    }

    window.addEventListener('beforeunload', teardown);
    window.addEventListener('pagehide', teardown);
    document.addEventListener('visibilitychange', function() {
      if (document.visibilityState === 'hidden') teardown();
    });

    return root;
  },

  handleSaveApply: null,
  handleSave: null,
  handleReset: null
});
