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

function parseCandump(line) {
  var m = line.match(/([0-9A-Fa-f]+)#([0-9A-Fa-f]+)/);
  if (m) return { id: m[1].toUpperCase(), data: m[2].toUpperCase() };

  m = line.match(/(^|[ \t])([0-9A-Fa-f]+)[ \t]+\[[ \t]*(\d+)[ \t]*\][ \t]+(.+)[ \t]*$/);
  if (!m) return null;

  var id = m[2].toUpperCase();
  var want = parseInt(m[3], 10) || 0;
  var tail = m[4] || '';
  var q = tail.indexOf("'");
  if (q >= 0) tail = tail.slice(0, q);
  var bytes = tail.match(/[0-9A-Fa-f]{2}/g) || [];
  if (want > 0) bytes = bytes.slice(0, want);
  if (!bytes.length) return null;

  return { id: id, data: bytes.join('').toUpperCase() };
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
          stream_token: cfg.stream_token || ''
        };
      } catch (e) {
        return { poll_interval_ms: 500, write_mode: 0, stream_token: '' };
      }
    }).catch(function() {
      return { poll_interval_ms: 500, write_mode: 0, stream_token: '' };
    });
  },

  render: function(cfg) {
    cfg = cfg || {};
    var pollInterval = clampPollInterval(cfg.poll_interval_ms);
    var streamToken = cfg.stream_token || '';
    var sendEnabled = String(cfg.write_mode || 0) === '1';

    var style = el('style', { html: '.hp-wrap{max-width:960px}.hp-panel{background:#3b3b3b;border-radius:10px;padding:18px;color:#eee}.hp-display{background:#0b0f16;border:2px solid #cfcfcf;border-radius:8px;padding:10px 12px;margin:0 auto 18px auto;width:96%;font-family:monospace}.l{white-space:pre;color:#74d3ff;font-size:18px}.l.dim{color:#2f4b5f}.hp-debug,.hp-status,.hp-sub{font-size:12px}.hp-grid{display:grid;grid-template-columns:1fr 1.2fr;gap:14px}.hp-left,.hp-right{background:rgba(255,255,255,.04);border-radius:10px;padding:12px}.hp-key{background:#d9d9d9;color:#222;border-radius:6px;border:1px solid #bfbfbf;cursor:pointer;font-weight:700}.hp-keygrid{display:grid;grid-template-columns:70px 70px 70px;grid-template-rows:44px 44px 44px;gap:10px;justify-content:center}.hp-power{display:flex;gap:10px;justify-content:center;margin-top:10px}.hp-power .hp-key{min-width:110px;height:36px}.hp-modes{display:flex;flex-direction:column;gap:10px}.hp-mode{display:grid;grid-template-columns:1fr auto;align-items:center;gap:12px;padding:10px;border-radius:8px;background:rgba(255,255,255,.06)}.hp-mode-actions{display:flex;align-items:center;gap:10px;min-width:96px;justify-content:flex-end}.hp-led{width:12px;height:12px;border-radius:50%;background:#555;border:1px solid #999;flex:0 0 12px}.hp-mode-btn{width:74px;height:32px}.hp-led.on{background:#ffd54a}.hp-status.ok{color:#97e493}.hp-status.warn{color:#ffd166}.hp-status.err{color:#ff8a80}.hp-inline-msg{min-height:20px;font-size:12px}.hp-inline-msg.ok{color:#97e493}.hp-inline-msg.warn{color:#ffd166}.hp-inline-msg.err{color:#ff8a80}.hp-map{margin-top:14px;padding:12px;border-radius:10px;background:rgba(255,255,255,.04)}.hp-map h3{margin:0 0 8px 0;font-size:14px}.hp-map table{width:100%;border-collapse:collapse;font-size:12px;margin-bottom:10px}.hp-map th,.hp-map td{border:1px solid rgba(255,255,255,.15);padding:4px 6px;text-align:left}.hp-map th{background:rgba(255,255,255,.08)}.hp-sensor-pick{display:flex;flex-wrap:wrap;gap:8px;margin-bottom:8px}.hp-sensor-pick label{font-size:12px;background:rgba(255,255,255,.06);padding:4px 6px;border-radius:6px}.hp-graph{background:#111;border:1px solid #666;border-radius:6px;width:100%;height:220px}.hp-legend{display:flex;flex-wrap:wrap;gap:8px;font-size:11px;margin-top:6px}' }, []);

    var line1 = el('div', { class: 'l dim' }, ['                    ']);
    var line2 = el('div', { class: 'l dim' }, ['                    ']);
    var flags = el('div', { class: 'hp-debug' }, ['flags16: ----  mode_code: --']);
    var status = el('div', { class: 'hp-status warn' }, ['Status: warte auf Raw-Frames ...']);
    var lastUpdate = el('div', { class: 'hp-sub' }, ['Letzte Aktualisierung: n/a']);
    var modeHint = el('div', { class:'hp-sub' }, ['Modus aus 0x321: n/a']);

    var actionFeedback = el('div', { class:'hp-inline-msg', 'aria-live':'polite' }, ['']);
    var sensorSeries = {};
    var sensorEnabled = {};
    var sensorColors = ['#ffd54a', '#81d4fa', '#ffab91', '#a5d6a7', '#ce93d8', '#ffcc80', '#80cbc4', '#ef9a9a'];
    var graphCanvas = el('canvas', { class: 'hp-graph', width: '900', height: '220' }, []);
    var graphLegend = el('div', { class: 'hp-legend' }, []);

    var idAssignments = [
      ['0x1F5', '501', 'Zeit-/Statuskanal', 'teilvalidiert'],
      ['0x258', '600', 'Soll-/Befehlsrahmen I/O', 'hoch validiert'],
      ['0x259', '601', 'Rückmeldung/Messrahmen I/O', 'hoch validiert'],
      ['0x320', '800', 'Displaydaten/Displaystatus', 'hoch validiert'],
      ['0x321', '801', 'Panel/Tasten-Rückkanal', 'hoch validiert']
    ];
    var commandMapRows = [
      ['dauer', '321#7FFF', 'Dauerbetrieb'],
      ['uhr', '321#BFFF', 'Uhrzeitbetrieb'],
      ['boiler', '321#DFFF', 'Boilerbetrieb'],
      ['uhr_boiler', '321#EFFF', 'Uhr+Boilerbetrieb'],
      ['aussen_reg', '321#F7FF', 'Außentemperatur-Regelung'],
      ['pruef', '321#FBFF', 'Prüfbetrieb'],
      ['hand', '321#FDFF', 'Handbetrieb'],
      ['v', '321#FFFB', 'Navigation V'],
      ['z', '321#FF7F', 'Navigation Z'],
      ['quit', '321#FFBF', 'Quit/Zurück'],
      ['(rx)', '321#FFFF', 'Alive/Poll-Status (transient)']
    ];
    var sensorCatalog = [
      { idx: '00', label: 'Index 00 – Kanalgruppe' }, { idx: '01', label: 'Index 01 – Boiler/Pumpe Kandidat' },
      { idx: '02', label: 'Index 02 – Kanalgruppe/Sonderfall' }, { idx: '03', label: 'Index 03 – Mischer/Vorlauf Kandidat' },
      { idx: '04', label: 'Index 04 – Relais/Sonderobjekt' }, { idx: '05', label: 'Index 05 – Relais/Pumpenobjekt' },
      { idx: '06', label: 'Index 06 – Relais/Sonderobjekt' }, { idx: '07', label: 'Index 07 – Relais/Pumpenobjekt' },
      { idx: '08', label: 'Index 08 – Statusobjekt' }, { idx: '09', label: 'Index 09 – Relais/Sonderobjekt' },
      { idx: '0A', label: 'Index 0A – Relais/Sonderobjekt' }, { idx: '0B', label: 'Index 0B – Statusobjekt' },
      { idx: '0C', label: 'Index 0C – Sensorobjekt' }
    ];

    var display = el('div', { class: 'hp-display' }, [
      el('div', { class: 'hp-sub' }, ['LCD 2x20 (Browser-dekodiert aus Raw 0x320/0x321)']),
      line1, line2, flags, status, lastUpdate
    ]);

    var expectedModeBySendCode = { dauer:'7FFF', uhr:'BFFF', boiler:'DFFF', uhr_boiler:'EFFF', aussen_reg:'F7FF', pruef:'FBFF', hand:'FDFF' };
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
    var transient321ByFlags = { 'FFFF': 'Anlage aktiv (Pollframe)' };

    function clearLeds() { [mD,mU,mB,mUB,mA,mP,mH].forEach(function(m) { m.led.className = 'hp-led'; }); }
    function setRenderedDisplay(a, b) {
      line1.textContent = pad20(a); line2.textContent = pad20(b);
      line1.className = 'l'; line2.className = 'l';
    }

    var lcd = []; for (var i = 0; i < 40; i++) lcd[i] = ' ';
    var modeCode = '--';
    var modeFlags = '----';
    var latchedModeFlags = '----';
    var liveHasRendered = false;
    var bootstrapHydrated = false;
    var liveTextSeen = false;
    var pendingLiveClear = false;

    function hydrateLcdFromLines(a, b) {
      var l1 = pad20(a);
      var l2 = pad20(b);
      var i;
      for (i = 0; i < 20; i++) lcd[i] = l1.charAt(i);
      for (i = 0; i < 20; i++) lcd[20 + i] = l2.charAt(i);
    }

    function renderLive() {
      setRenderedDisplay(lcd.slice(0,20).join(''), lcd.slice(20,40).join(''));
      liveHasRendered = true;
      flags.textContent = 'flags16: ' + modeFlags + '  mode_code: ' + modeCode;
      lastUpdate.textContent = 'Letzte Aktualisierung: ' + new Date().toLocaleString();
      clearLeds();
      if (modeByFlags[latchedModeFlags]) {
        modeByFlags[latchedModeFlags].led.className = 'hp-led on';
      }
      if (modeByFlags[modeFlags]) {
        modeHint.textContent = 'Modus aus 0x321: ' + modeByFlags[modeFlags].name + ' (' + modeFlags + ')';
      } else if (transient321ByFlags[modeFlags]) {
        if (modeByFlags[latchedModeFlags]) {
          modeHint.textContent = '0x321: ' + transient321ByFlags[modeFlags] + ' (' + modeFlags + '), Betriebsmodus: ' + modeByFlags[latchedModeFlags].name + ' (' + latchedModeFlags + ')';
        } else {
          modeHint.textContent = '0x321: ' + transient321ByFlags[modeFlags] + ' (' + modeFlags + ')';
        }
      } else {
        if (modeByFlags[latchedModeFlags]) {
          modeHint.textContent = 'Modus aus 0x321: unbekannt (' + modeFlags + '), letzter Betriebsmodus: ' + modeByFlags[latchedModeFlags].name + ' (' + latchedModeFlags + ')';
        } else {
          modeHint.textContent = 'Modus aus 0x321: unbekannt (' + modeFlags + ')';
        }
      }
      if (pendingModeAck && modeFlags === pendingModeAck.expected_flags) {
        showActionFeedback('ok', 'CAN-Bestätigung: ' + pendingModeAck.code + ' -> ' + modeFlags, 1500);
        pendingModeAck = null;
      }
    }

    function applyRawLine(raw) {
      var f = parseCandump(raw || '');
      if (!f) return;

      if (f.id === '321' && f.data.length >= 4) {
        modeFlags = f.data.slice(0, 4).toUpperCase();
        if (modeByFlags[modeFlags]) {
          latchedModeFlags = modeFlags;
        }
        renderLive();
        status.className = 'hp-status ok';
        status.textContent = 'Status: Raw-Stream aktiv';
        return;
      }

      if (f.id === '259' && f.data.length >= 12) {
        ingestSensorFrame(f.data);
        return;
      }
      if (f.id !== '320' || f.data.length < 2) return;
      var lead = f.data.slice(0, 2).toUpperCase();
      if (lead === '81') {
        if (bootstrapHydrated && !liveTextSeen) {
          pendingLiveClear = true;
        } else {
          for (var i = 0; i < 40; i++) lcd[i] = ' ';
        }
        return;
      }
      if (lead === '83') {
        if (f.data.length >= 4) modeCode = f.data.slice(2, 4).toUpperCase();
        renderLive();
        status.className = 'hp-status ok';
        status.textContent = 'Status: Raw-Stream aktiv';
        return;
      }
      if (f.data.length < 4) return;

      var off = hex2dec(lead);
      var idx = lcdIndex(off);
      if (idx < 0) return;
      if (pendingLiveClear) {
        for (var k = 0; k < 40; k++) lcd[k] = ' ';
        pendingLiveClear = false;
      }
      liveTextSeen = true;
      for (var j = 2; (j + 1) < f.data.length && idx < 40; j += 2) {
        lcd[idx++] = byteToChar(f.data.slice(j, j + 2));
      }
    }

    function ingestSensorFrame(data) {
      var idx = data.slice(0, 2).toUpperCase();
      var raw = data.slice(8, 12).toUpperCase();
      var rawNum = parseInt(raw, 16);
      if (isNaN(rawNum)) return;
      if (!sensorSeries[idx]) sensorSeries[idx] = [];
      sensorSeries[idx].push({ ts: Date.now(), v: rawNum / 10.0, raw: raw });
      if (sensorSeries[idx].length > 120) sensorSeries[idx].shift();
      drawSensorGraph();
    }

    function drawSensorGraph() {
      var ctx = graphCanvas.getContext('2d');
      var w = graphCanvas.width, h = graphCanvas.height;
      ctx.fillStyle = '#111'; ctx.fillRect(0, 0, w, h);
      ctx.strokeStyle = '#444'; ctx.strokeRect(0, 0, w, h);

      var keys = Object.keys(sensorEnabled).filter(function(k) { return sensorEnabled[k] && sensorSeries[k] && sensorSeries[k].length > 1; });
      graphLegend.innerHTML = '';
      if (!keys.length) {
        ctx.fillStyle = '#aaa';
        ctx.fillText('Keine Sensorkurve gewählt oder noch keine 0x259-Daten.', 16, 26);
        return;
      }

      var min = Infinity, max = -Infinity, i, j;
      for (i = 0; i < keys.length; i++) {
        var arr = sensorSeries[keys[i]];
        for (j = 0; j < arr.length; j++) {
          if (arr[j].v < min) min = arr[j].v;
          if (arr[j].v > max) max = arr[j].v;
        }
      }
      if (min === max) { min -= 1; max += 1; }
      var yScale = (h - 24) / (max - min);
      var xStep = (w - 20) / 119;

      ctx.fillStyle = '#ddd';
      ctx.fillText('Min: ' + min.toFixed(1) + '  Max: ' + max.toFixed(1), 10, h - 6);

      for (i = 0; i < keys.length; i++) {
        var key = keys[i];
        var vals = sensorSeries[key];
        var color = sensorColors[i % sensorColors.length];
        ctx.strokeStyle = color;
        ctx.beginPath();
        for (j = 0; j < vals.length; j++) {
          var x = 10 + ((120 - vals.length + j) * xStep);
          var y = h - 16 - ((vals[j].v - min) * yScale);
          if (j === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
        }
        ctx.stroke();
        graphLegend.appendChild(el('div', {}, [el('span', { style: 'display:inline-block;width:10px;height:10px;background:' + color + ';margin-right:4px' }, []), key + ' (' + vals[vals.length - 1].v.toFixed(1) + ')']));
      }
    }

    function mkTable(headers, rows) {
      var thead = el('thead', {}, [el('tr', {}, headers.map(function(h) { return el('th', {}, [h]); }))]);
      var bodyRows = rows.map(function(r) { return el('tr', {}, r.map(function(c) { return el('td', {}, [c]); })); });
      return el('table', {}, [thead, el('tbody', {}, bodyRows)]);
    }

    function applyBootstrap(st) {
      if (!st || st.status !== 'ok') return;
      var mode = st.mode || {};
      bootstrapHydrated = true;
      liveTextSeen = false;
      pendingLiveClear = false;
      modeFlags = (st.mode_flags16 || mode.flags16 || '----').toUpperCase();
      latchedModeFlags = modeFlags;
      modeCode = '--';

      // Persistent bootstrap is intentionally mode-only.
      // Display text is rendered exclusively from live Raw frames.
      clearLeds();
      if (modeByFlags[modeFlags]) {
        modeByFlags[modeFlags].led.className = 'hp-led on';
        modeHint.textContent = 'Modus (retained): ' + modeByFlags[modeFlags].name + ' (' + modeFlags + ')';
      } else {
        modeHint.textContent = 'Modus (retained): unbekannt (' + modeFlags + ')';
      }
      flags.textContent = 'flags16: ' + modeFlags + '  mode_code: --';
      status.className = 'hp-status warn';
      status.textContent = 'Status: Modus-Bootstrap geladen, Display wartet auf Raw-Liveframes';
    }

    function loadBootstrap() {
      return fs.exec('/usr/libexec/heizungpanel/state.sh', []).then(function(res) {
        if (!res || res.code !== 0) return;
        try { applyBootstrap(JSON.parse((res.stdout || '').trim() || '{}')); } catch (e) {}
      });
    }

    function startRawStream() {
      if (typeof EventSource === 'undefined') return false;
      var url = '/cgi-bin/heizungpanel_stream?mode=raw&token=' + encodeURIComponent(streamToken);
      var es = new EventSource(url);
      es.onmessage = function(ev) { applyRawLine(ev.data || ''); };
      es.onerror = function() {
        status.className = 'hp-status warn';
        status.textContent = 'Status: Raw-Stream getrennt, Reconnect aktiv';
      };
      return true;
    }

    function pollDebugState() {
      fs.exec('/usr/libexec/heizungpanel/state.sh', []).then(function(res) {
        if (!res || res.code !== 0) return;
        try { applyBootstrap(JSON.parse((res.stdout || '').trim() || '{}')); } catch (e) {}
      });
    }

    var powerRow = el('div', { class:'hp-power' }, [btn('Ein', 'ein'), btn('Aus', 'aus')]);
    var left = el('div', { class:'hp-left' }, [keygrid, powerRow, el('label', {}, ['Send mode ', sendSwitch]), actionFeedback]);
    var right = el('div', { class:'hp-right' }, [el('div', { class:'hp-modes' }, [mD.node,mU.node,mB.node,mUB.node,mA.node,mP.node,mH.node]), modeHint]);
    var sensorPick = el('div', { class: 'hp-sensor-pick' }, sensorCatalog.map(function(s, i) {
      var c = el('input', { type: 'checkbox' }, []);
      if (i < 3) { c.checked = true; sensorEnabled[s.idx] = true; }
      c.addEventListener('change', function() { sensorEnabled[s.idx] = c.checked; drawSensorGraph(); });
      return el('label', {}, [c, ' ', s.idx, ' ', s.label]);
    }));
    var mappingSection = el('div', { class: 'hp-map' }, [
      el('h3', {}, ['Reverse-Engineering Mapping']),
      el('div', { class: 'hp-sub' }, ['ID-Zuordnung, Button-/Command-Mapping und auswählbare Sensortrends aus 0x259.']),
      mkTable(['ID', 'Dez', 'Rolle', 'Status'], idAssignments),
      mkTable(['Command', 'CAN-Frame', 'Bedeutung'], commandMapRows),
      el('h3', {}, ['Sensor-Graph (0x259)']),
      sensorPick,
      graphCanvas,
      graphLegend
    ]);
    var root = el('div', { class:'hp-wrap' }, [style, el('div', { class:'hp-panel' }, [display, el('div', { class:'hp-grid' }, [left, right]), mappingSection])]);

    loadBootstrap().then(function() {
      if (!startRawStream()) {
        status.className = 'hp-status warn';
        status.textContent = 'Status: EventSource fehlt, bootstrap-only Polling aktiv';
        window.setInterval(pollDebugState, pollInterval);
      }
    });

    window.setInterval(function() {
      if (pendingModeAck && Date.now() > pendingModeAck.deadline) {
        showActionFeedback('warn', 'Keine CAN-Bestätigung für ' + pendingModeAck.code + ' innerhalb 8s', 2000);
        pendingModeAck = null;
      }
    }, 500);

    drawSensorGraph();

    return root;
  },

  handleSaveApply: null,
  handleSave: null,
  handleReset: null
});
