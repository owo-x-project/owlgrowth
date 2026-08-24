# JSON, UTF-8, and bounded projection helpers for OwlGrowth.

function ws(s, i) {
    while (i <= length(s) && substr(s, i, 1) ~ /[[:space:]]/) i++
    return i
}

function string_end(s, i, c) {
    i++
    while (i <= length(s)) {
        c = substr(s, i, 1)
        if (c == "\\") i += 2
        else if (c == "\"") return i
        else i++
    }
    return -1
}

function value_end(s, i, c, open, closer, depth) {
    i = ws(s, i)
    c = substr(s, i, 1)
    if (c == "\"") return string_end(s, i)
    if (c == "{" || c == "[") {
        for (open in value_stack) delete value_stack[open]
        value_stack[1] = c; depth = 1; i++
        while (i <= length(s)) {
            c = substr(s, i, 1)
            if (c == "\"") i = string_end(s, i)
            else if (c == "{" || c == "[") { value_stack[++depth] = c }
            else if (c == "}" || c == "]") {
                if ((value_stack[depth] == "{" && c == "}") || (value_stack[depth] == "[" && c == "]")) {
                    delete value_stack[depth]
                    depth--
                    if (depth == 0) return i
                }
            }
            i++
        }
        return -1
    }
    while (i <= length(s)) {
        c = substr(s, i, 1)
        if (c == "," || c == "}" || c == "]" || c ~ /[[:space:]]/) return i - 1
        i++
    }
    return length(s)
}

# Set GET_PRESENT, GET_RAW and GET_STRING for one top-level object member.
function object_get(obj, wanted, i, e, k_end, key, start, c) {
    GET_PRESENT = 0; GET_RAW = ""; GET_STRING = ""
    i = ws(obj, 1)
    if (substr(obj, i, 1) != "{") return 0
    i = ws(obj, i + 1)
    while (i <= length(obj) && substr(obj, i, 1) != "}") {
        if (substr(obj, i, 1) != "\"") return 0
        k_end = string_end(obj, i)
        if (k_end < 0) return 0
        key = json_decode(substr(obj, i, k_end - i + 1))
        i = ws(obj, k_end + 1)
        if (substr(obj, i, 1) != ":") return 0
        start = ws(obj, i + 1); e = value_end(obj, start)
        if (e < start) return 0
        if (key == wanted) {
            GET_PRESENT = 1; GET_RAW = substr(obj, start, e - start + 1)
            c = substr(GET_RAW, 1, 1)
            if (c == "\"") GET_STRING = json_decode(GET_RAW)
            return 1
        }
        i = ws(obj, e + 1)
        if (substr(obj, i, 1) == ",") i = ws(obj, i + 1)
        else if (substr(obj, i, 1) != "}") return 0
    }
    return 0
}

function json_decode(s, i, c, out, hex, n, low_hex, low) {
    out = ""; i = 2
    while (i < length(s)) {
        c = substr(s, i, 1)
        if (c == "\\") {
            i++; c = substr(s, i, 1)
            if (c == "n") out = out "\n"
            else if (c == "r") out = out "\r"
            else if (c == "t") out = out "\t"
            else if (c == "b") out = out "\b"
            else if (c == "f") out = out "\f"
            else if (c == "u" && i + 4 < length(s)) {
                hex = substr(s, i + 1, 4); n = hex_value(hex)
                if (n >= 55296 && n <= 56319 && substr(s, i + 5, 2) == "\\u") {
                    low_hex = substr(s, i + 7, 4); low = hex_value(low_hex)
                    if (low >= 56320 && low <= 57343) { n = 65536 + (n - 55296) * 1024 + low - 56320; out = out utf8_encode(n); i += 10 }
                    else { out = out "\\u" hex; i += 4 }
                } else if (n >= 55296 && n <= 57343) { out = out "\\u" hex; i += 4 }
                else if (n == 8) { out = out "\b"; i += 4 }
                else if (n == 9) { out = out "\t"; i += 4 }
                else if (n == 10) { out = out "\n"; i += 4 }
                else if (n == 12) { out = out "\f"; i += 4 }
                else if (n == 13) { out = out "\r"; i += 4 }
                else if (n < 32) { out = out "\\u" hex; i += 4 }
                else { out = out utf8_encode(n); i += 4 }
            } else out = out c
        } else if (c == "\"") return out
        else out = out c
        i++
    }
    return out
}

