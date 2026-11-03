'use strict';
'require baseclass';

return baseclass.extend({
  render: function(button) {
    var pages = [
      [_('Verbrennung'), _('Abgas-Istwert, Kesselleistung und Förderparameter. Änderungen beeinflussen Brennstoffzufuhr und Verbrennung.'), '23 / 21'],
      [_('Service'), _('Zünd-, Reinigungs- und Pufferparameter sowie Antriebsanzeigen. Änderungen können Startablauf und Anlagenbetrieb beeinflussen.'), '26 / 24'],
      [_('Fühlerabgleich'), _('Nullung und Normierung der Temperaturfühler. Änderungen wirken auf Messwerte und Regelung; Referenzmessung und ursprüngliche Werte berücksichtigen.'), '31 / 29'],
      [_('Hausanlage'), _('Pumpen, Mischer und Rücklaufregelung. Schaltschwellen und Regelparameter beeinflussen Wärmeverteilung und Rücklauftemperatur.'), '34 / 32'],
      [_('Fehlerspeicher'), _('Gespeicherte Störungen mit Datum und Uhrzeit. Nicht jedes Feld ist nur eine Anzeige; das Handbuch beschreibt auch einstellbare Datumsfelder.'), '36 / 34'],
      [_('Prüfparameter'), _('Lüfter-, Förder- und Abgasparameter für die Prüfung. Das Öffnen dieser Seite ist nicht gleichbedeutend mit dem Aktivieren einer Rauchgasmessung.'), '38 / 36']
    ];
    var summary = E('summary', {}, _('Seiten, Bedienung und Auswirkungen'));
    var closeButton = E('button', { 'class': 'hp-key', 'type': 'button', 'aria-label': _('Hilfe schließen') }, _('Schließen'));
    var body = E('div', { 'class': 'hp-help-body', 'tabindex': '0', 'role': 'region', 'aria-label': _('Scrollbarer Hilfetext') }, [
        E('p', {}, _('Ein Klick sendet genau eine konfigurierte V+Z-Betätigung. Sie blättert relativ zur aktuellen Anzeige weiter. Es gibt hier weder eine automatische Mehrfachfolge noch eine angenommene aktuelle Seite.')),
        E('p', {}, _('Aus dem Hauptmenü nennt das Handbuch folgende Anzahl von V+Z-Betätigungen. Den tatsächlich erreichten Bildschirm immer im Live-Display prüfen:')),
        E('ol', {}, pages.map(function(page, index) {
          return E('li', {}, [
            E('strong', {}, page[0] + ' (' + (index + 1) + '× V+Z)'),
            E('p', {}, page[1]),
            E('small', {}, _('Handbuch: PDF-Seite / gedruckte Seite: ') + page[2])
          ]);
        })),
        E('p', {}, _('V und Z dienen der Navigation; Plus/Minus können Parameter unmittelbar verändern. Laut Handbuch verlassen Betriebsarttasten die Zusatzmenüs, wobei die gewählte Betriebsart zu beachten ist.')),
        E('p', {}, _('Nicht enthalten sind unbestätigte Tastenkombinationen für Rauchgasmessung oder automatische Reinigung. Beim Laden dieser Hilfe wird kein Befehl gesendet.'))
    ]);
    var pane = E('aside', { 'class': 'hp-help-window', 'aria-label': _('Zusatzseiten-Hilfe') }, [
      E('div', { 'class': 'hp-help-header' }, [E('strong', {}, _('Zusatzseiten-Hilfe')), closeButton]),
      body
    ]);
    var details = E('details', {}, [summary, pane]);
    var observer = null;
    var section = E('section', { 'class': 'hp-special', 'aria-label': _('Zusatzparameter') }, [
      E('style', {}, [
        '.hp-help-window{position:fixed;z-index:20;box-sizing:border-box;display:flex;flex-direction:column;gap:10px;padding:12px;border:1px solid #999;border-radius:8px;background:#3b3b3b;color:#eee;color-scheme:dark;visibility:hidden}' +
        '.hp-help-window.hp-help-positioned{visibility:visible}' +
        '.hp-help-header{display:flex;align-items:center;justify-content:space-between;gap:12px;flex:0 0 auto}' +
        '.hp-help-header .hp-key{min-height:44px;padding:8px 12px}' +
        '.hp-help-body{min-height:0;flex:1 1 auto;overflow:auto;overscroll-behavior:contain;overflow-wrap:anywhere}' +
        '.hp-help-body:focus-visible{outline:2px solid #74d3ff;outline-offset:-2px}'
      ]),
      E('strong', {}, _('Zusatzparameter / Sonderseiten')),
      E('p', {}, [button]),
      details
    ]);

    function topInset() {
      var inset = 16;
      var header = document.querySelector('header');
      if (header && /^(fixed|sticky)$/.test(window.getComputedStyle(header).position))
        inset = Math.max(inset, header.getBoundingClientRect().bottom + 12);
      return inset;
    }

    function positionHelp() {
      if (!details.open) return;
      var root = section.closest('.hp-wrap');
      if (!root) return;
      var rect = root.getBoundingClientRect();
      var display = root.querySelector('.hp-display');
      var room = window.innerWidth - rect.right - 28;
      var width;
      var left;
      var top;
      if (room >= 260) {
        width = Math.min(360, room);
        left = rect.right + 12;
        top = Math.max(topInset(), rect.top);
      } else {
        width = Math.min(360, window.innerWidth - 32);
        left = window.innerWidth - width - 16;
        top = Math.max(topInset(), display.getBoundingClientRect().bottom + 12);
      }
      pane.style.left = left + 'px';
      pane.style.top = top + 'px';
      pane.style.width = width + 'px';
      pane.style.height = Math.max(60, window.innerHeight - top - 16) + 'px';
      pane.classList.add('hp-help-positioned');
    }

    function stopTracking() {
      window.removeEventListener('resize', positionHelp);
      window.removeEventListener('scroll', positionHelp);
      if (observer) { observer.disconnect(); observer = null; }
      pane.classList.remove('hp-help-positioned');
    }

    function closeHelp(restoreFocus) {
      details.open = false;
      stopTracking();
      if (restoreFocus) {
        var rect = summary.getBoundingClientRect();
        if (rect.top >= topInset() && rect.bottom <= window.innerHeight)
          summary.focus({ preventScroll: true });
        else {
          var display = section.closest('.hp-wrap').querySelector('.hp-display');
          display.setAttribute('tabindex', '-1');
          display.focus({ preventScroll: true });
        }
      }
    }

    function onToggle() {
      if (!details.open) { stopTracking(); return; }
      var display = section.closest('.hp-wrap').querySelector('.hp-display');
      var rect = display.getBoundingClientRect();
      if (rect.top < topInset() || rect.bottom > window.innerHeight - 16) {
        display.scrollIntoView({ block: 'start', behavior: 'auto' });
        window.scrollBy(0, -topInset());
      }
      positionHelp();
      window.addEventListener('resize', positionHelp);
      window.addEventListener('scroll', positionHelp, { passive: true });
      if (typeof ResizeObserver !== 'undefined') {
        observer = new ResizeObserver(positionHelp);
        observer.observe(section.closest('.hp-wrap'));
        observer.observe(display);
      }
    }

    function onClose() { closeHelp(true); }
    function onPageHide() { closeHelp(false); }
    function onKeyDown(event) {
      if (event.key === 'Escape') { event.preventDefault(); closeHelp(true); }
    }
    details.addEventListener('toggle', onToggle);
    closeButton.addEventListener('click', onClose);
    pane.addEventListener('keydown', onKeyDown);
    window.addEventListener('pagehide', onPageHide);
    section._heizungHelpDispose = function() {
      closeHelp(false);
      details.removeEventListener('toggle', onToggle);
      closeButton.removeEventListener('click', onClose);
      pane.removeEventListener('keydown', onKeyDown);
      window.removeEventListener('pagehide', onPageHide);
    };
    return section;
  }
});
