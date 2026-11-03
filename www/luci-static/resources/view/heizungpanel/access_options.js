'use strict';
'require baseclass';
'require form';
'require fs';
'require ui';

function sequenceValid(value) {
    var parts = String(value || '').split(',');
    return parts.length >= 3 && parts.length <= 15 && parts.every(function(part) {
        return /^[0-9]+$/.test(part) && Number(part) >= 120 && Number(part) <= 10000;
    });
}

function request(action) {
    return fs.exec('/usr/libexec/heizungpanel/access_rpc.sh', [action]).then(function(result) {
        if (result.code !== 0)
            throw new Error(result.stderr || _('Wartungsdienst nicht erreichbar.'));
        return JSON.parse(result.stdout);
    });
}

function learningWidget(sequence, sectionId) {
    var state = 'closed';
    var timer = null;
    var busy = false;
    var disposed = false;
    var status = E('p', { 'role': 'status', 'aria-live': 'polite' }, _('Bereit zum Anlernen.'));
    var messages = {
        closed: _('Geschlossen.'),
        open: _('Ethernet-Wartung geöffnet. Ein kurzer WPS-Druck schließt sofort.'),
        record: _('Muster jetzt am WPS-Knopf eingeben (4 bis 16 kurze Betätigungen).'),
        confirm: _('Dasselbe Muster zur Bestätigung erneut eingeben.'),
        ready: _('Muster bestätigt und ins Formular übernommen. Zum dauerhaften Speichern den normalen LuCI-Footer verwenden.'),
        error: _('Lernversuch ungültig. Bitte neu beginnen.')
    };
    var errors = {
        press_count: _('Vier bis sechzehn Betätigungen erforderlich; beide Durchgänge müssen gleich lang sein.'),
        mismatch: _('Die Abstände unterscheiden sich stärker als die gespeicherte Toleranz erlaubt.'),
        timing: _('Zu viele Betätigungen oder eine Pause über zehn Sekunden.'),
        learning_timeout: _('Das Lernfenster von 60 Sekunden ist abgelaufen.')
    };
    function dispose() {
        disposed = true;
        if (timer !== null) window.clearTimeout(timer);
        window.removeEventListener('pagehide', dispose);
    }
    function show(data) {
        if (disposed) return;
        state = data.mode;
        var text = messages[state] || _('Unbekannter Dienstzustand.');
        if (data.enabled && !data.service_ready)
            text = _('Wartungsdienst nicht bereit. Die konfigurierte Sperre ist nicht als aktiv bestätigt. Systemprotokoll prüfen.');
        button.disabled = busy || state === 'open';
        if (state === 'record' || state === 'confirm')
            text += ' ' + _('Erkannt: %d').format(data.presses);
        if (data.session_hold) text += ' ' + _('Eine gültige LuCI-Sitzung hält den Zugang offen.');
        if (data.error) text += ' ' + (errors[data.error] || data.error);
        status.textContent = text;
        button.textContent = state === 'record' ? _('Erstes Muster fertig') :
            state === 'confirm' ? _('Wiederholung prüfen') : _('Sequenz anlernen');
        if (state === 'ready' && sequenceValid(data.sequence)) {
            var widget = sequence.getUIElement(sectionId);
            if (widget) {
                widget.setValue(data.sequence);
                var input = widget.node ? widget.node.querySelector('input') : null;
                if (input) {
                    input.dispatchEvent(new Event('change', { bubbles: true }));
                    input.dispatchEvent(new Event('blur', { bubbles: true }));
                }
            }
        }
        if (state === 'record' || state === 'confirm' || state === 'open') {
            timer = window.setTimeout(function() {
                request('status').then(show).catch(failed);
            }, 1000);
        }
    }
    function failed(error) {
        if (!disposed) status.textContent = error.message || String(error);
    }
    var button = E('button', {
        'class': 'cbi-button cbi-button-action', 'type': 'button',
        'click': function() {
            if (busy) return;
            busy = true;
            button.disabled = true;
            status.textContent = _('Warte auf Bestätigung des Routers, dann das Muster eingeben.');
            if (timer !== null) window.clearTimeout(timer);
            var action = state === 'record' ? 'learn-next' : state === 'confirm' ? 'learn-finish' : 'learn-start';
            request(action).then(show).catch(failed).finally(function() {
                busy = false;
                button.disabled = state === 'open';
            });
        }
    }, _('Sequenz anlernen'));
    var close = E('button', {
        'class': 'cbi-button cbi-button-reset', 'type': 'button',
        'click': function() {
            if (timer !== null) window.clearTimeout(timer);
            request('close').then(show).catch(failed);
        }
    }, _('Lernen abbrechen / Zugang schließen'));
    window.addEventListener('pagehide', dispose);
    request('status').then(show).catch(failed);
    return { node: E('div', {}, [status, button, ' ', close]), dispose: dispose };
}