function utf8_encode(n) {
    if (n < 128) return sprintf("%c", n)
    if (n < 2048) return sprintf("%c%c", 192 + int(n / 64), 128 + (n % 64))
    if (n < 65536) return sprintf("%c%c%c", 224 + int(n / 4096), 128 + (int(n / 64) % 64), 128 + (n % 64))
    return sprintf("%c%c%c%c", 240 + int(n / 262144), 128 + (int(n / 4096) % 64), 128 + (int(n / 64) % 64), 128 + (n % 64))
}

function hex_value(s, i, c, p, n) {
    n = 0
    for (i = 1; i <= length(s); i++) {
        c = substr(s, i, 1); p = index("0123456789abcdefABCDEF", c)
        if (p == 0) return -1
        if (p <= 10) n = n * 16 + p - 1
        else if (p <= 16) n = n * 16 + p - 1 - 10 + 10
        else n = n * 16 + p - 1 - 16 + 10
    }
    return n
}

function utf8_sanitize(value, out, i, c, byte, need, first_min, first_max, sequence_end, j, next_byte, valid) {
    out = ""
    i = 1
    while (i <= length(value)) {
        c = substr(value, i, 1)
        if (c in UTF8_BYTE) byte = UTF8_BYTE[c]; else byte = -1
        need = 0
        first_min = 128
        first_max = 191
        if (byte < 128) { out = out c; i++; continue }
        if (byte >= 194 && byte <= 223) need = 1
        else if (byte >= 224 && byte <= 239) {
            need = 2
            if (byte == 224) first_min = 160
            if (byte == 237) first_max = 159
        } else if (byte >= 240 && byte <= 244) {
            need = 3
            if (byte == 240) first_min = 144
            if (byte == 244) first_max = 143
        } else { out = out "\357\277\275"; i++; continue }
        sequence_end = i + need; valid = 1
        for (j = i + 1; j <= sequence_end; j++) {
            c = substr(value, j, 1)
            if (c in UTF8_BYTE) next_byte = UTF8_BYTE[c]; else next_byte = -1
            if (next_byte < first_min || next_byte > first_max) { valid = 0; break }
            first_min = 128; first_max = 191
        }
        if (valid) { out = out substr(value, i, need + 1); i = sequence_end + 1 }
        else { out = out "\357\277\275"; i++ }
    }
    return out
}

function json_escape(s, i, c, out) {
    s = utf8_sanitize(s)
    out = "\""
    for (i = 1; i <= length(s); i++) {
        c = substr(s, i, 1)
        if (c == "\\") out = out "\\\\"
        else if (c == "\"") out = out "\\\""
        else if (c == "\n") out = out "\\n"
        else if (c == "\r") out = out "\\r"
        else if (c == "\t") out = out "\\t"
        else if (c == "\b") out = out "\\b"
        else if (c == "\f") out = out "\\f"
        else out = out c
    }
    return out "\""
}

function utf8_safe_prefix(value, limit, out, i, c, byte, need, start, first_min, first_max) {
    out = substr(value, 1, limit)
    need = 0
    start = 1
    first_min = 128
    first_max = 191
    for (i = 1; i <= length(out); i++) {
        c = substr(out, i, 1)
        if (c in UTF8_BYTE) byte = UTF8_BYTE[c]; else byte = -1
        if (need == 0) {
            start = i
            if (byte < 128) continue
            if (byte >= 194 && byte <= 223) { need = 1; first_min = 128; first_max = 191; continue }
            if (byte >= 224 && byte <= 239) {
                need = 2; first_min = 128; first_max = 191
                if (byte == 224) first_min = 160
                if (byte == 237) first_max = 159
                continue
            }
            if (byte >= 240 && byte <= 244) {
                need = 3; first_min = 128; first_max = 191
                if (byte == 240) first_min = 144
                if (byte == 244) first_max = 143
                continue
            }
            return substr(out, 1, i - 1)
        }
        if (byte < first_min || byte > first_max) return substr(out, 1, start - 1)
        need--
        first_min = 128
        first_max = 191
    }
    if (need != 0) return substr(out, 1, start - 1)
    return out
}

