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

return view.extend({
  render: function() {
    var style = el('style', { html: [
      '.hp-upd { max-width: 900px; }',
      '.hp-card { background:#fff; border:1px solid #ddd; border-radius:8px; padding:14px; margin-bottom:12px; }',
      '.hp-row { display:grid; grid-template-columns: 220px 1fr; gap:8px; align-items:center; margin-bottom:8px; }',
      '.hp-row input { width:100%; max-width:520px; }',
      '.hp-note { font-size:12px; color:#555; margin-bottom:8px; }',
      '.hp-status { font-size:12px; margin-top:10px; white-space:pre-wrap; }',
      '.hp-ok { color:#2e7d32; }',
      '.hp-err { color:#c62828; }',
      '.hp-warn { color:#ef6c00; }'
    ].join('\n') });

    var repoInput = el('input', { type: 'text', value: 'faktor22/open_slcontrol' }, []);
    var refInput = el('input', { type: 'text', value: 'main' }, []);
    var archiveInput = el('input', { type: 'text', placeholder: 'Optional: https://.../repo.tar.gz' }, []);
    var overwriteInput = el('input', { type: 'checkbox', checked: false }, []);
    var status = el('div', { class: 'hp-status hp-warn' }, ['Status: bereit']);

    var runBtn = el('button', { class: 'btn cbi-button cbi-button-save', type: 'button' }, ['Update herunterladen & installieren']);

    function setStatus(kind, msg) {
      status.className = 'hp-status ' + kind;
      status.textContent = msg;
    }

    runBtn.addEventListener('click', function() {
      var args = [];
      var repo = (repoInput.value || '').trim();
      var ref = (refInput.value || '').trim();
      var archive = (archiveInput.value || '').trim();

      if (archive) {
        args.push('--archive-url');
        args.push(archive);
      } else {
        if (!repo || !ref) {
          setStatus('hp-err', 'Bitte entweder Archive-URL ausfüllen oder Repository + Branch/Commit angeben.');
          return;
        }
        args.push('--repo');
        args.push(repo);
        args.push('--ref');
        args.push(ref);
      }

      if (overwriteInput.checked)
        args.push('--overwrite-config');

      setStatus('hp-warn', 'Update läuft ... Seite währenddessen nicht schließen.');
      runBtn.disabled = true;

      fs.exec('/usr/libexec/heizungpanel/git_update.sh', args).then(function(res) {
        runBtn.disabled = false;

        if (!res || res.code !== 0) {
          setStatus('hp-err', 'Fehler: ' + (res ? (res.stderr || res.stdout || res.code) : 'unbekannt'));
          return;
        }

        var out = (res.stdout || '').trim();
        try {
          var obj = JSON.parse(out || '{}');
          if (obj.ok)
            setStatus('hp-ok', 'Erfolg: ' + (obj.message || 'Update installiert. Bitte Seite neu laden.'));
          else
            setStatus('hp-err', 'Fehler: ' + (obj.error || out || 'unbekannt'));
        } catch (e) {
          setStatus('hp-warn', 'Update abgeschlossen, aber Antwort war kein JSON: ' + out);
        }
      }).catch(function(err) {
        runBtn.disabled = false;
        setStatus('hp-err', 'Fehler: ' + err);
      });
    });

    function row(label, input, note) {
      return el('div', { class: 'hp-row' }, [
        el('label', {}, [label]),
        el('div', {}, [input, note ? el('div', { class: 'hp-note' }, [note]) : null])
      ]);
    }

    return el('div', { class: 'hp-upd' }, [
      style,
      el('h2', {}, ['Heizungpanel – Git Update (tar.gz)']),
      el('div', { class: 'hp-card' }, [
        el('div', { class: 'hp-note' }, ['Lädt einen Branch oder Commit als tar.gz herunter und installiert die App-Dateien direkt auf dem Router.']),
        row('Repository (owner/name)', repoInput, 'Beispiel: faktor22/open_slcontrol'),
        row('Branch oder Commit', refInput, 'Beispiel: main oder SHA (nur wenn keine Archive-URL gesetzt ist)'),
        row('Direkte Archive-URL (optional)', archiveInput, 'Wenn gesetzt, werden Repository/Ref ignoriert.'),
        row('Config überschreiben', overwriteInput, '/etc/config/heizungpanel mitinstallieren'),
        runBtn,
        status
      ])
    ]);
  }
});
