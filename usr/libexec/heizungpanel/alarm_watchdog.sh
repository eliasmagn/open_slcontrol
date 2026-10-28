#!/bin/sh
# Passiver Heizungs-Alarm-Watcher auf dem Router.
#
# Abonniert den vorhandenen Raw-MQTT-Stream, dekodiert Displaytexte und
# Statusbytes aus 0x320 (Decoder entspricht panel.js: beide candump-Formate,
# strictDLC, 0x81-Clear, Zeilengrenzen) und alarmiert bei:
#   fault   – Display zeigt andauernd einen Fehlertext (Regex, UCI)
#   frozen  – Bus lebt, aber das Panel antwortet nicht mehr (keine 0x320-
#             Frames). Ein statisch bleibender Text bei weiterlaufendem
#             83xx-Statusstrom ist KEIN Alarm; der Alarm meldet die
#             fehlende Panel-Antwort, nicht einen bewiesenen Steuerungs-
#             Absturz.
#   stale   – gar keine CAN-Nachrichten mehr (Bus/Bridge/Steuerung tot)
#
# Eine stale-Alarmfolge gilt erst dann als erholt, wenn wieder frische
# 0x320-Daten gesehen wurden ("keine Antwort" != "heizung wieder ok").
# Die Entlastungsmeldung sagt nur, dass die beobachtete Bedingung entfallen
# ist – sie behauptet keine Reparatur.
#
# Kanäle: Telegram (Bot-API via HTTPS GET) plus Alarm-URLs (Platzhalter
# %%TEXT%% wird URL-kodiert ersetzt; begrenzt auf die ersten
# ALARM_MAX_URLS Eintraege).
# Zugangsdaten stehen nur in UCI auf dem Geraet (Optionen alarm_* in Sektion
# heizungpanel.main) und erscheinen nie in Logs.
#
# Quittierung (nur Telegram, nur solange ein Alarm aktiv ist):
#   – Button auf der aktuellen Alarmmeldung: callback_data muss EXAKT
#     "ack:<episode>" der laufenden Episode entsprechen, und der Taechter
#     (from.id) muss der autorisierte Nutzer sein
#   – oder eine neue Nachricht DES autorisierten Nutzers aus dem
#     konfigurierten Chat
# Autorisiert ist (Option alarm_telegram_ack_user): der explizit
# konfigurierte Nutzer; ohne die Option bei positivem Chat (Privatchat)
# die Chat-ID selbst. Gruppenchat (negative ID) ohne diese Option:
# Quittierung klar deaktiviert – Gruppenmitglieder zaehlen nicht als
# autorisiert. Fremde Chats/Sender, fremde oder alte Buttons und
# Nachrichten vor dem Alarm (Update-ID <= Highwater) werden ignoriert und
# wegbestaetigt. Nach der Quittierung enden die Wiederholungen (Default
# 10 Min); die Episode bleibt bis zur entlastenden Normalisierung aktiv.
#
# Telegram-Antworten werden mit nativem ucode geparst
# (telegram_json.uc daneben; benoetigt ucode + ucode-mod-fs). Fehlt ucode,
# schlaegt der Telegram-Kanal kontrolliert fehl (fail closed).
#
# Aufruf: alarm_watchdog.sh MQTT_HOST MQTT_PORT TOPIC
#         alarm_watchdog.sh --test
#   --test sendet eine Testmeldung (OHNE Ack-Button, ohne CAN-/UCI-
#   Schreibzugriff) ueber alle Kanaele und endet mit der Maschinenzeile
#     TEST_ALARM_RESULT ok channels=N failed=0            (exit 0)
#     TEST_ALARM_RESULT fail channels=N failed=M reason=UNCONFIGURED|CONFIG_INVALID|DELIVERY_FAILED
#   N = Anzahl konfigurierter Kanaele (Telegram zaehlt als 1, jede
#   Alarm-URL als 1), M = gescheiterte. Annahme durch den Dienst ist keine
#   garantierte Telefon-Zustellung. Pro Kanal erscheint eine Zeile VOR der
#   Maschinenzeile; Test-URLs sind auf ALARM_MAX_TEST_URLS begrenzt.
# Test-Hooks: ALARM_TIME_DIVISOR skaliert alle Minuten-Werte (nur fuer Tests),
#             ALARM_STATE_DIR verschiebt das Statusverzeichnis.
set -eu

PROG=heizungpanel-alarm
DIV=${ALARM_TIME_DIVISOR:-1}
TAB=$(printf '\t')
TG_UC=$(dirname "$0")/telegram_json.uc
ALARM_MAX_URLS=5
ALARM_MAX_TEST_URLS=5

