function clear_sequence() { position = 0; last = 0 }
function close_access() { mode = "closed"; deadline = 0; held = 0; clear_sequence() }
function tolerance(value, result) {
    result = value * jitter / 100
    return result > minimum ? result : minimum
}
function matches(actual, expected) {
    return actual >= expected - tolerance(expected) && actual <= expected + tolerance(expected)
}
BEGIN { OFMT = "%.0f"; CONVFMT = "%.0f"; mode = "closed"; last = 0; position = 0; deadline = 0; held = 0; started = 0; count = 0; first = ""; samples = ""; candidate = ""; error = "" }
$1 == "mode" { mode = $2 }
$1 == "last" { last = $2 + 0 }
$1 == "index" { position = $2 + 0 }
$1 == "deadline" { deadline = $2 + 0 }
$1 == "held" { held = $2 + 0 }
$1 == "started" { started = $2 + 0 }
$1 == "count" { count = $2 + 0 }
$1 == "first" { first = $2 }
$1 == "samples" { samples = $2 }
$1 == "candidate" { candidate = $2 }
$1 == "error" { error = $2 }
END {
    if (cmd == "close" || cmd == "reset") close_access()
    else if (cmd == "learn-start") {
        close_access(); mode = "record"; started = now; count = 0
        first = ""; samples = ""; candidate = ""; error = ""
    }
    else if (cmd == "learn-next") {
        if (mode != "record" || count < 4 || count > 16) error = "press_count"
        else { first = samples; samples = ""; count = 0; last = 0; mode = "confirm"; started = now; error = "" }
    }
    else if (cmd == "learn-finish") {
        n = split(first, a, ","); m = split(samples, b, ",")
        if (mode != "confirm" || count < 4 || n != m) error = "press_count"
        else {
            candidate = ""; error = ""
            for (i = 1; i <= n; i++) {
                if (!matches(b[i] + 0, a[i] + 0)) { error = "mismatch"; break }
                value = int((a[i] + b[i]) / 2)
                candidate = candidate (i == 1 ? "" : ",") value
            }
            if (error == "") mode = "ready"
            else candidate = ""
        }
    }
    else if (cmd == "tick") {
        if (mode == "open") {
            if (sessions > 0) { held = 1; deadline = now + window * 1000 }
            else {
                if (held) deadline = now + window * 1000
                held = 0
                if (now >= deadline) close_access()
            }
        }
        else if ((mode == "record" || mode == "confirm" || mode == "ready" || mode == "error") && now - started > 60000) {
            close_access(); error = "learning_timeout"; candidate = ""
        }
    }
    else if (cmd == "button") {
        gap = now - last
        if (last > 0 && gap < 120) { }
        else if (mode == "open") close_access()
        else if (mode == "record" || mode == "confirm") {
            if (count >= 16 || (count > 0 && (gap < 120 || gap > 10000))) { mode = "error"; error = "timing"; candidate = "" }
            else {
                if (count > 0) samples = samples (samples == "" ? "" : ",") gap
                count++; last = now; error = ""
            }
        }
        else if (mode == "closed" && enabled == 1) {
            n = split(sequence, expected, ",")
            if (position == 0 || !matches(gap, expected[position] + 0)) position = 1
            else position++
            last = now
            if (position > n) { mode = "open"; deadline = now + window * 1000; held = 0; position = 0 }
        }
    }
    print "mode", mode
    print "last", last
    print "index", position
    print "deadline", deadline
    print "held", held
    print "started", started
    print "count", count
    print "first", first
    print "samples", samples
    print "candidate", candidate
    print "error", error
}
