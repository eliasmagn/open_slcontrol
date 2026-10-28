'use strict';
'require view';
'require form';
'require fs';

var HEX4_RE = /^[0-9A-Fa-f]{4}$/;
var HEX_TOKEN_RE = /^[0-9A-Fa-f]+$/;
var LED_MAP_CHARS_RE = /^[0-9A-Fa-f:,\s]+$/;
var HOST_RE = /^[A-Za-z0-9._:-]+$/;
var CAN_IF_RE = /^(?:can|vcan|slcan)[A-Za-z0-9._-]*$/;
var LEARNING_BASELINE_MS = 3000;
var LEARNING_WINDOW_MS = 2500;
var LEARNING_MAX_DISTINCT = 32;
var LEARNING_MAX_SEQUENCE = 16;

function mappingDefinitions() {
  return [
    { key: 'mapping_z', command: 'z', tab: 'btn', label: _('Taste Z'), placeholder: 'FF7F' },
    { key: 'mapping_minus', command: 'minus', tab: 'btn', label: _('Taste Minus'), placeholder: '' },
    { key: 'mapping_quit', command: 'quit', tab: 'btn', label: _('Taste Quit'), placeholder: 'FFBF' },
    { key: 'mapping_plus', command: 'plus', tab: 'btn', label: _('Taste Plus'), placeholder: 'FFDF' },
    { key: 'mapping_v', command: 'v', tab: 'btn', label: _('Taste V'), placeholder: 'FFFB' },
    { key: 'mapping_vz', command: 'vz', tab: 'btn', label: _('Taste V+Z'), placeholder: 'FF7B' },
    { key: 'mapping_ein', command: 'ein', tab: 'btn', label: _('Taste Ein'), placeholder: '' },
    { key: 'mapping_aus', command: 'aus', tab: 'btn', label: _('Taste Aus'), placeholder: '' },
    { key: 'mapping_dauer', command: 'dauer', tab: 'mode', label: _('Mode Dauer'), placeholder: '7FFF' },
    { key: 'mapping_uhr', command: 'uhr', tab: 'mode', label: _('Mode Uhr'), placeholder: 'BFFF' },
    { key: 'mapping_boiler', command: 'boiler', tab: 'mode', label: _('Mode Boiler'), placeholder: 'DFFF' },
    { key: 'mapping_uhr_boiler', command: 'uhr_boiler', tab: 'mode', label: _('Mode Uhr+Boiler'), placeholder: 'EFFF' },
    { key: 'mapping_aussen_reg', command: 'aussen_reg', tab: 'mode', label: _('Mode Außentemp'), placeholder: 'F7FF' },
    { key: 'mapping_pruef', command: 'pruef', tab: 'mode', label: _('Mode Prüf'), placeholder: 'FBFF' },
    { key: 'mapping_hand', command: 'hand', tab: 'mode', label: _('Mode Hand'), placeholder: 'FDFF' }
  ];
}

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
  o.validate = function(section_id, value) {
    return validateHex4OrEmpty(String(value || '').trim());
  };
  return o;
}

function makeNode(tag, className, text) {
  var node = document.createElement(tag);
  if (className)
    node.className = className;
  if (text != null)
    node.textContent = text;
  return node;
}

function normalizeCanId(id) {
  var normalized = String(id || '').toUpperCase().replace(/^0+/, '');
  return normalized || '0';
}

