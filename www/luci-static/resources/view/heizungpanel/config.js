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

return view.extend({
  load: function() {
    return fs.exec('/usr/libexec/heizungpanel/config_get.sh', []).then(function(res) {
      if (!res || res.code !== 0)
        return {};
      try {
        return JSON.parse((res.stdout || '').trim() || '{}');
      } catch (e) {
        return {};
      }
    }).catch(function() { return {}; });
  },

  render: function(cfg) {
    cfg = cfg || {};

    var style = el('style', { html: [
      '.hp-cfg { max-width: 880px; }',
      '.hp-card { background:#fff; border:1px solid #ddd; border-radius:8px; padding:14px; margin-bottom:12px; }',
      '.hp-row { display:grid; grid-template-columns: 230px 1fr; gap:8px; align-items:center; margin-bottom:8px; }',
      '.hp-row input { width:100%; max-width:420px; }',
      '.hp-status { font-size:12px; margin-top:10px; }',
      '.hp-ok { color:#2e7d32; }',
      '.hp-err { color:#c62828; }',
      '.hp-warn { color:#ef6c00; }',
      '.hp-note { font-size:12px; color:#555; margin-bottom:6px; }'
    ].join('\n') });

    function mkRow(label, key, value, note, type) {
      var inp = el('input', { type: type || 'text', value: value || '' }, []);
      return {
        key: key,
        input: inp,
        node: el('div', { class: 'hp-row' }, [
          el('label', {}, [label]),
          el('div', {}, [inp, note ? el('div', { class: 'hp-note' }, [note]) : null])
        ])
      };
    }

    var rowsApp = [
      mkRow('CAN Interface', 'can_if', cfg.can_if || 'can0', 'Beispiel: can0'),
      mkRow('CAN Bitrate', 'can_bitrate', cfg.can_bitrate || '69144', '10000..1000000', 'number'),
      mkRow('Polling-Intervall (ms)', 'poll_interval_ms', cfg.poll_interval_ms || '500', '250..10000', 'number'),
      mkRow('Write-Mode (0/1)', 'write_mode', cfg.write_mode || '0', '0 = Read-only, 1 = Senden aktivieren', 'number')
    ];

    var rowsMqtt = [
      mkRow('MQTT Host', 'mqtt_host', cfg.mqtt_host || '127.0.0.1', 'Broker-Adresse für die Heizungpanel-App.'),
      mkRow('MQTT Port', 'mqtt_port', cfg.mqtt_port || '1883', '1..65535', 'number'),
      mkRow('MQTT Base Topic', 'mqtt_base', cfg.mqtt_base || 'heizungpanel', 'Keine Wildcards (#,+), kein führendes/trailing /.'),
      mkRow('Stream Token (hex)', 'stream_token', cfg.stream_token || '', 'Hex, 16..128 Zeichen oder leer')
    ];

    var status = el('div', { class: 'hp-status hp-warn' }, ['Status: bereit']);

    function saveAll(rows) {
      var payload = {};
      rows.forEach(function(r) {
        payload[r.key] = r.input.value;
      });

      return fs.exec('/usr/libexec/heizungpanel/config_set.sh', ['--batch-json', JSON.stringify(payload)]).then(function(res) {
        if (res && res.code === 0) {
          status.className = 'hp-status hp-ok';
          status.textContent = 'Konfiguration atomar gespeichert (ein Commit, ein Restart).';
          return true;
        }

        status.className = 'hp-status hp-err';
        status.textContent = 'Fehler beim Speichern: ' + (res ? (res.stderr || res.stdout || res.code) : 'n/a');
        return false;
      }).catch(function(err) {
        status.className = 'hp-status hp-err';
        status.textContent = 'Fehler beim Speichern: ' + err;
        return false;
      });
    }

    var allRows = rowsApp.concat(rowsMqtt);

    var saveBtn = el('button', { class: 'btn cbi-button cbi-button-save', type: 'button' }, ['Alle speichern']);
    saveBtn.addEventListener('click', function() {
      status.className = 'hp-status hp-warn';
      status.textContent = 'Speichere Konfiguration ...';
      saveBtn.disabled = true;
      saveAll(allRows).then(function(ok) {
        saveBtn.disabled = false;
        if (ok) {
          status.className = 'hp-status hp-ok';
          status.textContent = 'Konfiguration gespeichert. Seite wird neu geladen ...';
          window.setTimeout(function() { window.location.reload(); }, 900);
        }
      });
    });

    function card(title, rows) {
      var n = [el('h3', {}, [title])];
      rows.forEach(function(r) { n.push(r.node); });
      return el('div', { class: 'hp-card' }, n);
    }

    return el('div', { class: 'hp-cfg' }, [
      style,
      el('h2', {}, ['Heizungpanel – Slim Konfiguration']),
      el('div', { class: 'hp-note' }, ['Diese Seite verwaltet nur die Heizungpanel-App-Konfiguration in /etc/config/heizungpanel.']),
      card('App', rowsApp),
      card('MQTT', rowsMqtt),
      saveBtn,
      status
    ]);
  }
});
