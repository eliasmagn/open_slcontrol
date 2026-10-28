// Telegram-JSON -> tab-getrennte Datensaetze fuer alarm_watchdog.sh.
// Einziger Zweck: strukturiertes Parsen mit nativem ucode statt grep-
// Fragmenten. Die gesamte Richtlinienpruefung (Chat, Sender, callback_data,
// Offset) bleibt im Watchdog-Skript. Hier werden Feldtypen und das
// Datensatzformat geprueft, damit fremde Daten keine Zeilen einschleusen.
//
// Eingabe: genau ein Telegram-Bot-API-JSON-Dokument auf stdin.
// Ausgabe (Spalten durch Tab, fehlende Felder als "-"):
//   ERR                          Dokument nicht lesbar/kein Objekt
//   ok<TAB>true|false            top-level "ok", falls boolesch
//   chat<TAB><id>                result.chat.id, falls vorhanden
//   updates<TAB>count            Laenge eines result-Arrays
//   CB<TAB>uid<TAB>cbid<TAB>chat<TAB>from<TAB>data
//   MSG<TAB>uid<TAB>-<TAB>chat<TAB>from<TAB>-      (neue Textnachricht)
//   OTHER<TAB>uid<TAB>-<TAB>-<TAB>-<TAB>-
import { stdin } from "fs";

let doc;
try {
	doc = json(stdin.read("all"));
} catch (e) {
	doc = null;
}
if (type(doc) != "object" || type(doc.ok) != "bool") {
	print("ERR\n");
} else {
	print(`ok\t${doc.ok}\n`);
	if (!doc.ok)
		exit(0);
	let rchat = doc?.result?.chat?.id;
	if (type(rchat) == "int")
		print(`chat\t${rchat}\n`);
	if (type(doc?.result) == "array") {
		print(`updates\t${length(doc.result)}\n`);
		for (let i = 0; i < length(doc.result); i++) {
			let u = doc.result[i];
			let uid = u?.update_id;
			if (type(uid) != "int" || uid < 0 || uid > 2147483646)
				continue;
			let cb = u?.callback_query;
			let m = u?.message;
			let cbid = type(cb?.id) == "string" ? match(cb.id, /^[A-Za-z0-9_-]+$/) : null;
			let data = type(cb?.data) == "string" ? match(cb.data, /^ack:[0-9a-f]{16}-[0-9]+$/) : null;
			if (type(cb) == "object" && cbid && cbid[0] === cb.id
			    && type(cb?.message?.chat?.id) == "int"
			    && type(cb?.from?.id) == "int"
			    && data && data[0] === cb.data) {
				print(`CB\t${uid}\t${cb.id}\t${cb.message.chat.id}\t${cb.from.id}\t${cb.data}\n`);
			} else if (type(m) == "object" && type(m.text) == "string"
			           && length(m.text) > 0 && type(m?.chat?.id) == "int"
			           && type(m?.from?.id) == "int") {
				print(`MSG\t${uid}\t-\t${m.chat.id}\t${m.from.id}\t-\n`);
			} else {
				print(`OTHER\t${uid}\t-\t-\t-\t-\n`);
			}
		}
	}
}
