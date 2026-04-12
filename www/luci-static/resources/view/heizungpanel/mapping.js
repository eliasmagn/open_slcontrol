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

    var style = el('style', { html: '.hp-map{max-width:980px}.hp-note{font-size:12px;color:#555;margin-bottom:8px}.hp-card{background:#fff;border:1px solid #ddd;border-radius:8px;padding:14px;margin-bottom:12px}.hp-row{display:grid;grid-template-columns:140px 130px 1fr 110px;gap:8px;align-items:center;margin-bottom:6px}.hp-row input{width:100px}.hp-status{font-size:12px}.hp-ok{color:#2e7d32}.hp-err{color:#c62828}.hp-muted{color:#777}' });

    var idRows = [
      ['0x320', 'display data + display status', 'Textsegmente + 0x81/0x82/0x83 Commit/Status'],
      ['0x321', 'panel keys / panel return path', 'Durable Modus-Latch + transiente Key-Events'],
      ['0x258', 'command/setpoint side to external I/O module', 'Index-basierter Zyklus'],
      ['0x259', 'measurement/status reply from external I/O module', 'Index-basierter Zyklus ohne harte Physikzuordnung'],
      ['0x1F5', 'separate time/status channel', 'separater Zeit/Status-Kanal']
    ];

    var rowsDef = [
      { key: 'uhr', conf: 'safe default', note: 'confirmed', value: cfg.mapping_uhr || 'BFFF' },
      { key: 'boiler', conf: 'safe default', note: 'confirmed', value: cfg.mapping_boiler || 'DFFF' },
      { key: 'uhr_boiler', conf: 'safe default', note: 'confirmed', value: cfg.mapping_uhr_boiler || 'EFFF' },
      { key: 'dauer', conf: 'safe default', note: 'confirmed', value: cfg.mapping_dauer || '7FFF' },
      { key: 'v', conf: 'safe default', note: 'confirmed', value: cfg.mapping_v || 'FFFB' },
      { key: 'z', conf: 'safe default', note: 'confirmed', value: cfg.mapping_z || 'FF7F' },
      { key: 'quit', conf: 'safe default', note: 'confirmed', value: cfg.mapping_quit || 'FFBF' },
      { key: 'hand', conf: 'likely default', note: 'editable likely', value: cfg.mapping_hand || 'FDFF' },
      { key: 'aussen_reg', conf: 'likely default', note: 'editable likely', value: cfg.mapping_aussen_reg || 'F7FF' },
      { key: 'pruef', conf: 'likely default', note: 'editable likely', value: cfg.mapping_pruef || 'FBFF' },
      { key: 'plus', conf: 'likely default', note: 'editable likely', value: cfg.mapping_plus || 'FFDF' },
      { key: 'ein', conf: 'placeholder', note: 'unknown/unconfirmed', value: cfg.mapping_ein || '' },
      { key: 'aus', conf: 'placeholder', note: 'unknown/unconfirmed', value: cfg.mapping_aus || '' },
      { key: 'minus', conf: 'placeholder', note: 'unknown/unconfirmed', value: cfg.mapping_minus || '' }
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
      uiRows.push({ key: 'mapping_' + def.key, input: inp, def: def });
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

    function resetDefaults() {
      uiRows.forEach(function(r) {
        r.input.value = normHex(r.def.value || '');
      });
      status.className = 'hp-status hp-muted';
      status.textContent = 'Defaults geladen (noch nicht gespeichert).';
    }

    var saveBtn = el('button', { class: 'btn cbi-button cbi-button-save', type: 'button' }, ['Mapping speichern']);
    saveBtn.addEventListener('click', function() {
      saveBtn.disabled = true;
      saveMappings().then(function() { saveBtn.disabled = false; });
    });

    var resetBtn = el('button', { class: 'btn cbi-button', type: 'button' }, ['Defaults neu laden']);
    resetBtn.addEventListener('click', resetDefaults);

    return el('div', { class: 'hp-map' }, [
      style,
      el('h2', {}, ['Heizungpanel – Engineering Mapping']),
      el('div', { class: 'hp-note' }, ['Produktionsnutzung: sichere Defaults + likely Defaults sind vorbefüllt; unbestätigte Felder bleiben bewusst als Platzhalter.']),
      el('div', { class: 'hp-card' }, [
        el('h3', {}, ['CAN ID Rollen']),
        table(['ID', 'Rolle', 'Hinweis'], idRows)
      ]),
      (function() {
        var children = [
          el('h3', {}, ['Command Mapping (UCI: heizungpanel.main.mapping_*)']),
          el('div', { class: 'hp-note' }, ['Safe defaults: uhr/boiler/uhr_boiler/dauer/v/z/quit · Likely defaults: hand/aussen_reg/pruef/plus · Placeholders: ein/aus/minus.']),
          el('div', { class: 'hp-row hp-muted' }, [el('strong', {}, ['Command']), el('strong', {}, ['Confidence']), el('strong', {}, ['Status']), el('strong', {}, ['0x321 Payload'])])
        ];
        rowsDef.forEach(function(r) { children.push(mkRow(r)); });
        children.push(el('div', { class: 'hp-row' }, [resetBtn, saveBtn, el('div', {}, []), el('div', {}, [])]));
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