function parseOperatorPayload(line) {
  var raw = String(line || '');
  var match = raw.match(/(?:^|\s)([0-9A-Fa-f]{1,8})#([0-9A-Fa-f]{4})(?=\s|$)/);
  if (match)
    return normalizeCanId(match[1]) === '321' ? match[2].toUpperCase() : null;

  match = raw.match(/(?:^|[ \t])([0-9A-Fa-f]+)[ \t]+\[[ \t]*(\d+)[ \t]*\][ \t]+(.+)[ \t]*$/);
  if (!match || normalizeCanId(match[1]) !== '321' || parseInt(match[2], 10) !== 2)
    return null;

  var tail = match[3] || '';
  var quote = tail.indexOf("'");
  if (quote >= 0)
    tail = tail.slice(0, quote);
  tail = tail.trim();
  if (!/^[0-9A-Fa-f]{2}\s+[0-9A-Fa-f]{2}$/.test(tail))
    return null;
  return tail.replace(/\s+/g, '').toUpperCase();
}

function createObservation() {
  return { counts: Object.create(null), sequence: [], overflow: false };
}

function recordObservation(observation, payload) {
  if (!HEX4_RE.test(payload))
    return;

  if (!Object.prototype.hasOwnProperty.call(observation.counts, payload)) {
    if (Object.keys(observation.counts).length >= LEARNING_MAX_DISTINCT) {
      observation.overflow = true;
      return;
    }
    observation.counts[payload] = 0;
  }
  observation.counts[payload]++;

  if (observation.sequence[observation.sequence.length - 1] !== payload) {
    if (observation.sequence.length >= LEARNING_MAX_SEQUENCE) {
      observation.overflow = true;
      return;
    }
    observation.sequence.push(payload);
  }
}

function observationTotal(observation) {
  return Object.keys(observation ? observation.counts : {}).reduce(function(total, payload) {
    return total + observation.counts[payload];
  }, 0);
}

function contextualSequence(observation, background) {
  var result = [];
  observation.sequence.forEach(function(payload) {
    if (Object.prototype.hasOwnProperty.call(background.counts, payload))
      return;
    if (result[result.length - 1] !== payload)
      result.push(payload);
  });
  return result;
}

function distinctPayloads(sequence) {
  var seen = Object.create(null);
  var out = [];
  sequence.forEach(function(payload) {
    if (!Object.prototype.hasOwnProperty.call(seen, payload)) {
      seen[payload] = true;
      out.push(payload);
    }
  });
  return out;
}

function analyzeLearning(baseline, first, second) {
  if (baseline.overflow || first.overflow || second.overflow)
    return { ok: false, reason: _('Zu viele verschiedene 0x321-Werte; andere Sender stoppen und neu beginnen.') };

  var firstCandidates = distinctPayloads(contextualSequence(first, baseline));
  var secondCandidates = distinctPayloads(contextualSequence(second, baseline));
  if (!firstCandidates.length || !secondCandidates.length)
    return { ok: false, reason: _('Kein eindeutiger neuer Wert in beiden Pressfenstern. Ruhephase ohne Tastendruck wiederholen.') };
  if (firstCandidates.length > 1 || secondCandidates.length > 1)
    return { ok: false, reason: _('Mehr als ein neuer 0x321-Wert pro Pressfenster (Fenster 1: %s; Fenster 2: %s). Die Zuordnung ist mehrdeutig — auch bei Wiederholung wird nichts übernommen.')
      .format(firstCandidates.join(', '), secondCandidates.join(', ')) };
  if (firstCandidates[0] !== secondCandidates[0])
    return { ok: false, reason: _('Die neuen Werte der beiden Pressfenster stimmen nicht überein.') };

  return {
    ok: true,
    payload: firstCandidates[0],
    observations: [first.counts[firstCandidates[0]] || 0, second.counts[secondCandidates[0]] || 0],
    baselineDistinct: Object.keys(baseline.counts).length
  };
}

function createGuidedLearning(mappingDefs, mappingOptions, streamTokenOption) {
  var sessionEvidence = Object.create(null);
  var baseline = null;
  var windows = [null, null];
  var proposal = null;
  var eventSource = null;
  var captureTimer = null;
  var activeObservation = null;
  var activeStage = null;
  var disposed = false;

  var root = makeNode('div', 'cbi-section');
  root.setAttribute('data-guided-learning-root', '');
  root.appendChild(makeNode('h3', null, _('Passiv geführtes CAN-Tastenlernen')));
  root.appendChild(makeNode('div', 'alert-message warning',
    _('Die App sendet dabei nichts. Sie drücken am echten Bedienfeld; jeder Druck kann den Heizbetrieb sofort verändern. Wählen Sie vorher einen geeigneten Displayzustand, überspringen Sie unsichere Befehle und stoppen Sie andere Bediener, LuCI-Aktionen und Automationen während der Aufnahme.')));
  root.appendChild(makeNode('p', null,
    _('Gelernt werden ausschließlich exakte 4-Hex-Payloads aus 0x321-Bedienereignissen. Eine Kombination wie V+Z muss zweimal physisch ausgeführt werden; sie wird nie aus Einzelwerten berechnet.')));

  var targetRow = makeNode('div', 'cbi-value');
  var targetLabel = makeNode('label', 'cbi-value-title', _('Zu lernendes Mapping'));
  targetLabel.setAttribute('for', 'hp-learning-target');
  var targetField = makeNode('div', 'cbi-value-field');
  var targetSelect = makeNode('select', 'cbi-input-select');
  targetSelect.id = 'hp-learning-target';
  targetSelect.setAttribute('data-learning-target', '');
  mappingDefs.forEach(function(definition) {
    var option = makeNode('option', null, definition.label);
    option.value = definition.key;
    targetSelect.appendChild(option);
  });
  targetField.appendChild(targetSelect);
  targetRow.appendChild(targetLabel);
  targetRow.appendChild(targetField);
  root.appendChild(targetRow);

  var instruction = makeNode('p', null,
    _('Ablauf: Ruhephase aufnehmen, das gewählte Bedienelement im ersten Fenster genau einmal drücken und loslassen, danach denselben physischen Druck im zweiten Fenster wiederholen.'));
  root.appendChild(instruction);

  function createButton(text, style, attribute, value) {
    var button = makeNode('button', 'cbi-button cbi-button-' + style, text);
    button.type = 'button';
    button.setAttribute(attribute, value == null ? '' : value);
    return button;
  }

  var controls = makeNode('div', 'cbi-section-actions');
  var baselineButton = createButton(_('1. Ruhephase aufnehmen'), 'action', 'data-learning-baseline');
  var firstButton = createButton(_('2. Erstes Pressfenster starten'), 'action', 'data-learning-window', '1');
  var secondButton = createButton(_('3. Zweites Pressfenster starten'), 'action', 'data-learning-window', '2');
  var acceptButton = createButton(_('Vorschlag ins Formular übernehmen'), 'positive', 'data-learning-accept');
  var skipButton = createButton(_('Befehl überspringen'), 'neutral', 'data-learning-skip');
  var resetButton = createButton(_('Versuch neu starten'), 'reset', 'data-learning-reset');
  [baselineButton, firstButton, secondButton, acceptButton, skipButton, resetButton].forEach(function(button) {
    controls.appendChild(button);
  });
  root.appendChild(controls);

  var replaceRow = makeNode('div', 'cbi-value');
  replaceRow.hidden = true;
  var replaceLabel = makeNode('label', 'cbi-value-title', _('Vorhandenen Wert ersetzen'));
  replaceLabel.setAttribute('for', 'hp-learning-replace');
  var replaceField = makeNode('div', 'cbi-value-field');
  var replaceCheckbox = makeNode('input');
  replaceCheckbox.type = 'checkbox';
  replaceCheckbox.id = 'hp-learning-replace';
  replaceCheckbox.setAttribute('data-learning-replace', '');
  var replaceText = makeNode('span');
  replaceField.appendChild(replaceCheckbox);
  replaceField.appendChild(document.createTextNode(' '));
  replaceField.appendChild(replaceText);
  replaceRow.appendChild(replaceLabel);
  replaceRow.appendChild(replaceField);
  root.appendChild(replaceRow);

  var proposalText = makeNode('p');
  proposalText.setAttribute('data-learning-proposal', '');
  root.appendChild(proposalText);
  var evidenceSummary = makeNode('p');
  evidenceSummary.setAttribute('data-learning-evidence-summary', '');
  root.appendChild(evidenceSummary);
  var learningStatus = makeNode('div', 'alert-message');
  learningStatus.setAttribute('role', 'status');
  learningStatus.setAttribute('aria-live', 'polite');
  learningStatus.setAttribute('data-learning-status', '');
  root.appendChild(learningStatus);

  function setStatus(level, text) {
    learningStatus.className = 'alert-message' + (level ? ' ' + level : '');
    learningStatus.textContent = text;
  }

  function readMappingValue(key) {
    var option = mappingOptions[key];
    var value = option ? option.formvalue('main') : null;
    if (value == null && option)
      value = option.cfgvalue('main');
    value = String(value || '').toUpperCase();
    return HEX4_RE.test(value) ? value : '';
  }

  function writeMappingValue(key, payload) {
    var option = mappingOptions[key];
    var widget = option ? option.getUIElement('main') : null;
    var input = widget && widget.node ? widget.node.querySelector('input') : null;
    if (!widget || !input)
      return false;
    widget.setValue(payload);
    input.dispatchEvent(new Event('change', { bubbles: true }));
    input.dispatchEvent(new Event('blur', { bubbles: true }));
    return true;
  }

  function selectedDefinition() {
    for (var i = 0; i < mappingDefs.length; i++) {
      if (mappingDefs[i].key === targetSelect.value)
        return mappingDefs[i];
    }
    return null;
  }

  function findCollisions(targetKey, payload) {
    return mappingDefs.filter(function(definition) {
      return definition.key !== targetKey && readMappingValue(definition.key) === payload;
    });
  }

  function streamToken() {
    var value = streamTokenOption.formvalue('main');
    if (value == null)
      value = streamTokenOption.cfgvalue('main');
    return String(value || '');
  }

  function closeCapture() {
    if (captureTimer != null) {
      window.clearTimeout(captureTimer);
      captureTimer = null;
    }
    if (eventSource) {
      eventSource.onopen = null;
      eventSource.onmessage = null;
      eventSource.onerror = null;
      eventSource.close();
      eventSource = null;
    }
    activeObservation = null;
    activeStage = null;
  }

  function enableStep(step) {
    baselineButton.disabled = step !== 'baseline';
    firstButton.disabled = step !== 'first';
    secondButton.disabled = step !== 'second';
    acceptButton.disabled = step !== 'accept';
  }

  function updateEvidenceSummary() {
    var parts = [];
    if (baseline)
      parts.push(_('Ruhephase: %d gültige 0x321-Beobachtungen, %d temporäre Hintergrundkandidaten.').format(observationTotal(baseline), Object.keys(baseline.counts).length));
    if (windows[0])
      parts.push(_('Fenster 1: %d gültige Beobachtungen.').format(observationTotal(windows[0])));
    if (windows[1])
      parts.push(_('Fenster 2: %d gültige Beobachtungen.').format(observationTotal(windows[1])));
    evidenceSummary.textContent = parts.join(' ');
  }

  function restoreAfterCaptureError(stage) {
    if (stage === 'baseline') {
      targetSelect.disabled = false;
      enableStep('baseline');
    } else if (stage === 'first') {
      enableStep('first');
    } else {
      enableStep('second');
    }
  }

  function capture(stage, observation, duration, onComplete) {
    closeCapture();
    activeObservation = observation;
    activeStage = stage;
    enableStep('none');
    setStatus('', _('Verbinde passiv mit dem vorhandenen Raw-Stream …'));

    if (typeof EventSource === 'undefined') {
      closeCapture();
      restoreAfterCaptureError(stage);
      setStatus('warning', _('EventSource ist in diesem Browser nicht verfügbar; Lernen wurde nicht gestartet.'));
      return;
    }

    var opened = false;
    try {
      eventSource = new EventSource('/cgi-bin/heizungpanel_stream?token=' + encodeURIComponent(streamToken()));
    } catch (error) {
      closeCapture();
      restoreAfterCaptureError(stage);
      setStatus('warning', _('Raw-Stream konnte nicht geöffnet werden; Lernen wurde nicht gestartet.'));
      return;
    }

    eventSource.onmessage = function(event) {
      var payload = parseOperatorPayload(event.data);
      if (activeObservation && payload)
        recordObservation(activeObservation, payload);
    };
    eventSource.onerror = function() {
      if (!activeStage)
        return;
      var failedStage = activeStage;
      closeCapture();
      restoreAfterCaptureError(failedStage);
      setStatus('warning', _('Raw-Stream unterbrochen; dieses Aufnahmefenster wurde verworfen und muss wiederholt werden.'));
    };
    eventSource.onopen = function() {
      if (opened || !activeStage)
        return;
      opened = true;
      setStatus('', stage === 'baseline'
        ? _('Ruhephase läuft %d Sekunden: nichts drücken und andere Sender ruhig halten.').format(duration / 1000)
        : _('Pressfenster läuft %.1f Sekunden: jetzt genau einmal drücken und loslassen.').format(duration / 1000));
      captureTimer = window.setTimeout(function() {
        closeCapture();
        updateEvidenceSummary();
        onComplete();
      }, duration);
    };
  }

  function resetAttempt(message) {
    closeCapture();
    baseline = null;
    windows = [null, null];
    proposal = null;
    targetSelect.disabled = false;
    replaceRow.hidden = true;
    replaceCheckbox.checked = false;
    proposalText.textContent = '';
    evidenceSummary.textContent = '';
    enableStep('baseline');
    setStatus('', message || _('Bereit. Die Ruhephase gilt nur für den nächsten Lernversuch.'));
  }

  function showProposal() {
    var analysis = analyzeLearning(baseline, windows[0], windows[1]);
    if (!analysis.ok) {
      proposal = null;
      proposalText.textContent = '';
      enableStep('none');
      setStatus('warning', _('Keine Übernahme: ') + analysis.reason + ' ' + _('Versuch vollständig neu starten.'));
      return;
    }

    var definition = selectedDefinition();
    var existing = readMappingValue(definition.key);
    var collisions = findCollisions(definition.key, analysis.payload);
    proposal = {
      definition: definition,
      payload: analysis.payload,
      existing: existing,
      collisions: collisions,
      analysis: analysis
    };

    proposalText.textContent = _('Vorschlag für %s: %s. Beide Pressfenster zeigen ausschließlich diesen einen neuen Wert.')
      .format(definition.label, analysis.payload);

    replaceRow.hidden = !(existing && existing !== analysis.payload);
    replaceCheckbox.checked = false;
    replaceText.textContent = replaceRow.hidden
      ? ''
      : _('Den vorhandenen Wert %s ausdrücklich durch %s ersetzen.').format(existing, analysis.payload);

    if (collisions.length) {
      enableStep('none');
      setStatus('warning', _('Kollision: %s ist bereits %s zugeordnet. Der Vorschlag wird nicht übernommen; bestehende Zuordnung zuerst manuell klären.').format(
        analysis.payload,
        collisions.map(function(item) { return item.label; }).join(', ')));
      return;
    }

    enableStep(replaceRow.hidden ? 'accept' : 'none');
    setStatus('', replaceRow.hidden
      ? _('Beide Pressfenster stimmen überein. Erst „ins Formular übernehmen“ markiert diesen Wert als bestätigt.')
      : _('Beide Pressfenster stimmen überein. Vor der Übernahme muss das Ersetzen des vorhandenen Werts bestätigt werden.'));
  }

  baselineButton.addEventListener('click', function() {
    baseline = createObservation();
    windows = [null, null];
    proposal = null;
    targetSelect.disabled = true;
    replaceRow.hidden = true;
    proposalText.textContent = '';
    evidenceSummary.textContent = '';
    capture('baseline', baseline, LEARNING_BASELINE_MS, function() {
      if (baseline.overflow) {
        enableStep('none');
        setStatus('warning', _('Ruhephase war zu unruhig. Andere Sender stoppen und den Versuch neu starten.'));
        return;
      }
      enableStep('first');
      setStatus('', _('Ruhephase beendet. Die erkannten Werte sind nur für diesen Versuch temporäre Hintergrundkandidaten, keine dauerhafte Nicht-Tasten-Liste. Erstes Pressfenster starten, dann einmal physisch drücken.'));
    });
  });

  firstButton.addEventListener('click', function() {
    windows[0] = createObservation();
    capture('first', windows[0], LEARNING_WINDOW_MS, function() {
      enableStep('second');
      setStatus('', _('Erstes Fenster beendet. Zweites Fenster starten und denselben physischen Druck genau einmal wiederholen.'));
    });
  });

  secondButton.addEventListener('click', function() {
    windows[1] = createObservation();
    capture('second', windows[1], LEARNING_WINDOW_MS, showProposal);
  });

  replaceCheckbox.addEventListener('change', function() {
    if (proposal && !proposal.collisions.length)
      enableStep(replaceCheckbox.checked ? 'accept' : 'none');
  });

  skipButton.addEventListener('click', function() {
    resetAttempt(_('Befehl übersprungen. Es wurde kein Mapping verändert.'));
  });
  resetButton.addEventListener('click', function() {
    resetAttempt(_('Versuch verworfen. Temporäre Hintergrundkandidaten und Pressfenster wurden gelöscht.'));
  });

  root.appendChild(makeNode('hr'));
  root.appendChild(makeNode('h3', null, _('Freiwilliger Modell-Konfigurationsbeitrag')));
  root.appendChild(makeNode('p', null,
    _('Die JSON-Datei wird nur lokal im Browser erzeugt und heruntergeladen; es gibt keinen Upload. Alle Metadaten sind optional. Keine Seriennummern, Namen, Adressen, IP-/Hostnamen, Tokens, MQTT-/SSH-Zugangsdaten oder Raw-Dumps eintragen.')));
  root.appendChild(makeNode('p', null,
    _('Ein Export beschreibt nur diese beobachtete Gerätevariante, nie ein universelles Profil. Vorhandene Werte bleiben „existing_unverified“, bis sie in dieser Sitzung ausdrücklich aus zwei Pressfenstern übernommen wurden.')));

  var metadataInputs = Object.create(null);
  function appendMetadata(name, label, help) {
    var row = makeNode('div', 'cbi-value');
    var labelNode = makeNode('label', 'cbi-value-title', label);
    var inputId = 'hp-contribution-' + name;
    labelNode.setAttribute('for', inputId);
    var field = makeNode('div', 'cbi-value-field');
    var input = makeNode('input', 'cbi-input-text');
    input.type = 'text';
    input.id = inputId;
    input.maxLength = 80;
    input.autocomplete = 'off';
    input.placeholder = _('unbekannt (leer lassen)');
    input.setAttribute('data-export-meta', name);
    field.appendChild(input);
    field.appendChild(makeNode('div', 'cbi-value-description', help));
    row.appendChild(labelNode);
    row.appendChild(field);
    root.appendChild(row);
    metadataInputs[name] = input;
  }

  appendMetadata('model', _('Modell'), _('Freie Modellbezeichnung, ohne Seriennummer.'));
  appendMetadata('approx_year', _('Ungefähres Baujahr'), _('Jahr oder Zeitraum; unbekannt darf leer bleiben.'));
  appendMetadata('controller', _('Steuerung/Regler'), _('Optionale Reglerbezeichnung, ohne Gerätekennung.'));
  appendMetadata('firmware', _('Firmware'), _('Optionale Firmware-/Versionsbezeichnung.'));

  root.appendChild(makeNode('h4', null, _('Für den Export ausgewählte Mappings')));
  var exportRows = Object.create(null);
  var exportList = makeNode('div');
  mappingDefs.forEach(function(definition, index) {
    var row = makeNode('div', 'cbi-value');
    var label = makeNode('label', 'cbi-value-title', definition.label);
    var id = 'hp-export-' + index;
    label.setAttribute('for', id);
    var field = makeNode('div', 'cbi-value-field');
    var checkbox = makeNode('input');
    checkbox.type = 'checkbox';
    checkbox.id = id;
    checkbox.setAttribute('data-export-mapping', definition.key);
    var value = makeNode('code');
    var evidence = makeNode('span');
    field.appendChild(checkbox);
    field.appendChild(document.createTextNode(' '));
    field.appendChild(value);
    field.appendChild(document.createTextNode(' — '));
    field.appendChild(evidence);
    row.appendChild(label);
    row.appendChild(field);
    exportList.appendChild(row);
    exportRows[definition.key] = { checkbox: checkbox, value: value, evidence: evidence };
  });
  root.appendChild(exportList);

  function refreshExportRows(autoSelectKey) {
    mappingDefs.forEach(function(definition) {
      var row = exportRows[definition.key];
      var payload = readMappingValue(definition.key);
      var evidence = sessionEvidence[definition.key];
      row.value.textContent = payload || _('leer');
      row.checkbox.disabled = !payload;
      if (!payload)
        row.checkbox.checked = false;
      if (autoSelectKey === definition.key && payload)
        row.checkbox.checked = true;
      row.evidence.textContent = evidence && evidence.payload === payload
        ? _('contributor_confirmed; independently_confirmed: false')
        : _('existing_unverified; independently_confirmed: false');
    });
  }

  function sanitizedMetadata(input) {
    return String(input.value || '').replace(/[\u0000-\u001F\u007F]/g, ' ').trim().slice(0, 80) || null;
  }

  function buildContribution() {
    refreshExportRows();
    var mappings = [];
    mappingDefs.forEach(function(definition) {
      var row = exportRows[definition.key];
      var payload = readMappingValue(definition.key);
      if (!row.checkbox.checked || !payload)
        return;
      var evidence = sessionEvidence[definition.key];
      var confirmed = !!(evidence && evidence.payload === payload);
      var item = {
        mapping_key: definition.key,
        command: definition.command,
        can_id: '0x321',
        payload: payload,
        evidence_status: confirmed ? 'contributor_confirmed' : 'existing_unverified',
        contributor_confirmed: confirmed,
        independently_confirmed: false
      };
      if (confirmed) {
        item.session_evidence = {
          distinct_press_windows: 2,
          matching_payload_observations: evidence.observations.slice(),
          baseline_distinct_payload_count: evidence.baselineDistinct
        };
      }
      mappings.push(item);
    });

    if (!mappings.length)
      return null;

    return {
      schema: 'open_slcontrol.model_configuration_contribution',
      schema_version: 1,
      generated_at: new Date().toISOString(),
      metadata: {
        model: sanitizedMetadata(metadataInputs.model),
        approx_year: sanitizedMetadata(metadataInputs.approx_year),
        controller: sanitizedMetadata(metadataInputs.controller),
        firmware: sanitizedMetadata(metadataInputs.firmware)
      },
      scope: {
        variant_specific: true,
        model_may_have_multiple_variants: true,
        universal_profile_claimed: false
      },
      protocol: {
        mapping_can_id: '0x321',
        payload_format: 'HEX4',
        capture_method: 'passive_live_stream'
      },
      mappings: mappings,
      privacy: {
        raw_frames_included: false,
        stream_token_included: false,
        mqtt_or_ssh_credentials_included: false,
        network_addresses_included: false,
        serial_or_personal_identifiers_requested: false
      }
    };
  }

  var exportControls = makeNode('div', 'cbi-section-actions');
  var previewButton = createButton(_('JSON-Vorschau erzeugen'), 'action', 'data-export-preview');
  var downloadButton = createButton(_('JSON lokal herunterladen'), 'positive', 'data-export-download');
  exportControls.appendChild(previewButton);
  exportControls.appendChild(downloadButton);
  root.appendChild(exportControls);
  var exportStatus = makeNode('div', 'alert-message');
  exportStatus.setAttribute('role', 'status');
  exportStatus.setAttribute('aria-live', 'polite');
  exportStatus.setAttribute('data-export-status', '');
  root.appendChild(exportStatus);
  var preview = makeNode('pre');
  preview.hidden = true;
  preview.tabIndex = 0;
  preview.setAttribute('aria-label', _('Sanitisierte JSON-Vorschau'));
  preview.setAttribute('data-export-preview-content', '');
  root.appendChild(preview);

  function renderPreview() {
    var contribution = buildContribution();
    if (!contribution) {
      preview.hidden = true;
      preview.textContent = '';
      exportStatus.className = 'alert-message warning';
      exportStatus.textContent = _('Mindestens ein nicht-leeres Mapping ausdrücklich für den Export auswählen.');
      return null;
    }
    preview.textContent = JSON.stringify(contribution, null, 2);
    preview.hidden = false;
    exportStatus.className = 'alert-message';
    exportStatus.textContent = _('Vorschau lokal erzeugt. Bitte Inhalt vor dem freiwilligen Teilen prüfen.');
    return contribution;
  }

  previewButton.addEventListener('click', renderPreview);
  downloadButton.addEventListener('click', function() {
    var contribution = renderPreview();
    if (!contribution)
      return;
    var url = window.URL.createObjectURL(new Blob([JSON.stringify(contribution, null, 2) + '\n'], { type: 'application/json' }));
    var link = makeNode('a');
    link.href = url;
    link.download = 'open-slcontrol-model-contribution.json';
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    window.setTimeout(function() { window.URL.revokeObjectURL(url); }, 0);
    exportStatus.textContent = _('Sanitisierte JSON-Datei lokal heruntergeladen; es wurde nichts hochgeladen.');
  });

  acceptButton.addEventListener('click', function() {
    if (!proposal)
      return;
    var collisions = findCollisions(proposal.definition.key, proposal.payload);
    var existing = readMappingValue(proposal.definition.key);
    if (collisions.length) {
      enableStep('none');
      setStatus('warning', _('Kollision nach erneuter Prüfung; keine Übernahme.'));
      return;
    }
    if (existing && existing !== proposal.payload && !replaceCheckbox.checked) {
      enableStep('none');
      setStatus('warning', _('Vorhandener Wert wurde nicht zum Ersetzen bestätigt; keine Übernahme.'));
      return;
    }
    if (existing !== proposal.payload && !writeMappingValue(proposal.definition.key, proposal.payload)) {
      enableStep('none');
      setStatus('warning', _('LuCI-Formularfeld ist nicht verfügbar; keine Übernahme.'));
      return;
    }

    sessionEvidence[proposal.definition.key] = {
      payload: proposal.payload,
      observations: proposal.analysis.observations.slice(),
      baselineDistinct: proposal.analysis.baselineDistinct
    };
    refreshExportRows(proposal.definition.key);
    targetSelect.disabled = false;
    replaceRow.hidden = true;
    enableStep('baseline');
    setStatus('success', _('Wert nur ins Formular übernommen und für diese Sitzung als contributor_confirmed markiert. Dauerhaft speichern ausschließlich über den normalen LuCI-Footer Save / Save & Apply.'));
  });

  function cancelHiddenCapture() {
    if (!activeStage)
      return;
    var failedStage = activeStage;
    closeCapture();
    restoreAfterCaptureError(failedStage);
    setStatus('warning', _('Aufnahme wegen Seitenwechsel/ausgeblendeter Seite abgebrochen; Fenster wiederholen.'));
  }

  function onVisibilityChange() {
    if (document.visibilityState === 'hidden')
      cancelHiddenCapture();
  }

  function dispose() {
    if (disposed)
      return;
    disposed = true;
    closeCapture();
    document.removeEventListener('visibilitychange', onVisibilityChange);
    window.removeEventListener('pagehide', cancelHiddenCapture);
  }

  document.addEventListener('visibilitychange', onVisibilityChange);
  window.addEventListener('pagehide', cancelHiddenCapture);
  enableStep('baseline');
  refreshExportRows();
  setStatus('', _('Bereit. Die Ruhephase gilt nur für den nächsten Lernversuch.'));

  return { node: root, dispose: dispose };
}


    function validateToken(option) {
      option.validate = function(section_id, value) {
        var v = String(value || '');
        if (v === '')
          return true;
        if (/[^0-9A-Za-z:_-]/.test(v))
          return _('Der Token enthält ungültige oder unsichtbare Zeichen (oft beim Kopieren entstanden). Bitte den Token neu kopieren und vollständig erneut einfügen.');
        if (!/^[0-9]+:[A-Za-z0-9_-]+$/.test(v))
          return _('Erwartet das Format BotID:Hash (z. B. 123456789:AAFxyz…).');
        return true;
      };
      return option;
    }

    function validateChatId(option) {
      option.validate = function(section_id, value) {
        var v = String(value || '');
        if (v === '')
          return true;
        if (/[^0-9-]/.test(v))
          return _('Enthält ungültige Zeichen — erlaubt sind nur Ziffern und optional ein führendes Minus.');
        if (!/^-?[0-9]{1,32}$/.test(v))
          return _('Erwartet eine numerische Chat-ID.');
        return true;
      };
      return option;
    }

    function validateUrl(option) {
      option.validate = function(section_id, value) {
        var list = Array.isArray(value) ? value : [value];
        for (var i = 0; i < list.length; i++) {
          var v = String(list[i] == null ? '' : list[i]);
          if (v === '')
            continue;
          if (!/^https?:\/\/[^\s']{1,480}$/.test(v))
            return _('Erwartet je Zeile eine HTTP(S)-URL ohne Leerzeichen oder Anführungszeichen.');
        }
        return true;
      };
      return option;
    }

return view.extend({
  render: function() {
    var self = this;
    if (typeof self._learningDispose === 'function')
      self._learningDispose();

    var m = new form.Map('heizungpanel', _('Heizungpanel – Konfiguration'),
      _('Diese Seite nutzt den normalen LuCI Save/Save & Apply-Flow und schreibt direkt nach UCI.'));

    var s = m.section(form.NamedSection, 'main', 'heizungpanel');
    s.anonymous = true;

    s.tab('app', _('App'));
    s.tab('mqtt', _('MQTT'));
    s.tab('led', _('LED-Auswertung (0x320 83xx)'));
    s.tab('btn', _('Tasten-Mapping'));
    s.tab('mode', _('Betriebsarten-Mapping'));
    s.tab('learn', _('Lernen & Beitrag'));
    s.tab('alarm', _('Alarm'));

    var o;
    var streamTokenOption;
    var mappingOptions = Object.create(null);
    var mappingDefs = mappingDefinitions();

    o = s.taboption('app', form.Value, 'can_if', _('CAN Interface'), _('Erlaubt: Namen mit Präfix can, vcan oder slcan.'));
    o.placeholder = 'can0';
    o.validate = function(section_id, value) {
      var v = String(value || '');
      if (!v.length)
        return _('Wert darf nicht leer sein.');
      if (!CAN_IF_RE.test(v))
        return _('Erwartet einen Interface-Namen mit Präfix can, vcan oder slcan.');
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
    o.validate = function(section_id, value) {
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
    o.validate = function(section_id, value) {
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

    o = s.taboption('mqtt', form.Value, 'stream_token', _('Stream Token (hex)'), _('Hex, 16-128 Zeichen. Wird beim ersten Start automatisch erzeugt; leer lassen und Dienst neu starten für einen neuen Token.'));
    streamTokenOption = o;
    o.password = true;
    o.validate = function(section_id, value) {
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
    o.validate = function(section_id, value) {
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

    mappingDefs.forEach(function(definition) {
      mappingOptions[definition.key] = setupHexOption(
        s.taboption(definition.tab, form.Value, definition.key, definition.label, _('4-stelliges HEX oder leer.')),
        definition.placeholder);
    });

    o = s.taboption('learn', form.DummyValue, '_guided_learning');
    o.render = function() {
      var learning = createGuidedLearning(mappingDefs, mappingOptions, streamTokenOption);
      self._learningDispose = learning.dispose;
      return learning.node;
    };

    o = s.taboption('alarm', form.ListValue, 'alarm_enabled', _('Alarm aktiv'), _('Läuft als eigener Dienst auf dem Router.'));
    o.value('0', _('0 = Aus'));
    o.value('1', _('1 = An'));
    o.default = '0';

    o = s.taboption('alarm', form.Value, 'alarm_fault_pattern', _('Fehlertext-Muster (Regex)'), _('Regex gegen die dekodierten Displayzeilen. Treffer muss länger als die Bestätigungszeit sichtbar sein.'));
    o.placeholder = 'keine autom|Störung';
    o.validate = function(section_id, value) {
      var v = String(value || '').trim();
      if (v.length < 3 || v.length > 200)
        return _('3 bis 200 Zeichen erwartet.');
      if (/[']/.test(v))
        return _('Einfache Anführungszeichen sind in UCI-Werten nicht erlaubt.');
      return true;
    };

    o = s.taboption('alarm', form.Value, 'alarm_fault_confirm_minutes', _('Bestätigungszeit Fehlertext (Minuten)'), _('1..120 — verhindert Fehlalarme beim kurzen Durchblättern von Menüs.'));
    o.datatype = 'range(1,120)';
    o.placeholder = '3';

    o = s.taboption('alarm', form.Value, 'alarm_frozen_minutes', _('Keine Panel-Antwort (Minuten)'), _('10..1440 — CAN-Daten kommen an, aber keine frischen 0x320-Frames. Ein unveränderter Text bei frischen Statusframes ist kein Alarm.'));
    o.datatype = 'range(10,1440)';
    o.placeholder = '60';

    o = s.taboption('alarm', form.Value, 'alarm_stale_minutes', _('Keine CAN-Daten (Minuten)'), _('1..60 — totale Funkstille auf dem Bus (Steuerung tot oder Bridge defekt).'));
    o.datatype = 'range(1,60)';
    o.placeholder = '5';

    o = s.taboption('alarm', form.Value, 'alarm_repeat_minutes', _('Wiederholung (Minuten)'), _('1..1440 — solange der Alarmzustand besteht, wird erneut gemeldet.'));
    o.datatype = 'range(1,1440)';
    o.placeholder = '10';

    o = validateToken(s.taboption('alarm', form.Value, 'alarm_telegram_token', _('Telegram Bot-Token'), _('Leer lassen für aus. Token beim @BotFather erzeugen.')));
    o.password = true;

    o = validateChatId(s.taboption('alarm', form.Value, 'alarm_telegram_chat', _('Telegram Chat-ID'), _('Eigene Chat-ID (Ziffern, ggf. führendes Minus für Gruppen).')));

    o = validateUrl(s.taboption('alarm', form.DynamicList, 'alarm_url', _('Alarm-URLs'), _('HTTPS-GET je Zeile; %%TEXT%% wird durch die URL-kodierte Meldung ersetzt.')));
    o.placeholder = 'https://example.com/alarm?text=%%TEXT%%';

    /* Vertrag mit alarm_watchdog.sh --test: die LETZTE nicht-leere Ausgabezeile
     * ist maschinenlesbar: "TEST_ALARM_RESULT ok|fail channels=N failed=M
     * [reason=UNCONFIGURED|DELIVERY_FAILED|CONFIG_INVALID]". Erfolg wird nur
     * bei diesem finalen ok-Marker, Exit-Code 0 und mindestens einem
     * bestätigten Kanal behauptet (API-Annahme, keine Aussage zur
     * Handy-Zustellung); Exit-Code 0 ohne finalen Marker bleibt "unklar". */
    function parseAlarmTestResult(code, stdout) {
      var lines = String(stdout || '').split(/\r?\n/);
      var last = '';
      for (var i = lines.length - 1; i >= 0; i--) {
        if (lines[i].trim() !== '') {
          last = lines[i].trim();
          break;
        }
      }
      var match = /^TEST_ALARM_RESULT (ok|fail) channels=([0-9]+) failed=([0-9]+)(?: reason=(UNCONFIGURED|DELIVERY_FAILED|CONFIG_INVALID))?$/.exec(last);
      if (match)
        return { marked: true, status: match[1], channels: Number(match[2]), failed: Number(match[3]), reason: match[4] || '' };
      return { marked: false, status: code === 0 ? 'unmarked' : 'error', channels: -1, failed: -1, reason: '' };
    }

    /* Der Test läuft gegen die auf dem Gerät gespeicherte UCI-Konfiguration,
     * nicht gegen ungespeicherte Formulareingaben: bei abweichender
     * formvalue/cfgvalue irgendeines Alarmfeldes wird der Test verweigert
     * (statischer Hinweis, ohne Werte anzuzeigen). Gespeichert wird
     * ausschließlich über den normalen LuCI-Footer. */
    function alarmOptionValuesEqual(a, b) {
      function norm(v) {
        if (v == null)
          return [];
        if (Array.isArray(v))
          return v.map(function(e) { return String(e == null ? '' : e); });
        var s = String(v);
        return s === '' ? [] : [s];
      }
      var x = norm(a), y = norm(b);
      if (x.length !== y.length)
        return false;
      for (var i = 0; i < x.length; i++)
        if (x[i] !== y[i])
          return false;
      return true;
    }

    function hasUnsavedAlarmChanges(section, section_id) {
      return section.children.some(function(opt) {
        if (typeof opt.formvalue !== 'function' || typeof opt.cfgvalue !== 'function')
          return false;
        if (String(opt.option || '').indexOf('alarm_') !== 0)
          return false;
        var f = opt.formvalue(section_id);
        var c = opt.cfgvalue(section_id);
        if (c == null || (Array.isArray(c) ? !c.length : c === ''))
          c = (opt.default != null) ? opt.default : c;
        return !alarmOptionValuesEqual(f, c);
      });
    }

    var ALARM_TEST_TIMEOUT_MS = 60000;

    o = s.taboption('alarm', form.DummyValue, '_alarm_test', _('Alarm-Test'), _('Sendet eine Testmeldung über alle konfigurierten Kanäle.'));
    o.renderWidget = function(section_id) {
      var alarmSection = this.section;
      var wrapper = makeNode('div', 'cbi-value-field');
      var readonly = !!(this.map && this.map.readonly);
      var btn = makeNode('button', 'cbi-button cbi-button-action', _('Test-Alarm senden'));
      btn.type = 'button';
      btn.setAttribute('data-alarm-test', '');
      btn.disabled = readonly;
      var result = makeNode('span', null, '');
      result.setAttribute('data-alarm-test-result', '');
      result.setAttribute('role', 'status');
      result.setAttribute('aria-live', 'polite');
      if (readonly)
        result.textContent = _('Test-Alarm benötigt Schreibrechte (Read-only).');
      btn.addEventListener('click', function() {
        if (btn.disabled)
          return;
        if (hasUnsavedAlarmChanges(alarmSection, section_id)) {
          result.textContent = _('Erst Save & Apply: In den Alarmfeldern gibt es ungespeicherte Änderungen. Der Test nutzt ausschließlich die bereits gespeicherte Konfiguration.');
          return;
        }
        var settled = false;
        btn.disabled = true;
        result.textContent = _('Sende…');
        var timer = window.setTimeout(function() {
          finish(_('Ausgang unklar — keine rechtzeitige Antwort des Alarmdienstes; kein Erfolg angenommen.'));
        }, ALARM_TEST_TIMEOUT_MS);
        function finish(text) {
          if (settled)
            return;
          settled = true;
          window.clearTimeout(timer);
          result.textContent = text;
          btn.disabled = readonly;
        }
        fs.exec('/usr/libexec/heizungpanel/alarm_watchdog.sh', ['--test']).then(function(res) {
          var code = res ? res.code : -1;
          var parsed = parseAlarmTestResult(code, res ? res.stdout : '');
          if (parsed.marked && parsed.status === 'ok' && code === 0 && parsed.channels >= 1 && parsed.failed === 0)
            finish(_('Gesendet — API-Bestätigung für %d Kanäle.').format(parsed.channels));
          else if (parsed.marked && parsed.status === 'ok')
            finish(_('Ausgang unklar — Antwort des Alarmdienstes passt nicht zum Exit-Code oder meldet keinen Kanal.'));
          else if (parsed.marked && parsed.status === 'fail')
            finish(parsed.reason === 'UNCONFIGURED'
              ? _('Kein Alarmkanal konfiguriert.')
              : _('Zustellung fehlgeschlagen (%d von %d Kanälen) — Konfiguration der Kanäle prüfen.').format(parsed.failed >= 0 ? parsed.failed : 0, parsed.channels >= 0 ? parsed.channels : 0));
          else if (!parsed.marked && code === 0)
            finish(_('Ausgang unklar — kein Maschinenergebnis vom Alarmdienst; kein Erfolg angenommen.'));
          else
            finish(_('Fehlgeschlagen (Code %d)').format(code));
        }).catch(function(err) {
          if (err && (err.name === 'PermissionError' || /permission denied/i.test(String(err.message))))
            finish(_('Keine Berechtigung — Test-Alarm benötigt Schreibrechte.'));
          else
            finish(_('Fehlgeschlagen — Alarmdienst nicht erreichbar.'));
        });
      });
      wrapper.appendChild(btn);
      wrapper.appendChild(result);
      return wrapper;
    };

    this.map = m;
    return m.render();
  },

});
