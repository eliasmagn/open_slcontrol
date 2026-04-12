'use strict';
'require view';

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

return view.extend({
  render: function() {
    var style = el('style', { html: '.hp-map{max-width:980px}.hp-note{font-size:12px;color:#555;margin-bottom:8px}.hp-card{background:#fff;border:1px solid #ddd;border-radius:8px;padding:14px;margin-bottom:12px}' });

    var idRows = [
      ['0x320', 'LCD Rohdaten (Textsegmente + 0x81/0x83 Marker)', 'Primärquelle für Live-Display im Browser'],
      ['0x321', 'Mode/Panel-Flags', 'Durable Modus-Latch für LEDs + transientes current-Topic'],
      ['0x258', 'Sensor Index', 'Korrelation mit 0x259'],
      ['0x259', 'Sensor Werte', 'Engineering-Visualisierung auf eigener Sensor-Seite'],
      ['0x1F5', 'Weitere Zustandsframes', 'Derzeit nur beobachtet']
    ];

    var cmdRows = [
      ['dauer', '321#7FFF', 'persistenter Modus'],
      ['uhr', '321#BFFF', 'persistenter Modus'],
      ['boiler', '321#DFFF', 'persistenter Modus'],
      ['uhr_boiler', '321#EFFF', 'persistenter Modus'],
      ['aussen_reg', '321#F7FF', 'persistenter Modus'],
      ['pruef', '321#FBFF', 'persistenter Modus'],
      ['hand', '321#FDFF', 'persistenter Modus'],
      ['v', '321#FFFB', 'transient / Navigation'],
      ['z', '321#FF7F', 'transient / Navigation'],
      ['quit', '321#FFBF', 'transient / Navigation'],
      ['ein', 'nicht gemappt', 'aktuell nur UI-Button, kein Send-Mapping'],
      ['aus', 'nicht gemappt', 'aktuell nur UI-Button, kein Send-Mapping']
    ];

    return el('div', { class: 'hp-map' }, [
      style,
      el('h2', {}, ['Heizungpanel – Reverse Engineering Mapping']),
      el('div', { class: 'hp-note' }, ['Diese Seite ist bewusst engineering-orientiert und vom Operator-Panel getrennt.']),
      el('div', { class: 'hp-card' }, [
        el('h3', {}, ['CAN ID Zuordnung']),
        table(['ID', 'Bedeutung', 'Verwendung'], idRows)
      ]),
      el('div', { class: 'hp-card' }, [
        el('h3', {}, ['Command -> CAN Mapping (press.sh)']),
        table(['Kommando', 'Frame', 'Semantik'], cmdRows)
      ]),
      el('div', { class: 'hp-note' }, ['Hinweis: Durable Betriebsarten stammen ausschließlich aus bekannten 0x321-Flags. Transiente Werte (z.B. 321 FFFF) dürfen den Modus-Latch nicht überschreiben.'])
    ]);
  },

  handleSaveApply: null,
  handleSave: null,
  handleReset: null
});