function json_skip_ws(s) { while (JSON_POS <= length(s) && substr(s, JSON_POS, 1) ~ /[[:space:]]/) JSON_POS++ }

function json_parse_string(s, c, hex, i) {
    if (substr(s, JSON_POS, 1) != "\"") { JSON_OK = 0; return }
    JSON_POS++
    while (JSON_POS <= length(s)) {
        c = substr(s, JSON_POS, 1)
        if (c == "\"") { JSON_POS++; return }
        if (c ~ /[[:cntrl:]]/) { JSON_OK = 0; return }
        if (c == "\\") {
            JSON_POS++; c = substr(s, JSON_POS, 1)
            if (c == "u") {
                hex = substr(s, JSON_POS + 1, 4)
                if (length(hex) != 4 || hex !~ /^[0-9a-fA-F]{4}$/) { JSON_OK = 0; return }
                JSON_POS += 5
            } else if (c == "\"" || c == "\\" || c == "/" || c == "b" || c == "f" || c == "n" || c == "r" || c == "t") JSON_POS++
            else { JSON_OK = 0; return }
        } else JSON_POS++
    }
    JSON_OK = 0
}

function json_parse_number(s, fragment) {
    fragment = substr(s, JSON_POS)
    if (match(fragment, /^-?(0|[1-9][0-9]*)(\.[0-9]+)?([eE][+-]?[0-9]+)?/) != 1) { JSON_OK = 0; return }
    JSON_POS += RLENGTH
}

function json_parse_array(s, c) {
    JSON_POS++; json_skip_ws(s)
    if (substr(s, JSON_POS, 1) == "]") { JSON_POS++; return }
    while (JSON_OK) {
        json_parse_value(s); if (!JSON_OK) return
        json_skip_ws(s); c = substr(s, JSON_POS, 1)
        if (c == "]") { JSON_POS++; return }
        if (c != ",") { JSON_OK = 0; return }
        JSON_POS++; json_skip_ws(s)
    }
}

function json_parse_object(s, c, key_start, key_end, key, depth, marker) {
    JSON_OBJECT_DEPTH++; depth = JSON_OBJECT_DEPTH
    for (marker in json_object_keys) if (substr(marker, 1, length(depth) + 1) == depth SUBSEP) delete json_object_keys[marker]
    JSON_POS++; json_skip_ws(s)
    if (substr(s, JSON_POS, 1) == "}") { JSON_POS++; JSON_OBJECT_DEPTH--; return }
    while (JSON_OK) {
        key_start = JSON_POS; json_parse_string(s); if (!JSON_OK) { JSON_OBJECT_DEPTH--; return }
        key_end = JSON_POS; key = json_decode(substr(s, key_start, key_end - key_start)); marker = depth SUBSEP key
        if (marker in json_object_keys) { JSON_OK = 0; JSON_OBJECT_DEPTH--; return }
        json_object_keys[marker] = 1
        json_skip_ws(s); if (substr(s, JSON_POS, 1) != ":") { JSON_OK = 0; JSON_OBJECT_DEPTH--; return }
        JSON_POS++; json_parse_value(s); if (!JSON_OK) { JSON_OBJECT_DEPTH--; return }
        json_skip_ws(s); c = substr(s, JSON_POS, 1)
        if (c == "}") { JSON_POS++; JSON_OBJECT_DEPTH--; return }
        if (c != ",") { JSON_OK = 0; JSON_OBJECT_DEPTH--; return }
        JSON_POS++; json_skip_ws(s)
    }
    JSON_OBJECT_DEPTH--
}