uci_get() {
	uci -q get "heizungpanel.main.alarm_$1" 2>/dev/null || printf '%s' "$2"
}

minutes_to_seconds() {
	awk -v m="$1" -v d="$DIV" 'BEGIN { s = int(m * 60 / d); if (s < 1) s = 1; printf "%d", s }'
}

url_encode() {
	LC_ALL=C awk '
	BEGIN {
		for (i = 1; i < 256; i++) ord[sprintf("%c", i)] = i
		safe = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._~-"
	}
	{
		n = split($0, ch, "")
		for (i = 1; i <= n; i++) {
			c = ch[i]
			if (index(safe, c) > 0)
				printf "%s", c
			else
				printf "%%%02X", ord[c]
		}
	}'
}

trim_ws() {
	printf '%s' "$1" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

FAULT_PATTERN=$(uci_get fault_pattern 'keine autom|Störung')
FAULT_CONFIRM_S=$(minutes_to_seconds "$(uci_get fault_confirm_minutes 3)")
FROZEN_S=$(minutes_to_seconds "$(uci_get frozen_minutes 60)")
STALE_S=$(minutes_to_seconds "$(uci_get stale_minutes 5)")
REPEAT_S=$(minutes_to_seconds "$(uci_get repeat_minutes 10)")
TICK=$(awk -v d="$DIV" 'BEGIN { t = 5 / d; if (t < 0.05) t = 0.05; printf "%.3f", t }')
TELEGRAM_TOKEN=$(trim_ws "$(uci_get telegram_token '')")
TELEGRAM_CHAT=$(trim_ws "$(uci_get telegram_chat '')")
ALARM_URLS=$(uci -q -d '
' get heizungpanel.main.alarm_url 2>/dev/null || true)
TG_API=https://api.telegram.org

# Validierung: Format pruefen und bei Fehler den Kanal abschalten; niemals
# still reparieren (Doppelpunkt im Token bleibt unangetastet, nur
# umgebende Leerzeichen werden entfernt).
TELEGRAM_ON=0
TELEGRAM_CFG=0
if [ -n "$TELEGRAM_TOKEN" ] || [ -n "$TELEGRAM_CHAT" ]; then
	TELEGRAM_CFG=1
	if printf '%s' "$TELEGRAM_TOKEN" | grep -Eq '^[0-9]+:[A-Za-z0-9_-]+$' \
		&& printf '%s' "$TELEGRAM_CHAT" | grep -Eq '^-?[0-9]+$'; then
		TELEGRAM_ON=1
	else
		logger -t "$PROG" "alarm telegram config invalid (need token <botid>:<secret> and numeric chat); telegram disabled"
		TELEGRAM_TOKEN=''
		TELEGRAM_CHAT=''
	fi
fi

_pat_rc=0
printf '' | grep -qE -- "$FAULT_PATTERN" 2>/dev/null || _pat_rc=$?
if [ "$_pat_rc" -eq 2 ]; then
	logger -t "$PROG" "alarm fault_pattern is not a valid regex; fault detection disabled"
	FAULT_PATTERN='$^'
fi

# Quittierungs-Autorisierung: expliziter Nutzer (alarm_telegram_ack_user),
# sonst bei positivem Chat (Privatchat) die Chat-ID selbst. Gruppenchat ohne
# expliziten Nutzer: Quittierung deaktiviert (fail closed).
AUTH_UID=''
if [ "$TELEGRAM_ON" = "1" ]; then
	_ack_user=$(trim_ws "$(uci_get telegram_ack_user '')")
	if [ -n "$_ack_user" ]; then
		if printf '%s' "$_ack_user" | grep -Eq '^[0-9]+$'; then
			AUTH_UID=$_ack_user
		else
			logger -t "$PROG" "alarm_telegram_ack_user invalid (must be numeric); acknowledgment disabled"
		fi
	elif printf '%s' "$TELEGRAM_CHAT" | grep -Eq '^[0-9]+$'; then
		AUTH_UID=$TELEGRAM_CHAT
	fi
	if [ -z "$AUTH_UID" ]; then
		logger -t "$PROG" "telegram acknowledgment disabled (group chat without alarm_telegram_ack_user)"
	fi
fi

command -v ucode >/dev/null 2>&1 || logger -t "$PROG" "ucode not found; telegram channel fails closed (needs ucode + ucode-mod-fs)"
[ -f "$TG_UC" ] || logger -t "$PROG" "telegram helper missing ($TG_UC); telegram channel fails closed"

# Episoden-Nonce (CSPRNG): verhindert Button-Replay ueber Neustarts im
# selben Sekundenfenster; der Zaehler trennt Episoden im Prozess.
NONCE=$(head -c 16 /dev/urandom 2>/dev/null | md5sum | cut -c1-16)
case "$NONCE" in
'' | *[!0-9a-f]*) NONCE="n$(date +%s)" ;;
esac

# Telegram-Antworten werden ausschliesslich mit nativem ucode geparst
# (telegram_json.uc, s. Kopf). Normierte Datensaetze, Spalten per Tab:
#   ERR / ok true|false / chat <id> / CB uid cbid chat from data /
#   MSG uid - chat from - / OTHER uid - - - -
# Fehlt ucode oder der Helper, schlagen alle Aufrufe kontrolliert fehl.
tg_records() {
	ucode "$TG_UC" 2>/dev/null
}

tg_field() { # $1 Body, $2 Feldname (ok|chat) -> Wert oder leer
	printf '%s' "$1" | tg_records | awk -F'\t' -v k="$2" '$1 == k { print $2; exit }'
}

tg_body_ok() {
	[ "$(tg_field "$1" ok)" = "true" ]
}

# Neueste ausstehende update_id ermitteln (offset=-1 liefert nur die letzte,
# ohne etwas zu bestaetigen). Gueltige leere Liste liefert 0; Fehler exit 1.
tg_highwater() {
	_b=$(fetch_url "${TG_API}/bot${TELEGRAM_TOKEN}/getUpdates?offset=-1&limit=1&timeout=0") || return 1
	printf '%s' "$_b" | tg_records | awk -F'\t' '
		$1 == "ERR" { bad = 1 }
		$1 == "ok" { good = ($2 == "true") }
		$1 == "updates" { list = 1; expected = $2 + 0 }
		$1 == "CB" || $1 == "MSG" || $1 == "OTHER" { seen++; if ($2 + 0 > m) m = $2 + 0 }
		END { if (bad || !good || !list || seen != expected) exit 1; print int(m) }'
}
fetch_url() {
	uclient-fetch -q -O - -T 15 "$1" 2>/dev/null
}

tg_answer() {
	_id=$1
	if ! _b=$(fetch_url "${TG_API}/bot${TELEGRAM_TOKEN}/answerCallbackQuery?callback_query_id=${_id}"); then
		logger -t "$PROG" "answerCallbackQuery fetch failed"
		return 0
	fi
	tg_body_ok "$_b" || logger -t "$PROG" "answerCallbackQuery not accepted"
	return 0
}

# Sendet auf allen Kanälen; setzt DELIVERED=1 nur wenn jeder konfigurierte
# Kanal die Nachricht angenommen hat (Telegram via ok:true).
send_to_channels() {
	_text_raw=$1
	_episode=${2:-}
	_enc=$(printf '%s' "$_text_raw" | url_encode)
	DELIVERED=1
	if [ "$TELEGRAM_ON" = "1" ]; then
		_url="${TG_API}/bot${TELEGRAM_TOKEN}/sendMessage?chat_id=${TELEGRAM_CHAT}&text=${_enc}"
		if [ -n "$_episode" ]; then
			_btn=$(printf '{"inline_keyboard":[[{"text":"ACKNOWLEDGE: Alarm quittieren","callback_data":"ack:%s"}]]}' "$_episode" | url_encode)
			_url="${_url}&reply_markup=${_btn}"
		fi
		_b=$(fetch_url "$_url") && tg_body_ok "$_b" || {
			DELIVERED=0
			logger -t "$PROG" "telegram delivery failed"
		}
	fi
	if [ -n "$ALARM_URLS" ]; then
		_un=0
		_capped=0
		while IFS= read -r _u; do
			case "$_u" in
			https://*|http://*) ;;
			*) continue ;;
			esac
			_un=$((_un + 1))
			if [ "$_un" -gt "$ALARM_MAX_URLS" ]; then
				_capped=1
				continue
			fi
			_u2=$(printf '%s' "$_u" | sed "s|%%TEXT%%|${_enc}|g")
			fetch_url "$_u2" >/dev/null || {
				DELIVERED=0
				logger -t "$PROG" "alarm url delivery failed"
			}
		done <<EOF
$ALARM_URLS
EOF
		[ "$_capped" = "1" ] && logger -t "$PROG" "alarm url list capped at $ALARM_MAX_URLS, extra channels skipped"
	fi
	return 0
}

