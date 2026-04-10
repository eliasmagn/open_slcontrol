'use strict';
'require view';
'require fs';
'require ui';

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

function parseEpochMs(raw) {
  var n = parseInt(raw, 10);
  if (isNaN(n) || n <= 0) return null;
  return n;
}

return view.extend({
  load: function() {
    return fs.exec('/usr/libexec/heizungpanel/config.sh', []).then(function(res) {
      if (!res || res.code !== 0)
        return { poll_interval_ms: 500, write_mode: 0 };

      try {
        var cfg = JSON.parse((res.stdout || "").trim() || "{}");
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
    var sendEnabled = String(cfg.write_mode || 0) === "1";
    var style = el('style', { 'html': [
      '.hp-wrap { max-width: 720px; }',
      '.hp-panel {',
      '  background:#3b3b3b; border-radius:10px; padding:18px;',
      '  color:#eee; box-shadow:0 2px 8px rgba(0,0,0,.25);',
      '}',
      '.hp-display {',
      '  margin-top:6px;',
      '  background:#0b0f16; border:2px solid #cfcfcf; border-radius:8px;',
      '  padding:10px 12px; margin:0 auto 18px auto; width: 88%;',
      '  font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, "Liberation Mono", "Courier New", monospace;',
      '  color:#39a9ff; letter-spacing:1px;',
      '}',
      '.hp-display .lcd-title { font-size:12px; opacity:.9; margin-bottom:6px; color:#9fc8ff; letter-spacing:.4px; }',
      '.hp-display .lcd-frame { border:1px solid #35526e; border-radius:6px; padding:8px; background:#050b14; }',
      '.hp-display .l { white-space:pre; line-height:1.2; font-size:18px; color:#74d3ff; }',
      '.hp-display .l.dim { color:#2f4b5f; }',
      '.hp-grid { display:grid; grid-template-columns: 1fr 1.2fr; gap:14px; }',
      '.hp-left, .hp-right { background: rgba(255,255,255,.04); border-radius:10px; padding:12px; }',
      '.hp-keygrid { display:grid; grid-template-columns: 70px 70px 70px; grid-template-rows: 44px 44px 44px; gap:10px; justify-content:center; }',
      '.hp-key { background:#d9d9d9; color:#222; border-radius:6px; border:1px solid #bfbfbf; cursor:pointer; font-weight:700; }',
      '.hp-key:active { transform: translateY(1px); }',
      '.hp-wide { grid-column: 1 / span 3; display:flex; justify-content:space-between; gap:10px; }',
      '.hp-power { display:flex; gap:12px; justify-content:center; margin-top:12px; }',
      '.hp-pwrbtn { width:120px; height:48px; border-radius:8px; font-weight:800; cursor:pointer; border:1px solid #bfbfbf; }',
      '.hp-pwrbtn.on { background:#d9d9d9; }',
      '.hp-pwrbtn.off { background:#d9d9d9; }',
      '.hp-modes { display:flex; flex-direction:column; gap:10px; }',
      '.hp-mode { display:flex; align-items:center; justify-content:space-between; gap:10px; padding:10px; border-radius:8px; background: rgba(255,255,255,.06); }',
      '.hp-mode .lbl { font-weight:700; }',
      '.hp-led { width:12px; height:12px; border-radius:50%; background:#555; border:1px solid #999; flex:0 0 auto; }',
      '.hp-led.on { background:#ffd54a; }',
      '.hp-sub { opacity:.8; font-size:12px; margin-top:10px; }',
      '.hp-debug { margin-top:12px; font-family: ui-monospace, monospace; font-size:12px; opacity:.85; }',
      '.hp-row { display:flex; gap:10px; align-items:center; justify-content:space-between; }',
      '.hp-status { margin-top:8px; font-size:12px; opacity:.9; }',
      '.hp-status.ok { color:#97e493; }',
      '.hp-status.warn { color:#ffd166; }',
      '.hp-status.err { color:#ff8a80; }',
      '.hp-switches { margin-top:10px; display:flex; flex-direction:column; gap:8px; }',
      '.hp-switch { display:flex; align-items:center; justify-content:space-between; gap:8px; font-size:12px; }',
      '.hp-switch input { width:18px; height:18px; }'
    ].join('\n') });

    var line1 = el('div', { class: 'l dim' }, ['                ']);
    var line2 = el('div', { class: 'l dim' }, ['                ']);
    var flags = el('div', { class: 'hp-debug' }, ['flags16: ----  last_1f5: ----']);
    var status = el('div', { class: 'hp-status warn' }, ['Status: warte auf Daten ...']);
    var lastUpdate = el('div', { class: 'hp-sub' }, ['Letzte Aktualisierung: n/a']);

    var display = el('div', { class: 'hp-display' }, [
      el('div', { class: 'lcd-title' }, ['LCD 2x16 (emuliert aus CAN 0x320)']),
      el('div', { class: 'lcd-frame' }, [line1, line2]),
      flags, status, lastUpdate
    ]);

    var runSend = function(code) {
      return fs.exec('/usr/libexec/heizungpanel/press.sh', [code]).then(function(res) {
        if (res && res.code === 0) {
          ui.addNotification(null, E('p', {}, _('OK: ' + code)));
          return;
        }

        if (res && res.code === 4) {
          ui.addNotification(null, E('p', {}, _('Hinweis: Send-Mapping für "' + code + '" ist noch nicht hinterlegt.')));
          return;
        }

        ui.addNotification(null, E('p', {}, _('Send failed: ' + (res ? res.stdout || res.stderr || res.code : ''))));
      }).catch(function(err) {
        ui.addNotification(null, E('p', {}, _('Send error: ' + err)));
      });
    };

    var btn = function(txt, code) {
      var b = el('button', { class: 'hp-key', type: 'button' }, [txt]);
      b.disabled = !sendEnabled;
      b.addEventListener('click', function() {
        if (!sendEnabled) return;
        runSend(code);
      });
      return b;
    };

    var keygrid = el('div', { class: 'hp-keygrid' }, [
      el('div', {}, []),
      btn('Z', 'z'),
      el('div', {}, []),

      btn('-', 'minus'),
      btn('Quit', 'quit'),
      btn('+', 'plus'),

      el('div', {}, []),
      btn('V', 'v'),
      el('div', {}, [])
    ]);

    var pwr = el('div', { class: 'hp-power' }, [
      el('button', { class:'hp-pwrbtn on', type:'button' }, ['Ein']),
      el('button', { class:'hp-pwrbtn off', type:'button' }, ['Aus'])
    ]);
    pwr.querySelectorAll('button').forEach(function(b){ b.disabled = true; });

    var modeHintText = el('div', { class:'hp-sub' }, [sendEnabled
      ? 'Hinweis: Write-Mode aktiv (nur erlaubte Befehle, Mapping teils noch offen).'
      : 'Hinweis: CAN-Senden ist deaktiviert (Safe Read-Only).']);
    var switchStatus = el('div', { class:'hp-status warn' }, ['Konfiguration: unverändert']);
    var sendSwitch = el('input', { type:'checkbox' }, []);
    sendSwitch.checked = sendEnabled;

    var setMode = function(key, enabled, inputEl) {
      var unlock = function() { inputEl.disabled = false; };
      inputEl.disabled = true;
      switchStatus.className = 'hp-status warn';
      switchStatus.textContent = 'Konfiguration: speichere ' + key + '...';
      fs.exec('/usr/libexec/heizungpanel/set_mode.sh', [key, enabled ? '1' : '0']).then(function(res) {
        if (!res || res.code !== 0) {
          inputEl.checked = !enabled;
          switchStatus.className = 'hp-status err';
          switchStatus.textContent = 'Konfiguration: Fehler bei ' + key;
          ui.addNotification(null, E('p', {}, _('Set failed: ' + (res ? res.stdout || res.stderr || res.code : 'n/a'))));
          unlock();
          return;
        }

        if (key === 'write_mode') {
          sendEnabled = enabled;
          modeHintText.textContent = sendEnabled
            ? 'Hinweis: Write-Mode aktiv (nur erlaubte Befehle, Mapping teils noch offen).'
            : 'Hinweis: CAN-Senden ist deaktiviert (Safe Read-Only).';
          window.setTimeout(function() { window.location.reload(); }, 600);
        }

        switchStatus.className = 'hp-status ok';
        switchStatus.textContent = 'Konfiguration: gespeichert (' + key + '=' + (enabled ? '1' : '0') + ').';
        unlock();
      }).catch(function(err) {
        inputEl.checked = !enabled;
        switchStatus.className = 'hp-status err';
        switchStatus.textContent = 'Konfiguration: Fehler bei ' + key;
        ui.addNotification(null, E('p', {}, _('Set error: ' + err)));
        unlock();
      });
    };

    sendSwitch.addEventListener('change', function() {
      setMode('write_mode', sendSwitch.checked, sendSwitch);
    });

    var left = el('div', { class:'hp-left' }, [
      el('div', { class:'hp-row' }, [
        el('div', { class:'lbl' }, ['Tasten']),
        el('div', { class:'hp-sub' }, ['(Senden optional)'])
      ]),
      keygrid,
      pwr,
      modeHintText,
      el('div', { class:'hp-switches' }, [
        el('label', { class:'hp-switch' }, [
          el('span', {}, ['Send mode']),
          sendSwitch
        ])
      ]),
      switchStatus
    ]);

    var mkMode = function(label, code) {
      var led = el('div', { class:'hp-led' }, []);
      var b = el('button', { class:'hp-key', type:'button', style:'width:120px; height:34px;' }, ['⟳']);
      b.disabled = !sendEnabled;
      b.title = 'Send: ' + code;
      b.addEventListener('click', function() {
        if (!sendEnabled) return;
        runSend(code);
      });

      return { node: el('div', { class:'hp-mode' }, [
        el('div', { class:'lbl' }, [label]),
        el('div', { style:'display:flex; align-items:center; gap:10px;' }, [led, b])
      ]), led: led };
    };

    var mDauer = mkMode('Dauerbetrieb', 'dauer');
    var mUhr   = mkMode('Uhrzeitbetrieb', 'uhr');
    var mBoil  = mkMode('Boilerbetrieb', 'boiler');
    var mUB    = mkMode('Uhr+Boilerbetr.', 'uhr_boiler');
    var mAR    = mkMode('Außentemp. Reg.', 'aussen_reg');
    var mPr    = mkMode('Prüfbetrieb', 'pruef');
    var mHand  = mkMode('Handbetrieb', 'hand');
    var modeHint = el('div', { class:'hp-sub' }, ['Modus aus 0x321: n/a']);

    var modeByFlags = {
      '7FFF': { name: 'Dauerbetrieb', led: mDauer.led },
      'BFFF': { name: 'Uhrzeitbetrieb', led: mUhr.led },
      'DFFF': { name: 'Boilerbetrieb', led: mBoil.led },
      'EFFF': { name: 'Uhr+Boilerbetrieb', led: mUB.led },
      'F7FF': { name: 'Außentemperatur-Regelung', led: mAR.led },
      'FBFF': { name: 'Prüfbetrieb', led: mPr.led },
      'FDFF': { name: 'Handbetrieb', led: mHand.led }
    };

    var keyByFlags = {
      'FF7F': 'Z / zurück',
      'FFFB': 'V / weiter',
      'FFDF': '+',
      'FFBF': 'Quit / Sonderfunktion'
    };

    function clearLeds() {
      [mDauer, mUhr, mBoil, mUB, mAR, mPr, mHand].forEach(function(m) {
        m.led.className = 'hp-led';
      });
    }

    var right = el('div', { class:'hp-right' }, [
      el('div', { class:'hp-row' }, [
        el('div', { class:'lbl' }, ['Betriebsarten']),
        el('div', { class:'hp-sub' }, ['LEDs: live aus 0x321'])
      ]),
      el('div', { class:'hp-modes' }, [
        mDauer.node, mUhr.node, mBoil.node, mUB.node, mAR.node, mPr.node, mHand.node
      ]),
      modeHint
    ]);

    var root = el('div', { class:'hp-wrap' }, [
      style,
      el('div', { class:'hp-panel' }, [
        display,
        el('div', { class:'hp-grid' }, [ left, right ])
      ])
    ]);

    var lcd = new Array(32).fill(' ');
    var frameCount = 0;
    var lastFrameAt = 0;
    var state = {
      line1: '                ',
      line2: '                ',
      flags16: '----',
      last_1f5: ''
    };

    var byteToChar = function(hex) {
      var b = parseInt(hex, 16);
      if (hex === 'DF') return '°';
      if (hex === 'E2') return 'ß';
      if (hex === 'F5') return 'ü';
      if (hex === 'E1') return 'ä';
      if (hex === 'EF') return 'ö';
      if (!isNaN(b) && b >= 32 && b <= 126) return String.fromCharCode(b);
      return ' ';
    };

    var lcdIndexFromOffset = function(off) {
      if (off >= 0x00 && off <= 0x0F) return off;
      if (off >= 0x40 && off <= 0x4F) return 16 + (off - 0x40);
      if (off >= 0x10 && off <= 0x1F) return off;
      if (off >= 0x50 && off <= 0x5F) return 16 + (off - 0x50);
      return -1;
    };

    var parseRawFrame = function(line) {
      var m = line.match(/([0-9A-Fa-f]+)#([0-9A-Fa-f]+)/);
      if (m)
        return { id: m[1].toUpperCase(), hex: m[2].toUpperCase() };

      m = line.match(/(?:^|\s)([0-9A-Fa-f]+)\s+\[\s*(\d+)\s*\]\s+(.+)\s*$/);
      if (!m) return null;
      var id = m[1].toUpperCase();
      var want = parseInt(m[2], 10) || 0;
      var tail = m[3];
      var q = tail.indexOf("'");
      if (q >= 0) tail = tail.slice(0, q);
      var bytes = tail.match(/[0-9A-Fa-f]{2}/g) || [];
      if (want > 0 && bytes.length > want) bytes = bytes.slice(0, want);
      if (!bytes.length) return null;
      return { id: id, hex: bytes.join('').toUpperCase() };
    };

    var renderFromState = function(st) {
      var l1 = (st.line1 || '').padEnd(16, ' ').slice(0, 16);
      var l2 = (st.line2 || '').padEnd(16, ' ').slice(0, 16);
      var hasLcdText = !!(l1.trim() || l2.trim());
      var hasFlags = !!(st.flags16 && st.flags16 !== '----');
      var hasAnyPayload = hasLcdText || hasFlags || !!st.last_1f5;
      var flagsNorm = String(st.flags16 || '').replace(/[^0-9A-Fa-f]/g, '').toUpperCase();
      var modeInfo = modeByFlags[flagsNorm];
      var keyInfo = keyByFlags[flagsNorm];

      line1.textContent = l1;
      line2.textContent = l2;
      line1.className = 'l' + (l1.trim() ? '' : ' dim');
      line2.className = 'l' + (l2.trim() ? '' : ' dim');
      lastUpdate.textContent = 'Letzte Aktualisierung: ' + new Date().toLocaleString() + ' (Push)';
      flags.textContent = 'frames: ' + frameCount + '  flags16: ' + (st.flags16 || '----') + '  last_1f5: ' + (st.last_1f5 || '----');

      clearLeds();
      if (modeInfo) {
        modeInfo.led.className = 'hp-led on';
        modeHint.textContent = 'Modus aus 0x321: ' + modeInfo.name + ' (' + flagsNorm + ')';
      } else if (keyInfo) {
        modeHint.textContent = 'Tastenereignis aus 0x321: ' + keyInfo + ' (' + flagsNorm + ')';
      } else if (flagsNorm) {
        modeHint.textContent = '0x321 aktiv, noch nicht zugeordnet: ' + flagsNorm;
      } else {
        modeHint.textContent = 'Modus aus 0x321: n/a';
      }

      if (!hasAnyPayload) {
        status.className = 'hp-status warn';
        status.textContent = 'Status: verbunden, aber noch keine decodierbaren Paneldaten';
      } else {
        status.className = 'hp-status ok';
        status.textContent = 'Status: live (Push/SSE)';
      }
    };

    var applyRawLine = function(line) {
      var f = parseRawFrame(line);
      if (!f) return;
      frameCount++;
      lastFrameAt = Date.now();

      if (f.id === '321' && f.hex.length >= 4) {
        state.flags16 = f.hex.slice(0, 4);
        renderFromState(state);
        return;
      }

      if (f.id === '1F5') {
        state.last_1f5 = f.hex;
        renderFromState(state);
        return;
      }

      if (f.id !== '320' || f.hex.length < 4) return;

      var off = parseInt(f.hex.slice(0, 2), 16);
      if (isNaN(off)) return;
      var base = lcdIndexFromOffset(off);
      if (base < 0) return;

      for (var p = 2; p < f.hex.length; p += 2) {
        var idx = base + ((p - 2) / 2);
        if (idx < 0 || idx >= 32) continue;
        lcd[idx] = byteToChar(f.hex.slice(p, p + 2));
      }

      state.line1 = lcd.slice(0, 16).join('');
      state.line2 = lcd.slice(16, 32).join('');
      renderFromState(state);
    };

    var connectPush = function() {
      if (typeof EventSource === 'undefined') {
        status.className = 'hp-status warn';
        status.textContent = 'Status: Browser ohne EventSource, Fallback auf Polling';
        return false;
      }

      var url = '/cgi-bin/heizungpanel_stream?token=' + encodeURIComponent(streamToken);
      var es = new EventSource(url);
      es.onmessage = function(ev) {
        applyRawLine(ev.data || '');
      };
      es.onerror = function() {
        status.className = 'hp-status warn';
        status.textContent = 'Status: Stream getrennt, automatischer Reconnect aktiv';
      };

      window.setInterval(function() {
        if (!lastFrameAt) return;
        if ((Date.now() - lastFrameAt) > 5000) {
          status.className = 'hp-status warn';
          status.textContent = 'Status: Stream verbunden, aber aktuell keine Frames';
        }
      }, 1000);

      return true;
    };

    var poll = function() {
      return fs.exec('/usr/libexec/heizungpanel/state.sh', []).then(function(res) {
        if (!res || res.code !== 0) {
          status.className = 'hp-status err';
          status.textContent = 'Status: Fehler beim Abruf von state.sh';
          line1.textContent = '                ';
          line2.textContent = '                ';
          line1.className = 'l dim';
          line2.className = 'l dim';
          return;
        }
        var txt = (res.stdout || '').trim();
        if (!txt) {
          status.className = 'hp-status warn';
          status.textContent = 'Status: keine Daten verfügbar';
          line1.textContent = '                ';
          line2.textContent = '                ';
          line1.className = 'l dim';
          line2.className = 'l dim';
          return;
        }
        var st = null;
        try {
          st = JSON.parse(txt);
        } catch(e) {
          status.className = 'hp-status err';
          status.textContent = 'Status: ungültiges JSON im State';
          line1.textContent = '                ';
          line2.textContent = '                ';
          line1.className = 'l dim';
          line2.className = 'l dim';
          return;
        }

        var l1 = (st.line1 || '').padEnd(16, ' ');
        var l2 = (st.line2 || '').padEnd(16, ' ');
        var hasLcdText = !!(l1.trim() || l2.trim());
        var hasFlags = !!(st.flags16 && st.flags16 !== '----');
        var hasAnyPayload = hasLcdText || hasFlags || !!st.last_1f5;
        var flagsNorm = String(st.flags16 || '').replace(/[^0-9A-Fa-f]/g, '').toUpperCase();
        var modeInfo = modeByFlags[flagsNorm];
        var keyInfo = keyByFlags[flagsNorm];

        line1.textContent = l1;
        line2.textContent = l2;
        line1.className = 'l' + (l1.trim() ? '' : ' dim');
        line2.className = 'l' + (l2.trim() ? '' : ' dim');
        var parserTs = parseEpochMs(st.ts_ms);
        var nowTs = Date.now();
        var displayTs = parserTs;
        var suffix = '';

        // Guard against malformed/drifting parser timestamps from target systems.
        if (!displayTs || Math.abs(nowTs - displayTs) > (5 * 60 * 1000)) {
          displayTs = nowTs;
          suffix = ' (Browserzeit)';
        }

        lastUpdate.textContent = 'Letzte Aktualisierung: ' + new Date(displayTs).toLocaleString() + suffix;

        flags.textContent = 'flags16: ' + (st.flags16 || '----') + '  last_1f5: ' + (st.last_1f5 || '----');
        clearLeds();
        if (modeInfo) {
          modeInfo.led.className = 'hp-led on';
          modeHint.textContent = 'Modus aus 0x321: ' + modeInfo.name + ' (' + flagsNorm + ')';
        } else if (keyInfo) {
          modeHint.textContent = 'Tastenereignis aus 0x321: ' + keyInfo + ' (' + flagsNorm + ')';
        } else if (flagsNorm) {
          modeHint.textContent = '0x321 aktiv, noch nicht zugeordnet: ' + flagsNorm;
        } else {
          modeHint.textContent = 'Modus aus 0x321: n/a';
        }

        if (st.status === 'no_data') {
          status.className = 'hp-status warn';
          status.textContent = 'Status: keine Live-Daten (Cache/MQTT leer)';
        } else if (!hasAnyPayload) {
          status.className = 'hp-status warn';
          status.textContent = 'Status: verbunden, aber noch keine decodierbaren Paneldaten';
        } else {
          status.className = 'hp-status ok';
          status.textContent = 'Status: OK';
        }
      });
    };

    if (!connectPush()) {
      poll();
      window.setInterval(poll, pollInterval);
    }

    return root;
  },

  handleSaveApply: null,
  handleSave: null,
  handleReset: null
});