function json_parse_value(s, c) {
    json_skip_ws(s); c = substr(s, JSON_POS, 1)
    if (c == "\"") json_parse_string(s)
    else if (c == "{") json_parse_object(s)
    else if (c == "[") json_parse_array(s)
    else if (c == "-" || c ~ /^[0-9]$/) json_parse_number(s)
    else if (substr(s, JSON_POS, 4) == "true") JSON_POS += 4
    else if (substr(s, JSON_POS, 5) == "false") JSON_POS += 5
    else if (substr(s, JSON_POS, 4) == "null") JSON_POS += 4
    else JSON_OK = 0
}

function valid_json(s) {
    if (s == "") return 0
    for (JSON_KEY in json_object_keys) delete json_object_keys[JSON_KEY]
    JSON_OBJECT_DEPTH = 0; JSON_POS = 1; JSON_OK = 1; json_parse_value(s); json_skip_ws(s)
    return JSON_OK && JSON_POS > length(s)
}

function valid_rpc_id(raw) {
    if (raw == "null") return 1
    if (substr(raw, 1, 1) == "\"") return valid_json(raw)
    if (raw !~ /^-?(0|[1-9][0-9]*)(\.[0-9]+)?([eE][+-]?[0-9]+)?$/) return 0
    return valid_json(raw)
}

function raw_kind(raw, i, c) {
    i = ws(raw, 1); c = substr(raw, i, 1)
    if (c == "{") return "object"
    if (c == "[") return "array"
    if (c == "\"") return "string"
    if (c == "-" || c ~ /^[0-9]$/) return "number"
    return "value"
}

function bounded_raw(raw) {
    if (length(raw) <= MAX_CONTEXT_TEXT) return utf8_sanitize(raw)
    return "{\"kind\":" json_escape(raw_kind(raw)) ",\"bytes\":" length(raw) ",\"truncated\":true}"
}

function bounded_json_string(value) { return json_escape(utf8_safe_prefix(value, MAX_CONTEXT_TEXT)) }

function bounded_text(value) {
    gsub(/[[:space:]]+/, " ", value)
    return utf8_safe_prefix(value, MAX_CONTEXT_TEXT)
}

function bounded_text_field(name, value, out) {
    out = json_escape(name) ":" bounded_json_string(value)
    if (length(value) > MAX_CONTEXT_TEXT) out = out "," json_escape(name "_truncated") ":true"
    return out
}

function bounded_raw_field(name, value, out) {
    out = json_escape(name) ":" bounded_raw(value)
    if (length(value) > MAX_CONTEXT_TEXT) out = out "," json_escape(name "_truncated") ":true"
    return out
}

function bounded_string_array(raw, i, start, e, count, item, value, list) {
    ARRAY_COUNT = 0; ARRAY_TRUNCATED = 0; list = "["
    if (substr(raw, 1, 1) != "[" || !valid_json(raw)) return list "]"
    i = ws(raw, 2)
    while (i <= length(raw) && substr(raw, i, 1) != "]") {
        start = ws(raw, i); e = value_end(raw, start)
        if (e < start) break
        ARRAY_COUNT++
        if (ARRAY_COUNT <= MAX_CONTEXT_ITEMS) {
            item = substr(raw, start, e - start + 1)
            if (substr(item, 1, 1) == "\"") {
                value = json_decode(item)
                if (length(value) > MAX_CONTEXT_TEXT) value = utf8_safe_prefix(value, MAX_CONTEXT_TEXT)
                item = json_escape(value)
            } else item = bounded_raw(item)
            if (ARRAY_COUNT > 1) list = list ","
            list = list item
        }
        i = ws(raw, e + 1)
        if (substr(raw, i, 1) == ",") i = ws(raw, i + 1)
        else break
    }
    if (ARRAY_COUNT > MAX_CONTEXT_ITEMS) ARRAY_TRUNCATED = 1
    return list "]"
}