if [ "${1:-}" = "--test" ]; then
	_cfg=0
	_fail=0
	_cfginv=0
	_test_msg="HEIZUNG Test-Alarm: Konfiguration ok ($(date '+%d.%m %H:%M %Z'))"
	if [ "$TELEGRAM_CFG" = "1" ]; then
		_cfg=$((_cfg + 1))
		if [ "$TELEGRAM_ON" != "1" ]; then
			echo "telegram: FAIL CONFIG_INVALID"
			_fail=$((_fail + 1))
			_cfginv=1
		elif ! command -v ucode >/dev/null 2>&1 || [ ! -f "$TG_UC" ]; then
			echo "telegram: FAIL CONFIG_INVALID"
			_fail=$((_fail + 1))
			_cfginv=1
		else
			_enc=$(printf '%s' "$_test_msg" | url_encode)
			if ! _b=$(fetch_url "${TG_API}/bot${TELEGRAM_TOKEN}/sendMessage?chat_id=${TELEGRAM_CHAT}&text=${_enc}"); then
				echo "telegram: FAIL TRANSPORT"
				_fail=$((_fail + 1))
			elif [ "$(tg_field "$_b" ok)" != "true" ]; then
				echo "telegram: FAIL API_REJECTED"
				_fail=$((_fail + 1))
			elif [ "$(tg_field "$_b" chat)" != "$TELEGRAM_CHAT" ]; then
				echo "telegram: FAIL CHAT_MISMATCH"
				_fail=$((_fail + 1))
			else
				echo "telegram: ACCEPT (Dienst hat angenommen; Telefon-Zustellung unbestaetigt)"
			fi
		fi
	fi
	_n=0
	if [ -n "$ALARM_URLS" ]; then
		while IFS= read -r _tu; do
			_tu=$(printf '%s' "$_tu" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
			[ -n "$_tu" ] || continue
			_n=$((_n + 1))
			_cfg=$((_cfg + 1))
			case "$_tu" in
			https://*|http://*) ;;
			*)
				echo "url${_n}: FAIL CONFIG_INVALID"
				_fail=$((_fail + 1))
				_cfginv=1
				continue
				;;
			esac
			if [ "$_n" -gt "$ALARM_MAX_TEST_URLS" ]; then
				echo "url${_n}: FAIL LIMIT"
				_fail=$((_fail + 1))
				continue
			fi
			_tu2=$(printf '%s' "$_tu" | sed "s|%%TEXT%%|$(printf '%s' "$_test_msg" | url_encode)|g")
			if fetch_url "$_tu2" >/dev/null; then
				echo "url${_n}: ACCEPT"
			else
				echo "url${_n}: FAIL TRANSPORT"
				_fail=$((_fail + 1))
			fi
		done <<EOF
