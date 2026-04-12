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
        return { stream_token: '' };
      try {
        var cfg = JSON.parse((res.stdout || '').trim() || '{}');
        return { stream_token: cfg.stream_token || '' };
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

    var style = el('style', { html: '.hp-sensors{max-width:880px}.hp-card{background:#fff;border:1px solid #ddd;border-radius:8px;padding:14px;margin-bottom:12px}.hp-row{display:flex;gap:8px;align-items:center}.hp-status{font-size:12px;color:#555}.hp-mono{font-family:monospace}.hp-graph{width:100%;height:220px;border:1px solid #ccc;background:#fcfcff}' });

    var idxInput = el('input', { type: 'text', value: '00', maxlength: 2, size: 4 }, []);
    var status = el('div', { class: 'hp-status' }, ['Status: warte auf 0x259 Frames ...']);
    var latest = el('div', { class: 'hp-mono' }, ['letzter Frame: n/a']);
    var points = [];
    var maxPoints = 120;

    var svg = el('svg', { class: 'hp-graph', viewBox: '0 0 640 220', preserveAspectRatio: 'none' }, []);
    var poly = el('polyline', { fill: 'none', stroke: '#2a6fdb', 'stroke-width': '2', points: '' }, []);
    var grid = el('g', {}, []);
    for (var y = 0; y <= 4; y++) {
      var yy = 10 + y * 50;
      grid.appendChild(el('line', { x1: '0', y1: String(yy), x2: '640', y2: String(yy), stroke: '#e9edf5', 'stroke-width': '1' }, []));
    }
    svg.appendChild(grid);
    svg.appendChild(poly);

    function selectedIndex() {
      return String(idxInput.value || '').toUpperCase().replace(/[^0-9A-F]/g, '').slice(0, 2).padStart(2, '0');
    }

    function redraw() {
      if (!points.length) {
        poly.setAttribute('points', '');
        return;
      }
      var p = [];
      var i;
      for (i = 0; i < points.length; i++) {
        var x = (i / Math.max(1, (maxPoints - 1))) * 640;
        var y = 210 - ((points[i] / 255) * 200);
        p.push(x.toFixed(1) + ',' + y.toFixed(1));
      }
      poly.setAttribute('points', p.join(' '));
    }

    function onRaw(line) {
      var f = parseCandump(line || '');
      if (!f || f.id !== '259' || f.data.length < 4)
        return;

      var idx = f.data.slice(0, 2).toUpperCase();
      if (idx !== selectedIndex())
        return;

      var b1 = parseInt(f.data.slice(2, 4), 16);
      if (isNaN(b1)) return;

      points.push(b1);
      if (points.length > maxPoints) points.shift();

      redraw();
      latest.textContent = 'letzter Frame: 259#' + f.data;
      status.textContent = 'Status: live 0x259 für Index 0x' + idx + ' (Y = Byte1, 0..255)';
    }

    idxInput.addEventListener('change', function() {
      points = [];
      redraw();
      status.textContent = 'Status: Indexwechsel auf 0x' + selectedIndex() + ', warte auf neue Frames ...';
    });

    var clearBtn = el('button', { class: 'btn cbi-button', type: 'button' }, ['Graph leeren']);
    clearBtn.addEventListener('click', function() {
      points = [];
      redraw();
    });

    if (typeof EventSource !== 'undefined') {
      var url = '/cgi-bin/heizungpanel_stream?mode=raw&token=' + encodeURIComponent(streamToken);
      var es = new EventSource(url);
      es.onmessage = function(ev) { onRaw(ev.data || ''); };
      es.onerror = function() { status.textContent = 'Status: Raw-Stream getrennt, Reconnect aktiv ...'; };
    } else {
      status.textContent = 'Status: EventSource fehlt, diese Seite benötigt Raw-SSE';
    }

    return el('div', { class: 'hp-sensors' }, [
      style,
      el('h2', {}, ['Heizungpanel – Sensor Graph (Engineering)']),
      el('div', { class: 'hp-card' }, [
        el('div', {}, ['Live-Visualisierung für CAN-ID 0x259. Operator-Bedienung bleibt auf der Panel-Seite.']),
        el('div', { class: 'hp-row' }, [el('label', {}, ['Index (hex):']), idxInput, clearBtn]),
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
