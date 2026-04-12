'use strict';
'require view';
'require fs';

function el(tag, attrs, children) {
  var n = document.createElement(tag);
  if (attrs) Object.keys(attrs).forEach(function(k) {
    if (k === 'class') n.className = attrs[k];
    else if (k === 'html') n.innerHTML = attrs[k];
    else if (k === 'checked') n.checked = !!attrs[k];
    else n.setAttribute(k, attrs[k]);
  });
  (children || []).forEach(function(c) {
    if (typeof c === 'string') n.appendChild(document.createTextNode(c));
    else if (c) n.appendChild(c);
  });
  return n;
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

function byteAt(data, idx) {
  var pos = idx * 2;
  if (!data || data.length < (pos + 2)) return null;
  var v = parseInt(data.slice(pos, pos + 2), 16);
  return isNaN(v) ? null : v;
}

function fieldValue(data, field) {
  var m = field.match(/^byte([0-6])$/);
  if (m) return byteAt(data, parseInt(m[1], 10));
  if (field === 'u16be_1_2') {
    var b1 = byteAt(data, 1), b2 = byteAt(data, 2);
    if (b1 === null || b2 === null) return null;
    return (b1 << 8) + b2;
  }
  if (field === 'u16le_1_2') {
    var b1l = byteAt(data, 1), b2l = byteAt(data, 2);
    if (b1l === null || b2l === null) return null;
    return (b2l << 8) + b1l;
  }
  return null;
}

function toNum(v, def) {
  var x = parseFloat(v);
  return isNaN(x) ? def : x;
}

var GRAPH_PROFILES = [
  {
    id: 'engineering_generic', title: 'Engineering Generic (0x259 idx00)',
    source: '259', idx: '00', field: 'byte1', label: 'Engineering channel', unit: 'raw',
    scale: '1', offset: '0', confidence: 'unknown', autoscale: '1', ymin: '0', ymax: '255',
    note: 'Sicherer Startpunkt ohne physikalische Interpretation.'
  },
  {
    id: 'io259_idx01_status', title: '0x259 Index 01 Statusbyte',
    source: '259', idx: '01', field: 'byte1', label: '0x259 idx01 byte1', unit: 'raw',
    scale: '1', offset: '0', confidence: 'likely', autoscale: '1', ymin: '0', ymax: '255',
    note: 'Plausibler Statuskanal aus dem Reply-Zyklus; Bedeutung noch feldseitig zu bestätigen.'
  },
  {
    id: 'io259_idx04_param16', title: '0x259 Index 04 u16 (1,2)',
    source: '259', idx: '04', field: 'u16be_1_2', label: '0x259 idx04 u16be(1,2)', unit: 'raw16',
    scale: '1', offset: '0', confidence: 'unknown', autoscale: '1', ymin: '0', ymax: '65535',
    note: 'Nützlich für Parameterblöcke, weiterhin als Engineering-Rohwert markiert.'
  },
  {
    id: 'paired_idx00_delta_b1', title: 'Paired Δ idx00 (259.b1-258.b1)',
    source: 'paired', idx: '00', field: 'paired_delta_1', label: 'paired delta idx00 byte1', unit: 'rawΔ',
    scale: '1', offset: '0', confidence: 'unknown', autoscale: '1', ymin: '-80', ymax: '80',
    note: 'Vergleicht Command-/Reply-Seite je Index; gut für Drift-/Antwortanalyse.'
  }
];

function getProfile(id) {
  for (var i = 0; i < GRAPH_PROFILES.length; i++) {
    if (GRAPH_PROFILES[i].id === id) return GRAPH_PROFILES[i];
  }
  return GRAPH_PROFILES[0];
}

return view.extend({
  load: function() {
    return fs.exec('/usr/libexec/heizungpanel/config_get.sh', []).then(function(res) {
      if (!res || res.code !== 0)
        return { stream_token: '' };
      try {
        return JSON.parse((res.stdout || '').trim() || '{}');
      } catch (e) {
        return { stream_token: '' };
      }
    }).catch(function() {
      return { stream_token: '' };
    });
  },

  render: function(cfg) {
    cfg = cfg || {};
    var streamToken = cfg.stream_token || '';

    var style = el('style', { html: '.hp-sensors{max-width:980px}.hp-card{background:#fff;border:1px solid #ddd;border-radius:8px;padding:14px;margin-bottom:12px}.hp-row{display:flex;gap:8px;align-items:center;flex-wrap:wrap}.hp-status{font-size:12px;color:#555}.hp-mono{font-family:monospace}.hp-graph{width:100%;height:260px;border:1px solid #ccc;background:#fcfcff}.hp-input{width:130px}.hp-note{font-size:12px;color:#666}.hp-ok{color:#2e7d32}.hp-err{color:#c62828}' });

    var profileSel = el('select', { class: 'hp-input' }, GRAPH_PROFILES.map(function(p) {
      return el('option', { value: p.id }, [p.title]);
    }));
    profileSel.value = cfg.sensor_profile || 'engineering_generic';

    var sourceSel = el('select', { class: 'hp-input' }, [
      el('option', { value: '259' }, ['0x259']),
      el('option', { value: '258' }, ['0x258']),
      el('option', { value: 'paired' }, ['paired 258/259'])
    ]);
    sourceSel.value = cfg.sensor_source || getProfile(profileSel.value).source;

    var idxInput = el('input', { type: 'text', class: 'hp-input', value: (cfg.sensor_index || getProfile(profileSel.value).idx), maxlength: 2 }, []);
    var fieldSel = el('select', { class: 'hp-input' }, [
      el('option', { value: 'byte0' }, ['byte0 (index)']),
      el('option', { value: 'byte1' }, ['byte1']),
      el('option', { value: 'byte2' }, ['byte2']),
      el('option', { value: 'byte3' }, ['byte3']),
      el('option', { value: 'byte4' }, ['byte4']),
      el('option', { value: 'byte5' }, ['byte5']),
      el('option', { value: 'byte6' }, ['byte6']),
      el('option', { value: 'u16be_1_2' }, ['u16be(1,2)']),
      el('option', { value: 'u16le_1_2' }, ['u16le(1,2)']),
      el('option', { value: 'paired_delta_1' }, ['paired: 259.b1 - 258.b1']),
      el('option', { value: 'paired_delta_2' }, ['paired: 259.b2 - 258.b2'])
    ]);
    fieldSel.value = cfg.sensor_field || getProfile(profileSel.value).field;

    var labelInput = el('input', { type: 'text', class: 'hp-input', value: cfg.sensor_label || getProfile(profileSel.value).label }, []);
    var unitInput = el('input', { type: 'text', class: 'hp-input', value: cfg.sensor_unit || getProfile(profileSel.value).unit }, []);
    var scaleInput = el('input', { type: 'text', class: 'hp-input', value: cfg.sensor_scale || getProfile(profileSel.value).scale }, []);
    var offsetInput = el('input', { type: 'text', class: 'hp-input', value: cfg.sensor_offset || getProfile(profileSel.value).offset }, []);

    var confSel = el('select', { class: 'hp-input' }, [
      el('option', { value: 'confirmed' }, ['confirmed']),
      el('option', { value: 'likely' }, ['likely']),
      el('option', { value: 'unknown' }, ['unknown'])
    ]);
    confSel.value = cfg.sensor_confidence || getProfile(profileSel.value).confidence;

    var autoscaleChk = el('input', { type: 'checkbox', checked: String(cfg.sensor_autoscale || getProfile(profileSel.value).autoscale) === '1' }, []);
    var yminInput = el('input', { type: 'text', class: 'hp-input', value: cfg.sensor_y_min || getProfile(profileSel.value).ymin }, []);
    var ymaxInput = el('input', { type: 'text', class: 'hp-input', value: cfg.sensor_y_max || getProfile(profileSel.value).ymax }, []);

    var status = el('div', { class: 'hp-status' }, ['Status: warte auf Raw-SSE ...']);
    var latest = el('div', { class: 'hp-mono' }, ['letzter Frame: n/a']);
    var meta = el('div', { class: 'hp-note' }, ['']);
    var profileNote = el('div', { class: 'hp-note' }, ['']);

    var points = [];
    var maxPoints = 180;
    var last258ByIdx = {};
    var last259ByIdx = {};

    var svg = el('svg', { class: 'hp-graph', viewBox: '0 0 760 260', preserveAspectRatio: 'none' }, []);
    var grid = el('g', {}, []);
    var path = el('polyline', { fill: 'none', stroke: '#2a6fdb', 'stroke-width': '2', points: '' }, []);
    var yLabelTop = el('text', { x: '6', y: '14', fill: '#777', 'font-size': '11' }, ['']);
    var yLabelBottom = el('text', { x: '6', y: '252', fill: '#777', 'font-size': '11' }, ['']);

    for (var gy = 0; gy <= 5; gy++) {
      var y = 10 + gy * 40;
      grid.appendChild(el('line', { x1: '0', y1: String(y), x2: '760', y2: String(y), stroke: '#e9edf5', 'stroke-width': '1' }, []));
    }
    svg.appendChild(grid);
    svg.appendChild(path);
    svg.appendChild(yLabelTop);
    svg.appendChild(yLabelBottom);

    function selectedIndex() {
      return String(idxInput.value || '').toUpperCase().replace(/[^0-9A-F]/g, '').slice(0, 2).padStart(2, '0');
    }

    function graphCfg() {
      return {
        profile: profileSel.value,
        source: sourceSel.value,
        field: fieldSel.value,
        idx: selectedIndex(),
        label: labelInput.value || 'Engineering channel',
        unit: unitInput.value || 'raw',
        scale: toNum(scaleInput.value, 1),
        offset: toNum(offsetInput.value, 0),
        confidence: confSel.value || 'unknown',
        autoscale: !!autoscaleChk.checked,
        ymin: toNum(yminInput.value, 0),
        ymax: toNum(ymaxInput.value, 255)
      };
    }

    function applyProfile(p) {
      if (!p) return;
      sourceSel.value = p.source;
      idxInput.value = p.idx;
      fieldSel.value = p.field;
      labelInput.value = p.label;
      unitInput.value = p.unit;
      scaleInput.value = p.scale;
      offsetInput.value = p.offset;
      confSel.value = p.confidence;
      autoscaleChk.checked = String(p.autoscale) === '1';
      yminInput.value = p.ymin;
      ymaxInput.value = p.ymax;
      profileNote.textContent = 'Profil: ' + p.title + ' · ' + p.note;
    }

    function updateMeta() {
      var c = graphCfg();
      var sem = (c.confidence === 'unknown') ? 'raw engineering data (semantics unknown)' : 'configured interpretation';
      meta.textContent = 'Profil=' + c.profile + ' · Quelle=' + c.source + ' · Index=0x' + c.idx + ' · Feld=' + c.field + ' · Confidence=' + c.confidence + ' · ' + sem;
    }

    function redraw() {
      if (!points.length) {
        path.setAttribute('points', '');
        yLabelTop.textContent = '';
        yLabelBottom.textContent = '';
        return;
      }
      var c = graphCfg();
      var minv = c.ymin;
      var maxv = c.ymax;
      if (c.autoscale) {
        minv = points[0].y;
        maxv = points[0].y;
        for (var i = 1; i < points.length; i++) {
          if (points[i].y < minv) minv = points[i].y;
          if (points[i].y > maxv) maxv = points[i].y;
        }
        if (Math.abs(maxv - minv) < 0.001) maxv = minv + 1;
      }
      if (maxv <= minv) maxv = minv + 1;

      var out = [];
      for (var p = 0; p < points.length; p++) {
        var x = (p / Math.max(1, maxPoints - 1)) * 760;
        var n = (points[p].y - minv) / (maxv - minv);
        var y = 250 - (n * 235);
        out.push(x.toFixed(1) + ',' + y.toFixed(1));
      }
      path.setAttribute('points', out.join(' '));
      yLabelTop.textContent = maxv.toFixed(2) + ' ' + c.unit;
      yLabelBottom.textContent = minv.toFixed(2) + ' ' + c.unit;
      status.textContent = 'Status: live · ' + c.label + ' (' + c.unit + ')';
    }

    function pushSample(val, origin) {
      var c = graphCfg();
      var y = (val * c.scale) + c.offset;
      points.push({ y: y, raw: val, source: origin, ts: Date.now() });
      if (points.length > maxPoints) points.shift();
      redraw();
      updateMeta();
    }

    function extractValue(c, f258, f259) {
      if (c.source === '258') {
        if (!f258) return null;
        return fieldValue(f258.data, c.field);
      }
      if (c.source === '259') {
        if (!f259) return null;
        return fieldValue(f259.data, c.field);
      }
      if (c.field === 'paired_delta_1') {
        var a1 = f258 ? byteAt(f258.data, 1) : null;
        var b1 = f259 ? byteAt(f259.data, 1) : null;
        if (a1 === null || b1 === null) return null;
        return b1 - a1;
      }
      if (c.field === 'paired_delta_2') {
        var a2 = f258 ? byteAt(f258.data, 2) : null;
        var b2 = f259 ? byteAt(f259.data, 2) : null;
        if (a2 === null || b2 === null) return null;
        return b2 - a2;
      }
      if (!f259) return null;
      return fieldValue(f259.data, c.field);
    }

    function onRaw(line) {
      var f = parseCandump(line || '');
      if (!f || (f.id !== '258' && f.id !== '259') || f.data.length < 2)
        return;

      var idx = f.data.slice(0, 2).toUpperCase();
      if (f.id === '258') last258ByIdx[idx] = f;
      if (f.id === '259') last259ByIdx[idx] = f;

      var c = graphCfg();
      if (idx !== c.idx) return;

      var sample = extractValue(c, last258ByIdx[idx], last259ByIdx[idx]);
      if (sample === null || isNaN(sample)) return;

      pushSample(sample, f.id);
      latest.textContent = 'letzter Frame: ' + f.id + '#' + f.data;
    }

    function clearGraph() {
      points = [];
      redraw();
      updateMeta();
    }

    function saveConfig() {
      var c = graphCfg();
      var payload = {
        sensor_profile: c.profile,
        sensor_source: c.source,
        sensor_index: c.idx,
        sensor_field: c.field,
        sensor_label: c.label,
        sensor_unit: c.unit,
        sensor_scale: String(c.scale),
        sensor_offset: String(c.offset),
        sensor_confidence: c.confidence,
        sensor_autoscale: c.autoscale ? '1' : '0',
        sensor_y_min: String(c.ymin),
        sensor_y_max: String(c.ymax)
      };
      return fs.exec('/usr/libexec/heizungpanel/config_set.sh', ['--batch-json', JSON.stringify(payload)]).then(function(res) {
        if (res && res.code === 0) {
          status.className = 'hp-status hp-ok';
          status.textContent = 'Graph-Profil gespeichert.';
          return;
        }
        status.className = 'hp-status hp-err';
        status.textContent = 'Speichern fehlgeschlagen: ' + (res ? (res.stderr || res.stdout || res.code) : 'n/a');
      }).catch(function(err) {
        status.className = 'hp-status hp-err';
        status.textContent = 'Speichern fehlgeschlagen: ' + err;
      });
    }

    var applyProfileBtn = el('button', { class: 'btn cbi-button', type: 'button' }, ['Profil übernehmen']);
    applyProfileBtn.addEventListener('click', function() {
      applyProfile(getProfile(profileSel.value));
      clearGraph();
    });

    var clearBtn = el('button', { class: 'btn cbi-button', type: 'button' }, ['Graph leeren']);
    clearBtn.addEventListener('click', clearGraph);
    var saveBtn = el('button', { class: 'btn cbi-button cbi-button-save', type: 'button' }, ['Graph-Profil speichern']);
    saveBtn.addEventListener('click', function() { saveConfig(); });

    [sourceSel, idxInput, fieldSel, labelInput, unitInput, scaleInput, offsetInput, confSel, autoscaleChk, yminInput, ymaxInput, profileSel].forEach(function(node) {
      node.addEventListener('change', function() { updateMeta(); });
    });

    applyProfile(getProfile(profileSel.value));
    if (cfg.sensor_source) sourceSel.value = cfg.sensor_source;
    if (cfg.sensor_index) idxInput.value = cfg.sensor_index;
    if (cfg.sensor_field) fieldSel.value = cfg.sensor_field;
    if (cfg.sensor_label) labelInput.value = cfg.sensor_label;
    if (cfg.sensor_unit) unitInput.value = cfg.sensor_unit;
    if (cfg.sensor_scale) scaleInput.value = cfg.sensor_scale;
    if (cfg.sensor_offset) offsetInput.value = cfg.sensor_offset;
    if (cfg.sensor_confidence) confSel.value = cfg.sensor_confidence;
    if (cfg.sensor_autoscale !== undefined) autoscaleChk.checked = String(cfg.sensor_autoscale) === '1';
    if (cfg.sensor_y_min) yminInput.value = cfg.sensor_y_min;
    if (cfg.sensor_y_max) ymaxInput.value = cfg.sensor_y_max;

    updateMeta();

    var es = null;
    function closeStream() {
      if (es) {
        es.close();
        es = null;
      }
    }

    if (typeof EventSource !== 'undefined') {
      es = new EventSource('/cgi-bin/heizungpanel_stream?mode=raw&token=' + encodeURIComponent(streamToken));
      es.onmessage = function(ev) { onRaw(ev.data || ''); };
      es.onerror = function() { status.textContent = 'Status: Raw-Stream getrennt, Reconnect aktiv ...'; };
      window.addEventListener('beforeunload', closeStream);
      window.addEventListener('pagehide', closeStream);
      document.addEventListener('visibilitychange', function() {
        if (document.visibilityState === 'hidden') closeStream();
      });
    } else {
      status.textContent = 'Status: EventSource fehlt, diese Seite benötigt Raw-SSE';
    }

    return el('div', { class: 'hp-sensors' }, [
      style,
      el('h2', {}, ['Heizungpanel – Engineering/Sensor Graph Profiles']),
      el('div', { class: 'hp-card' }, [
        el('div', { class: 'hp-note' }, ['Profile liefern sinnvolle Seed-Werte für bekannte/verdächtige Kanäle. Unbekannte Semantik bleibt explizit als Raw-Engineering markiert.']),
        el('div', { class: 'hp-row' }, [
          el('label', {}, ['Profil']), profileSel, applyProfileBtn
        ]),
        profileNote,
        el('div', { class: 'hp-row' }, [
          el('label', {}, ['Quelle']), sourceSel,
          el('label', {}, ['Index']), idxInput,
          el('label', {}, ['Feld']), fieldSel
        ]),
        el('div', { class: 'hp-row' }, [
          el('label', {}, ['Label']), labelInput,
          el('label', {}, ['Unit']), unitInput,
          el('label', {}, ['Confidence']), confSel
        ]),
        el('div', { class: 'hp-row' }, [
          el('label', {}, ['Scale']), scaleInput,
          el('label', {}, ['Offset']), offsetInput,
          el('label', {}, ['Autoscale']), autoscaleChk,
          el('label', {}, ['Y min']), yminInput,
          el('label', {}, ['Y max']), ymaxInput
        ]),
        el('div', { class: 'hp-row' }, [clearBtn, saveBtn]),
        meta,
        status,
        latest,
        svg
      ])
    ]);
  },

  handleSaveApply: null,
  handleSave: null,
  handleReset: null
});