$ALARM_URLS
EOF
	fi
	if [ "$_cfg" -eq 0 ]; then
		echo "TEST_ALARM_RESULT fail channels=0 failed=0 reason=UNCONFIGURED"
		exit 1
	fi
	if [ "$_fail" -eq 0 ]; then
		echo "TEST_ALARM_RESULT ok channels=$_cfg failed=0"
		exit 0
	fi
	if [ "$_cfginv" = "1" ]; then
		_reason=CONFIG_INVALID
	else
		_reason=DELIVERY_FAILED
	fi
	echo "TEST_ALARM_RESULT fail channels=$_cfg failed=$_fail reason=$_reason"
	exit 1
fi

[ $# -ge 3 ] || { echo "Usage: $0 MQTT_HOST MQTT_PORT TOPIC | --test" >&2; exit 64; }
MQTT_HOST_ARG=$1
MQTT_PORT_ARG=$2
TOPIC_ARG=$3

[ "$(uci_get enabled 0)" = "1" ] || { logger -t "$PROG" "alarm disabled (heizungpanel.alarm.enabled != 1), exiting"; exit 0; }

STATE_DIR=${ALARM_STATE_DIR:-/tmp/heizungpanel-alarm}
umask 077
if ! mkdir "$STATE_DIR" 2>/dev/null; then
	_state_owner=$(id -u)
	_state_meta=$(stat -c '%u:%a' "$STATE_DIR" 2>/dev/null) || _state_meta=''
	case "$_state_meta" in
	"$_state_owner:700"|"$_state_owner:750"|"$_state_owner:755") ;;
	*) logger -t "$PROG" "unsafe alarm runtime directory; refusing startup"; exit 73 ;;
	esac
	if [ -L "$STATE_DIR" ] || [ ! -d "$STATE_DIR" ]; then
		logger -t "$PROG" "unsafe alarm runtime directory; refusing startup"
		exit 73
	fi
	chmod 700 "$STATE_DIR"
