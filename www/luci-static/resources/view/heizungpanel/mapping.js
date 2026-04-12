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

function table(headers, rows) {
  var thead = el('thead', {}, [el('tr', {}, headers.map(function(h) { return el('th', {}, [h]); }))]);
  var tbody = el('tbody', {}, rows.map(function(r) {
    return el('tr', {}, r.map(function(c) { return el('td', {}, [c]); }));
  }));
  return el('table', { class: 'table cbi-section-table' }, [thead, tbody]);
}

function normHex(v) {
  return String(v || '').toUpperCase().replace(/[^0-9A-F]/g, '').slice(0, 4);
}

return view.extend({
  load: function() {
    return fs.exec('/usr/libexec/heizungpanel/config_get.sh', []).then(function(res) {
      if (!res || res.code !== 0) return {};
      try { return JSON.parse((res.stdout || '').trim() || '{}'); } catch (e) { return {}; }
    }).catch(function() { return {}; });
  },

  render: function(cfg) {
    cfg = cfg || {};

    var style = el('style', { html: '.hp-map{max-width:980px}.hp-note{font-size:12px;color:#555;margin-bottom:8px}.hp-card{background:#fff;border:1px solid #ddd;border-radius:8px;padding:14px;margin-bottom:12px}.hp-row{display:grid;grid-template-columns:120px 110px 1fr 110px;gap:8px;align-items:center;margin-bottom:6px}.hp-row input{width:100px}.hp-status{font-size:12px}.hp-ok{color:#2e7d32}.hp-err{color:#c62828}.hp-muted{color:#777}' });

    var idRows = [
      ['0x320', 'display data / display status', 'Textsegmente + 0x81/0x82/0x83 Commit'],
      ['0x321', 'panel keys / panel return path', 'Panel-Tasten und Modus-Flags'],
      ['0x258', 'command/setpoint side to external I/O module', 'Index-basierter Zyklus, kein Displayprotokoll'],
      ['0x259', 'measurement/status reply from external I/O module', 'Index-basierter Zyklus, keine direkte Sensor-Einheit ohne Mapping'],
      ['0x1F5', 'separate time/status channel', 'separater Zeit/Status-Kanal']
    ];

    var rowsDef = [
      { key: 'uhr', conf: 'confirmed default', note: 'safe default', value: cfg.mapping_uhr || 'BFFF' },
      { key: 'boiler', conf: 'confirmed default', note: 'safe default', value: cfg.mapping_boiler || 'DFFF' },
      { key: 'uhr_boiler', conf: 'confirmed default', note: 'safe default', value: cfg.mapping_uhr_boiler || 'EFFF' },
      { key: 'dauer', conf: 'confirmed default', note: 'safe default', value: cfg.mapping_dauer || '7FFF' },
      { key: 'v', conf: 'confirmed default', note: 'safe default', value: cfg.mapping_v || 'FFFB' },
      { key: 'z', conf: 'confirmed default', note: 'safe default', value: cfg.mapping_z || 'FF7F' },
      { key: 'quit', conf: 'confirmed default', note: 'safe default', value: cfg.mapping_quit || 'FFBF' },
      { key: 'hand', conf: 'likely default', note: 'editable default', value: cfg.mapping_hand || 'FDFF' },
      { key: 'aussen_reg', conf: 'likely default', note: 'editable default', value: cfg.mapping_aussen_reg || 'F7FF' },
      { key: 'pruef', conf: 'likely default', note: 'editable default', value: cfg.mapping_pruef || 'FBFF' },
      { key: 'plus', conf: 'likely default', note: 'editable default', value: cfg.mapping_plus || 'FFDF' },
      { key: 'ein', conf: 'unknown', note: 'unmapped placeholder', value: cfg.mapping_ein || '' },
      { key: 'aus', conf: 'unknown', note: 'unmapped placeholder', value: cfg.mapping_aus || '' },
      { key: 'minus', conf: 'unknown', note: 'unmapped placeholder', value: cfg.mapping_minus || '' }
    ];

    var status = el('div', { class: 'hp-status hp-muted' }, ['Status: bereit']);
    var uiRows = [];

    function mkRow(def) {
      var inp = el('input', { type: 'text', maxlength: 4, value: def.value }, []);
      inp.addEventListener('input', function() { inp.value = normHex(inp.value); });
      var row = el('div', { class: 'hp-row' }, [
        el('div', { class: 'hp-mono' }, [def.key]),
        el('input', { type: 'text', readonly: 'readonly', value: def.conf }, []),
        el('div', { class: 'hp-note' }, [def.note + ' · leer = nicht gemappt']),
        inp
      ]);
      uiRows.push({ key: 'mapping_' + def.key, input: inp });
      return row;
    }

    function saveMappings() {
      var payload = {};
      uiRows.forEach(function(r) { payload[r.key] = normHex(r.input.value); });
      status.className = 'hp-status hp-muted';
      status.textContent = 'Speichere Mapping ...';
      return fs.exec('/usr/libexec/heizungpanel/config_set.sh', ['--batch-json', JSON.stringify(payload)]).then(function(res) {
        if (res && res.code === 0) {
          status.className = 'hp-status hp-ok';
          status.textContent = 'Mapping gespeichert, Runtime neu gestartet.';
          return;
        }
        status.className = 'hp-status hp-err';
        status.textContent = 'Fehler: ' + (res ? (res.stderr || res.stdout || res.code) : 'n/a');
      }).catch(function(err) {
        status.className = 'hp-status hp-err';
        status.textContent = 'Fehler: ' + err;
      });
    }

    var saveBtn = el('button', { class: 'btn cbi-button cbi-button-save', type: 'button' }, ['Mapping speichern']);
    saveBtn.addEventListener('click', function() {
      saveBtn.disabled = true;
      saveMappings().then(function() { saveBtn.disabled = false; });
    });

    return el('div', { class: 'hp-map' }, [
      style,
      el('h2', {}, ['Heizungpanel – Mapping & Engineering']),
      el('div', { class: 'hp-note' }, ['Diese Seite kombiniert Engineering-Status und editierbare UCI-Command-Mappings für press.sh.']),
      el('div', { class: 'hp-card' }, [
        el('h3', {}, ['CAN ID Rollen']),
        table(['ID', 'Rolle', 'Hinweis'], idRows)
      ]),
      (function() {
        var children = [
          el('h3', {}, ['Command Mapping (UCI: heizungpanel.main.mapping_*)']),
          el('div', { class: 'hp-note' }, ['Sichere Defaults und likely Defaults sind vorbefüllt. ein/aus/minus bleiben standardmäßig leer bis Feldvalidierung vorliegt.']),
          el('div', { class: 'hp-row hp-muted' }, [el('strong', {}, ['Command']), el('strong', {}, ['Confidence']), el('strong', {}, ['Status']), el('strong', {}, ['0x321 Payload'])])
        ];
        rowsDef.forEach(function(r) { children.push(mkRow(r)); });
        children.push(saveBtn);
        children.push(status);
        return el('div', { class: 'hp-card' }, children);
      })(),
      el('div', { class: 'hp-note' }, ['Write-Safety bleibt erhalten: press.sh sendet nur bei write_mode=1 und validem hex-Mapping.'])
    ]);
  },

  handleSaveApply: null,
  handleSave: null,
  handleReset: null
});
