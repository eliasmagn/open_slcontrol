'use strict';
'require view';
'require form';

var HEX4_RE = /^[0-9A-Fa-f]{4}$/;
var HEX_TOKEN_RE = /^[0-9A-Fa-f]+$/;
var LED_MAP_CHARS_RE = /^[0-9A-Fa-f:,\s]+$/;
var HOST_RE = /^[A-Za-z0-9._:-]+$/;
var CAN_IF_RE = /^[A-Za-z0-9._-]+$/;

function validateHex4OrEmpty(value) {
  var v = String(value || '');
  if (v === '')
    return true;
  if (HEX4_RE.test(v))
    return true;
  return _('Erwartet exakt 4 Hex-Zeichen oder leer.');
}

function setupHexOption(o, placeholder) {
  o.placeholder = placeholder || '';
  o.validate = function(_, value) {
    return validateHex4OrEmpty(value);
  };
}

return view.extend({
  render: function() {
    var m = new form.Map('heizungpanel', _('Heizungpanel – Konfiguration'),
      _('Diese Seite nutzt den normalen LuCI Save/Save & Apply-Flow und schreibt direkt nach UCI.'));

    var s = m.section(form.NamedSection, 'main', 'heizungpanel');
    s.anonymous = true;

    s.tab('app', _('App'));
    s.tab('mqtt', _('MQTT'));
    s.tab('led', _('LED-Auswertung (0x320 83xx)'));
    s.tab('btn', _('Tasten-Mapping'));
    s.tab('mode', _('Betriebsarten-Mapping'));

    var o;

    o = s.taboption('app', form.Value, 'can_if', _('CAN Interface'), _('Erlaubt: A-Z, a-z, 0-9, Punkt, Unterstrich, Bindestrich.'));
    o.placeholder = 'can0';
    o.validate = function(_, value) {
      var v = String(value || '');
      if (!v.length)
        return _('Wert darf nicht leer sein.');
      if (!CAN_IF_RE.test(v))
        return _('Ungültige Zeichen im Interface-Namen.');
      return true;
    };

    o = s.taboption('app', form.Value, 'can_bitrate', _('CAN Bitrate'), _('10000..1000000'));
    o.datatype = 'range(10000,1000000)';
    o.placeholder = '69144';

    o = s.taboption('app', form.Value, 'poll_interval_ms', _('Polling-Intervall (ms)'), _('250..10000'));
    o.datatype = 'range(250,10000)';
    o.placeholder = '500';

    o = s.taboption('app', form.ListValue, 'write_mode', _('Write-Mode'));
    o.value('0', _('0 = Read-only'));
    o.value('1', _('1 = Senden aktivieren'));
    o.default = '0';

    o = s.taboption('mqtt', form.Value, 'mqtt_host', _('MQTT Host'), _('Broker-Adresse (Hostname, IPv4 oder IPv6-Literal).'));
    o.placeholder = '127.0.0.1';
    o.validate = function(_, value) {
      var v = String(value || '');
      if (!v.length)
        return _('Wert darf nicht leer sein.');
      if (!HOST_RE.test(v))
        return _('Ungültige Zeichen im Hostnamen.');
      return true;
    };

    o = s.taboption('mqtt', form.Value, 'mqtt_port', _('MQTT Port'), _('1..65535'));
    o.datatype = 'port';
    o.placeholder = '1883';

    o = s.taboption('mqtt', form.Value, 'mqtt_base', _('MQTT Base Topic'), _('Keine Wildcards (#,+), kein führendes/trailing /.'));
    o.placeholder = 'heizungpanel';
    o.validate = function(_, value) {
      var v = String(value || '');
      if (!v.length)
        return _('Wert darf nicht leer sein.');
      if (v.indexOf('#') >= 0 || v.indexOf('+') >= 0)
        return _('Wildcards (#,+) sind nicht erlaubt.');
      if (v.charAt(0) === '/' || v.charAt(v.length - 1) === '/')
        return _('Kein führendes oder abschließendes /.');
      if (!/^[A-Za-z0-9._/-]+$/.test(v))
        return _('Ungültige Zeichen im Topic-Basisnamen.');
      return true;
    };

    o = s.taboption('mqtt', form.Value, 'stream_token', _('Stream Token (hex)'), _('Hex, 16..128 Zeichen, gerade Länge oder leer'));
    o.validate = function(_, value) {
      var v = String(value || '');
      if (!v.length)
        return true;
      if (!HEX_TOKEN_RE.test(v))
        return _('Nur Hex-Zeichen erlaubt.');
      if (v.length < 16 || v.length > 128)
        return _('Länge muss zwischen 16 und 128 liegen.');
      if ((v.length % 2) !== 0)
        return _('Länge muss gerade sein (vollständige Bytes).');
      return true;
    };

    o = s.taboption('led', form.Value, 'led_map_83', _('83xx -> Modus-Map'), _('Kommagetrennte Paare HEX2:HEX4, z.B. EF:DFFF.'));
    o.placeholder = 'BF:7FFF,3F:7FFF,DF:BFFF,5F:BFFF,EF:DFFF,6F:DFFF,FB:EFFF,7B:EFFF,73:F7FF,7E:FDFF';
    o.validate = function(_, value) {
      var v = String(value || '');
      if (!v.length)
        return _('Wert darf nicht leer sein.');
      if (!LED_MAP_CHARS_RE.test(v))
        return _('Nur HEX, Komma, Doppelpunkt und Leerzeichen erlaubt.');
      var parts = v.split(',');
      for (var i = 0; i < parts.length; i++) {
        var p = parts[i].trim();
        if (!/^[0-9A-Fa-f]{2}:[0-9A-Fa-f]{4}$/.test(p))
          return _('Erwartet Einträge im Format HEX2:HEX4.');
      }
      return true;
    };

    o = s.taboption('led', form.ListValue, 'led_power_ein_when_bit7_clear', _('Ein aktiv bei Bit7=0 (0/1)'), _('1 = Ein wenn Bit7 gelöscht, 0 = invertiert.'));
    o.value('1', _('1'));
    o.value('0', _('0'));
    o.default = '1';

    setupHexOption(s.taboption('btn', form.Value, 'mapping_z', _('Taste Z'), _('4-stelliges HEX oder leer.')), 'FF7F');
    setupHexOption(s.taboption('btn', form.Value, 'mapping_minus', _('Taste Minus'), _('4-stelliges HEX oder leer.')), '');
    setupHexOption(s.taboption('btn', form.Value, 'mapping_quit', _('Taste Quit'), _('4-stelliges HEX oder leer.')), 'FFBF');
    setupHexOption(s.taboption('btn', form.Value, 'mapping_plus', _('Taste Plus'), _('4-stelliges HEX oder leer.')), 'FFDF');
    setupHexOption(s.taboption('btn', form.Value, 'mapping_v', _('Taste V'), _('4-stelliges HEX oder leer.')), 'FFFB');
    setupHexOption(s.taboption('btn', form.Value, 'mapping_ein', _('Taste Ein'), _('4-stelliges HEX oder leer.')), '');
    setupHexOption(s.taboption('btn', form.Value, 'mapping_aus', _('Taste Aus'), _('4-stelliges HEX oder leer.')), '');

    setupHexOption(s.taboption('mode', form.Value, 'mapping_dauer', _('Mode Dauer'), _('4-stelliges HEX oder leer.')), '7FFF');
    setupHexOption(s.taboption('mode', form.Value, 'mapping_uhr', _('Mode Uhr'), _('4-stelliges HEX oder leer.')), 'BFFF');
    setupHexOption(s.taboption('mode', form.Value, 'mapping_boiler', _('Mode Boiler'), _('4-stelliges HEX oder leer.')), 'DFFF');
    setupHexOption(s.taboption('mode', form.Value, 'mapping_uhr_boiler', _('Mode Uhr+Boiler'), _('4-stelliges HEX oder leer.')), 'EFFF');
    setupHexOption(s.taboption('mode', form.Value, 'mapping_aussen_reg', _('Mode Außentemp'), _('4-stelliges HEX oder leer.')), 'F7FF');
    setupHexOption(s.taboption('mode', form.Value, 'mapping_pruef', _('Mode Prüf'), _('4-stelliges HEX oder leer.')), 'FBFF');
    setupHexOption(s.taboption('mode', form.Value, 'mapping_hand', _('Mode Hand'), _('4-stelliges HEX oder leer.')), 'FDFF');

    this.map = m;
    return m.render();
  },

  handleSave: function(ev) {
    return this.map.save(ev);
  },

  handleSaveApply: function(ev) {
    return this.map.save(ev, true);
  },

  handleReset: function(ev) {
    return this.map.reset(ev);
  }
});