fi
for _state_name in status telegram_highwater; do
	if [ -L "$STATE_DIR/$_state_name" ] || { [ -e "$STATE_DIR/$_state_name" ] && [ ! -f "$STATE_DIR/$_state_name" ]; }; then
		logger -t "$PROG" "unsafe alarm runtime file; refusing startup"
		exit 73
	fi
done

write_state() {
	_state_tmp=$(mktemp "$STATE_DIR/.$1.XXXXXX") || return 1
	# Unique files inside the verified private directory; -T never follows a target directory symlink.
	if cat > "$_state_tmp" && mv -fT "$_state_tmp" "$STATE_DIR/$1"; then
		return 0
	fi
	rm -f "$_state_tmp"
	return 1
}

# Zustandsloser Taktgeber: liefert nur Zeitmarken, haelt keinerlei
# Alarmvariablen (alle Zustände leben im einzelnen Verbraucherprozess).
ticker() {
	while :; do
		printf 'T\t%s\n' "$(date +%s)"
		sleep "$TICK"
	done
}

# StrikterDecoder, semantisch wie parseCandump/applyRawLine in panel.js:
# beide candump-Formate, strictDLC 1..8, Hex-Paar-Validierung, 0x81-Clear,
# 0x83-Status ab DLC 2, Zeilengrenzen bei 20/40. Ereignisse (Tab-getrennt):
#   M <ep> <id>   gueltiger Frame (beliebige ID)
#   D <ep> <r1> <r2>  Displayaenderung
#   S <ep> 83XX   Statusaenderung
decoder() {
	mosquitto_sub -h "$MQTT_HOST_ARG" -p "$MQTT_PORT_ARG" -t "$TOPIC_ARG" 2>/dev/null | awk '
	function h2d(h,  v, c, i, d) {
		h = toupper(h); d = 0
		for (i = 1; i <= length(h); i++) {
			c = substr(h, i, 1)
			if (c >= "0" && c <= "9") v = c + 0
			else v = index("123456789ABCDEF", c)
			d = d * 16 + v
		}
		return d
	}
	function chr(b) {
		if (b == 0xDF) return "\302\260"
		if (b == 0xE2) return "\303\237"
		if (b == 0xF5) return "\303\274"
		if (b == 0xE1) return "\303\244"
		if (b == 0xEF) return "\303\266"
		if (b >= 32 && b <= 126) return sprintf("%c", b)
		return " "
	}
	function hexid(tok,  t, i) {
		t = toupper(tok)
		if (t == "" || length(t) > 8) return ""
		for (i = 1; i <= length(t); i++)
			if (index("0123456789ABCDEF", substr(t, i, 1)) == 0) return ""
		sub(/^0+/, "", t)
		return (t == "") ? "0" : t
	}
	function lcdidx(off) {
		if (off >= 0 && off <= 19) return off
		if (off >= 64 && off <= 83) return 20 + off - 64
		return -1
	}
	function render(  i, r1, r2) {
		r1 = ""; r2 = ""
		for (i = 0; i < 20; i++) r1 = r1 lcd[i]
		for (i = 20; i < 40; i++) r2 = r2 lcd[i]
		return r1 "\t" r2
	}
	function try_compact(ln,  h, pre, tok, d, c1, c2, cnt) {
		h = index(ln, "#")
		if (h < 1) return ""
		pre = substr(ln, 1, h - 1)
		sub(/[ \t]+$/, "", pre)
		tok = pre
		sub(/^.*[ \t]/, "", tok)
		id = hexid(tok)
		if (id == "") return ""
		d = toupper(substr(ln, h + 1))
		dhex = ""
		cnt = 0
		while (length(d) >= 2 && cnt < 8) {
			c1 = substr(d, 1, 1); c2 = substr(d, 2, 1)
			if (index("0123456789ABCDEF", c1) == 0 || index("0123456789ABCDEF", c2) == 0) break
			dhex = dhex c1 c2
			d = substr(d, 3)
			cnt++
		}
		sub(/^[ \t]+/, "", d)
		if (dhex == "" || d != "") return ""
		return id
	}
	function try_bracket(ln,  lb, rb, pre, tok, dl, rest, nb, k, tk, got, stop) {
		lb = index(ln, "[")
		if (lb < 1) return ""
		rb = index(ln, "]")
		if (rb <= lb + 1) return ""
		pre = substr(ln, 1, lb - 1)
		sub(/[ \t]+$/, "", pre)
		tok = pre
		sub(/^.*[ \t]/, "", tok)
		id = hexid(tok)
		if (id == "") return ""
		dl = substr(ln, lb + 1, rb - lb - 1)
		if (dl !~ /^[0-9]+$/) return ""
		dlc = dl + 0
		if (dlc < 1 || dlc > 8) return ""
		rest = substr(ln, rb + 1)
		sub(/^[ \t]+/, "", rest)
		nb = split(rest, B, /[ \t]+/)
		dhex = ""
		got = 0
		stop = 0
		for (k = 1; k <= nb && !stop; k++) {
			tk = toupper(B[k])
			if (substr(tk, 1, 1) == "\047") { stop = 1; continue }
			if (length(tk) == 2 && index("0123456789ABCDEF", substr(tk, 1, 1)) > 0 && index("0123456789ABCDEF", substr(tk, 2, 1)) > 0) {
				dhex = dhex tk
				got++
			} else {
				return ""
			}
		}
		if (got != dlc) return ""
		return id
	}
	BEGIN {
		for (i = 0; i < 40; i++) lcd[i] = " "
		lcdstr = render()
		status = ""
	}
	{
		ln = $0
		sub(/^[ \t]+/, "", ln)
		if (ln == "") next
		ep = 0
		if (substr(ln, 1, 1) == "(") {
			i = index(ln, ")")
			if (i > 2) {
				ep = substr(ln, 2, i - 2) + 0
				ln = substr(ln, i + 1)
				sub(/^[ \t]+/, "", ln)
			}
		}
		if (ep <= 0) ep = systime()
		id = try_compact(ln)
		if (id == "") id = try_bracket(ln)
		if (id == "") next
		printf "M\t%d\t%s\n", ep, id
		fflush()
		if (id != "320") next
		b0 = h2d(substr(dhex, 1, 2))
		dlc = length(dhex) / 2
		if (b0 == 129) {
			for (i = 0; i < 40; i++) lcd[i] = " "
		} else if (b0 == 131) {
			if (dlc >= 2) {
				st = substr(dhex, 3, 2)
				if (st != status) {
					status = st
					printf "S\t%d\t83%s\n", ep, st
				}
			}
		} else if (dlc >= 2) {
			idx = lcdidx(b0)
			if (idx >= 0) {
				rowend = (idx < 20) ? 20 : 40
				ii = idx
				for (j = 3; j <= length(dhex) - 1; j += 2) {
					if (ii >= rowend) break
					lcd[ii] = chr(h2d(substr(dhex, j, 2)))
					ii++
				}
			}
		} else {
			next
		}
		cur = render()
		if (cur != lcdstr) {
			lcdstr = cur
			printf "D\t%d\t%s\n", ep, cur
		}
		fflush()
	}'
}