return baseclass.extend({
    addOptions: function(section) {
        section.tab('access', _('WPS / Ethernet-Wartung'));
        var option = section.taboption('access', form.Flag, 'access_enabled', _('Ethernet-Sperre aktivieren'),
            _('Nur für ein separates, bereits eingerichtetes Ethernet-Wartungsnetz. Keine Bridge mit Sensor-WLAN auswählen. Die Funktion ändert keine Netzwerktopologie.'));
        option.default = '0';
        option.rmempty = false;
        option.validate = function(sectionId, value) {
            var devices = this.map.lookupOption('access_devices', sectionId);
            return value !== '1' || (devices.length && devices[0].formvalue(sectionId)) ? true :
                _('Vor dem Aktivieren mindestens ein separates Wartungsgerät auswählen.');
        };
        option = section.taboption('access', form.Value, 'access_devices', _('Wartungsgeräte (L3)'),
            _('Bis zu acht Gerätenamen, durch einzelne Leerzeichen getrennt, z. B. br-maint. WLAN-Geräte und Bridge-Mitglieder werden abgelehnt. Das Basis-Firewall-Regelwerk muss die Verwaltungsdienste erlauben; diese Funktion sperrt sie zusätzlich.'));
        option.placeholder = 'br-maint';
        option.validate = function(sectionId, value) {
            var text = String(value || '');
            if (text === '') return true;
            var parts = text.split(' ');
            var seen = Object.create(null);
            return parts.length <= 8 && parts.every(function(part) {
                if (!/^[A-Za-z0-9_][A-Za-z0-9_.:-]{0,14}$/.test(part) || seen[part]) return false;
                seen[part] = true;
                return true;
            }) ? true : _('Eindeutige Gerätenamen mit höchstens 15 Zeichen und einzelnen Leerzeichen erwartet.');
        };
        var sequence = section.taboption('access', form.Value, 'access_sequence', _('Sequenzabstände (ms)'),
            _('Drei bis fünfzehn Abstände für vier bis sechzehn kurze Betätigungen. Anlernen übernimmt das Muster nur ins Formular.'));
        sequence.default = '2000,2000,300,300,300';
        sequence.validate = function(sectionId, value) {
            return sequenceValid(value) ? true : _('Drei bis fünfzehn kommagetrennte Ganzzahlen von 120 bis 10000 erwartet.');
        };
        [['access_window_seconds', _('Freigabe / Nachlauf (Sekunden)'), 'range(30,3600)', '300'],
         ['access_jitter_percent', _('Relative Toleranz (%)'), 'range(5,40)', '25'],
         ['access_jitter_ms', _('Mindesttoleranz (ms)'), 'range(20,250)', '80']].forEach(function(definition) {
            var field = section.taboption('access', form.Value, definition[0], definition[1]);
            field.datatype = definition[2];
            field.default = definition[3];
        });
        option = section.taboption('access', form.Value, 'access_led', _('Status-LED'),
            _('Name unter /sys/class/leds, bevorzugt eine rote LED. Leer = keine Anzeige. Leuchtet bei Freigabe, blinkt beim Lernen; anschließend wird die vorherige LED-Funktion wiederhergestellt.'));
        option.validate = function(sectionId, value) {
            return /^(?:[A-Za-z0-9_:-][A-Za-z0-9_:.-]{0,63})?$/.test(String(value || '')) ? true : _('Ungültiger LED-Name.');
        };
        option.load = function(sectionId) {
            this.value('', _('Keine LED'));
            return request('status').then(L.bind(function(data) {
                (data.leds || []).forEach(L.bind(function(name) { this.value(name, name); }, this));
            }, this)).catch(function(error) {
                ui.addNotification(null, E('p', {}, _('LED-Liste nicht verfügbar: ') + error.message), 'warning');
            }).then(L.bind(function() {
                return form.Value.prototype.load.call(this, sectionId);
            }, this));
        };
        option = section.taboption('access', form.DummyValue, '_access_learning', _('WPS-Muster anlernen'),
            _('Verwendet die gespeicherten Toleranzen. Jede gültige LuCI-Sitzung hält einen bereits geöffneten Zugang offen; es wird kein eigener Sitzungstimeout eingeführt. Die Tastensequenz ersetzt keine Anmeldung.'));
        var dispose = null;
        option.renderWidget = function(sectionId) {
            if (dispose) dispose();
            var widget = learningWidget(sequence, sectionId);
            dispose = widget.dispose;
            return widget.node;
        };
        return function() { if (dispose) dispose(); };
    }
});