save_hw() {
	printf '%s\n' "$ACK_HW" | write_state telegram_highwater
}

# Fragt neue Telegram-Updates ab (offset = Highwater+1, damit nichts
# Historisches zurueckkommt) und verarbeitet sie. Autorisierung: Chat UND
# Sender muessen exakt passen, callback_data muss exakt der laufenden
# Episode entsprechen. Rueckgabe 1 nur bei Transport-/ok-Fehlern (Poll bleibt
# beim naechsten Takt).
poll_ack() {
	_recs=$(fetch_url "${TG_API}/bot${TELEGRAM_TOKEN}/getUpdates?offset=$((ACK_HW + 1))&limit=10&timeout=0") || return 1
	_recs=$(printf '%s' "$_recs" | tg_records)
	_newhw=$ACK_HW
	_ans=''
	_rej=0
	while IFS="$TAB" read -r _k _uid _cbid _chat _from _data; do
		[ -n "${_k:-}" ] || continue
		case "$_k" in
		ok)
			[ "$_uid" = "true" ] || return 1
			;;
		ERR)
			return 1
			;;
		chat)
			;;
		CB|MSG)
			case "$_uid" in '' | *[!0-9]*) continue ;; esac
			if [ "$_uid" -le "$ACK_HW" ]; then continue; fi
			if [ "$_uid" -gt "$_newhw" ]; then _newhw=$_uid; fi
			if [ "$ALARM_ACKED" = "0" ]; then
				if [ "$_chat" = "$TELEGRAM_CHAT" ] && [ -n "$AUTH_UID" ] && [ "$_from" = "$AUTH_UID" ] \
					&& { { [ "$_k" = "MSG" ] && [ "$TEXT_ACK_READY" = "1" ]; } || { [ "$_k" = "CB" ] && [ "$_data" = "ack:${EPISODE}" ]; }; }; then
					ALARM_ACKED=1
					if [ "$_k" = "CB" ]; then
						_ans=$_cbid
						logger -t "$PROG" "alarm acknowledged via Telegram button"
					else
						logger -t "$PROG" "alarm acknowledged via Telegram message"
					fi
				else
					_rej=$((_rej + 1))
				fi
			fi
			;;
		OTHER)
			case "$_uid" in '' | *[!0-9]*) continue ;; esac
			if [ "$_uid" -gt "$_newhw" ]; then _newhw=$_uid; fi
			;;
		*)
			;;
		esac
	done <<EOF
$_recs
EOF
	if [ "$_rej" -gt 0 ]; then
		logger -t "$PROG" "telegram updates ignored (fremd oder veraltet): $_rej"
	fi
	if [ -n "$_ans" ]; then
		tg_answer "$_ans"
	fi
	if [ "$_newhw" != "$ACK_HW" ]; then
		ACK_HW=$_newhw
		save_hw
	fi
	return 0
}

_now=$(date +%s)
LAST_MSG=$_now
LAST_320=$_now
LAST_DISP_CHANGE=$_now
FAULT_SINCE=''
FAULT_MATCH=0
LAST_SENT=''
BACKOFF_S=$REPEAT_S
CONSEC_FAIL=0
ALARMING=0
ALARM_ACKED=0
TEXT_ACK_READY=0
EPISODE=''
EPISODE_N=0
REASON=''
NEED_EVIDENCE=0
EVID_TS=0
HAVE_CONTENT=0
L1=''
L2=''
STATUS='--'
TICK_N=0
ACK_HW=0
if [ -f "$STATE_DIR/telegram_highwater" ]; then
	ACK_HW=$(cat "$STATE_DIR/telegram_highwater" 2>/dev/null || printf '0')
	case "$ACK_HW" in '' | *[!0-9]*) ACK_HW=0 ;; esac
fi

logger -t "$PROG" "watcher start (Log-Zeitzone $(date +%Z)): frozen=${FROZEN_S}s stale=${STALE_S}s confirm=${FAULT_CONFIRM_S}s repeat=${REPEAT_S}s pattern=[$FAULT_PATTERN] telegram=$([ "$TELEGRAM_ON" = "1" ] && echo on || echo off) urls=$(printf '%s\n' "$ALARM_URLS" | grep -c . || true)"

{ ticker & decoder; } | while IFS="$TAB" read -r _typ _ts _rest; do
	[ -n "${_ts:-}" ] || continue
	case "$_typ" in
	T)
		TICK_N=$((TICK_N + 1))
		if [ "$ALARMING" = "1" ] && [ "$ALARM_ACKED" = "0" ] && [ "$TELEGRAM_ON" = "1" ] && [ $((TICK_N % 6)) -eq 0 ]; then
			poll_ack || logger -t "$PROG" "telegram poll failed"
		fi
		;;
	M)
		LAST_MSG=$_ts
		if [ "$_rest" = "320" ]; then
			LAST_320=$_ts
			EVID_TS=$_ts
		fi
		;;
	D)
		LAST_MSG=$_ts
		LAST_320=$_ts
		EVID_TS=$_ts
		LAST_DISP_CHANGE=$_ts
		HAVE_CONTENT=1
		L1=${_rest%%"$TAB"*}
		L2=${_rest#*"$TAB"}
		if printf '%s %s' "$L1" "$L2" | grep -qE -- "$FAULT_PATTERN"; then
			FAULT_MATCH=1
		else
			FAULT_MATCH=0
		fi
		;;
	S)
		LAST_MSG=$_ts
		LAST_320=$_ts
		EVID_TS=$_ts
		STATUS=$_rest
		;;
	*)
		continue
		;;
	esac

	_age_msg=$((_ts - LAST_MSG))
	_age320=$((_ts - LAST_320))
	_fault=0
	if [ "$HAVE_CONTENT" = "1" ] && [ "$FAULT_MATCH" = "1" ]; then
		if [ -z "$FAULT_SINCE" ]; then
			FAULT_SINCE=$_ts
		fi
		if [ $((_ts - FAULT_SINCE)) -ge "$FAULT_CONFIRM_S" ]; then
			_fault=1
		fi
	else
		FAULT_SINCE=''
	fi
	_frozen=0
	_stale=0
	if [ "$_age_msg" -ge "$STALE_S" ]; then
		_stale=1
	elif [ "$_age320" -ge "$FROZEN_S" ]; then
		_frozen=1
	fi

	_cond=''
	if [ "$_fault" = "1" ]; then _cond="$_cond Fehlertext"; fi
	if [ "$_frozen" = "1" ]; then _cond="$_cond keine-0x320-Antwort(${_age320}s)"; fi
	if [ "$_stale" = "1" ]; then _cond="$_cond keine-CAN-Daten(${_age_msg}s)"; fi
	if [ -z "$_cond" ] && [ "$ALARMING" = "1" ] && [ "$NEED_EVIDENCE" = "1" ] && [ "$EVID_TS" -lt "$_ts" ]; then
		_cond=' warte-auf-Display-Daten'
	fi

	if [ -n "$_cond" ]; then
		_send=0
		if [ "$ALARM_ACKED" = "0" ]; then
			if [ "$ALARMING" = "0" ]; then
				_send=1
			elif [ -z "$LAST_SENT" ] || [ $((_ts - LAST_SENT)) -ge "$BACKOFF_S" ]; then
				_send=1
			fi
		fi
		if [ "$_send" = "1" ]; then
			if [ "$ALARMING" = "0" ] || [ -z "$EPISODE" ]; then
				EPISODE_N=$((EPISODE_N + 1))
				EPISODE="${NONCE}-${EPISODE_N}"
			fi
			REASON=$_cond
			if [ "$TELEGRAM_ON" = "1" ] && [ "$ALARMING" = "0" ]; then
				TEXT_ACK_READY=0
				if _hw=$(tg_highwater); then
					if [ "$_hw" -gt "$ACK_HW" ]; then ACK_HW=$_hw; fi
					TEXT_ACK_READY=1
				else
					logger -t "$PROG" "telegram cutoff unavailable; text acknowledgment disabled for this episode"
				fi
				save_hw
			fi
			_ack_note=''
			if [ "$TELEGRAM_ON" = "1" ] && [ "$TEXT_ACK_READY" = "0" ]; then
				_ack_note=' Textquittierung fuer diese Episode deaktiviert; aktuellen Quittier-Button verwenden.'
			fi
			send_to_channels "HEIZUNG ALARM $(date '+%d.%m %H:%M %Z') Grund:$REASON Display:[$L1][$L2] Status:$STATUS$_ack_note" "$EPISODE"
			if [ "$DELIVERED" = "1" ]; then
				CONSEC_FAIL=0
				BACKOFF_S=$REPEAT_S
			else
				CONSEC_FAIL=$((CONSEC_FAIL + 1))
				# busybox awk kommt ohne Mathe-Support aus: 2**n als Schleife
				BACKOFF_S=$(awk -v t="$TICK" -v n="$CONSEC_FAIL" -v cap="$REPEAT_S" 'BEGIN { b = t; for (i = 0; i < n; i++) b = b * 2; if (b > cap) b = cap; if (b < 1) b = 1; printf "%d", b }')
			fi
			case "$REASON" in *keine-CAN-Daten*) NEED_EVIDENCE=1 ;; esac
			LAST_SENT=$_ts
			ALARMING=1
			logger -t "$PROG" "alarm sent:$REASON delivery=$DELIVERED fails=$CONSEC_FAIL episode=$EPISODE"
		fi
	elif [ "$ALARMING" = "1" ]; then
		send_to_channels "HEIZUNG OK $(date '+%d.%m %H:%M %Z') Alarmgrund entfallen (beobachteter Zustand unauffaellig, keine Reparatur bestaetigt). Display:[$L1][$L2] Status:$STATUS" ''
		logger -t "$PROG" "recovery sent (Alarmbedingung entfallen, frische 0x320-Daten gesehen)"
		ALARMING=0
		ALARM_ACKED=0
		TEXT_ACK_READY=0
		EPISODE=''
		LAST_SENT=''
		REASON=''
		NEED_EVIDENCE=0
		CONSEC_FAIL=0
		BACKOFF_S=$REPEAT_S
	fi

	printf 'now=%s last_msg=%s last_320=%s last_disp_change=%s fault_since=%s alarming=%s acked=%s episode=%s ack_hw=%s last_sent=%s backoff=%s fails=%s need_evidence=%s status=%s display=[%s][%s] reason=%s\n' \
		"$_ts" "$LAST_MSG" "$LAST_320" "$LAST_DISP_CHANGE" "${FAULT_SINCE:-na}" "$ALARMING" "$ALARM_ACKED" "${EPISODE:-na}" "$ACK_HW" "${LAST_SENT:-na}" "$BACKOFF_S" "$CONSEC_FAIL" "$NEED_EVIDENCE" "$STATUS" "$L1" "$L2" "${REASON:-na}" \
		| write_state status
done
