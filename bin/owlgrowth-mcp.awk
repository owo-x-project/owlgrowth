# OwlGrowth's only product boundary is MCP over stdio.
# This file intentionally uses only POSIX awk.

BEGIN {
    exp_file = data_dir "/experiences.jsonl"
    adapt_file = data_dir "/adaptations.jsonl"
    sequence = 0
    MAX_CONTEXT_ITEMS = 20
    MAX_CONTEXT_TEXT = 512
    MAX_IDENTIFIER_TEXT = 256
    MAX_REQUEST_TEXT = 65536
    MAX_RESPONSE_TEXT = 32768
    REQUEST_NOTIFICATION = 0
    SHUTDOWN_REQUESTED = 0
    for (byte_index = 0; byte_index <= 255; byte_index++) UTF8_BYTE[sprintf("%c", byte_index)] = byte_index
    load_experiences()
    load_adaptations()
}

{
    if ($0 !~ /^[[:space:]]*$/) handle_request($0)
}

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

function load_experiences(line, id) {
    while ((getline line < exp_file) > 0) {
        if (valid_json(line) && persisted_experience(line)) {
            object_get(line, "id")
            id = GET_STRING
            if (id in exp_json) continue
            exp_json[id] = line
            object_get(line, "project"); exp_project[id] = GET_STRING
            object_get(line, "task"); exp_task[id] = GET_STRING
            object_get(line, "action"); exp_action[id] = GET_STRING
            object_get(line, "outcome"); exp_outcome[id] = GET_RAW
            object_get(line, "evidence"); exp_evidence[id] = GET_RAW
            object_get(line, "occurred_at"); exp_occurred[id] = GET_STRING
            exp_search[id] = tolower(exp_project[id] " " exp_task[id] " " exp_action[id] " " exp_outcome[id] " " exp_evidence[id])
            sequence++
        }
    }
    close(exp_file)
}

function load_adaptations(line, id) {
    while ((getline line < adapt_file) > 0) {
        if (valid_json(line) && persisted_adaptation(line)) {
            object_get(line, "id")
            id = GET_STRING
            if ((id in adapt_status) && adapt_status[id] == "retired") continue
            adapt_json[id] = line
            object_get(line, "guidance"); adapt_guidance[id] = GET_STRING
            object_get(line, "scope"); adapt_scope[id] = GET_RAW
            object_get(line, "evidence"); adapt_evidence[id] = GET_RAW
            object_get(line, "status"); adapt_status[id] = GET_STRING
            object_get(line, "source_experience_ids"); adapt_sources[id] = GET_RAW
            adapt_search[id] = tolower(adapt_guidance[id] " " adapt_scope[id]); sequence++
        }
    }
    close(adapt_file)
}

function generated_id_in_use(prefix, candidate) {
    if (prefix == "exp") return candidate in exp_json
    if (prefix == "adapt") return candidate in adapt_json
    return 0
}

function next_id(prefix, candidate) {
    do { sequence++; candidate = prefix "-" systime() "-" sequence } while (generated_id_in_use(prefix, candidate))
    return candidate
}
function append_record(file, record) { print record >> file; close(file) }
function fail(message) { TOOL_ERROR = message; return 0 }

function required_string(obj, name, label) {
    object_get(obj, name)
    if (!GET_PRESENT || substr(GET_RAW, 1, 1) != "\"") return fail(label " requires string argument '" name "'")
    return 1
}

function required_nonempty_string(obj, name, label) {
    if (!required_string(obj, name, label)) return 0
    if (GET_STRING ~ /^[[:space:]]*$/) return fail(label " requires a non-empty string argument '" name "'")
    return 1
}

function valid_identifier(value, label) {
    if (value == "" || value ~ /^[[:space:]]*$/) return fail(label " requires a non-empty identifier")
    if (length(value) > MAX_IDENTIFIER_TEXT) return fail(label " identifier exceeds " MAX_IDENTIFIER_TEXT " characters")
    return 1
}

function optional_string(obj, name, default_value, label) {
    object_get(obj, name)
    if (GET_PRESENT && substr(GET_RAW, 1, 1) != "\"") { fail(label " requires string argument '" name "'"); return default_value }
    if (GET_PRESENT) return GET_STRING
    return default_value
}

function optional_nonempty_string(obj, name, default_value, label) {
    object_get(obj, name)
    if (!GET_PRESENT) return default_value
    if (substr(GET_RAW, 1, 1) != "\"" || GET_STRING ~ /^[[:space:]]*$/) { fail(label " requires a non-empty string argument '" name "'"); return default_value }
    return GET_STRING
}

function bounded_limit(obj, name, default_value, raw, value) {
    object_get(obj, name)
    value = default_value
    if (GET_PRESENT && GET_RAW !~ /^[0-9]+$/) { fail("requires a positive integer argument '" name "'"); return default_value }
    if (GET_PRESENT) value = GET_RAW + 0
    if (GET_PRESENT && value < 1) { fail("requires a positive integer argument '" name "'"); return default_value }
    if (value < 1) value = 1
    if (value > MAX_CONTEXT_ITEMS) value = MAX_CONTEXT_ITEMS
    return value
}

function required_raw(obj, name, label) {
    object_get(obj, name)
    if (!GET_PRESENT || GET_RAW == "null") return fail(label " requires argument '" name "'")
    return GET_RAW
}

function meaningful_raw(raw, i, first) {
    if (raw == "" || raw == "null") return 0
    first = substr(raw, 1, 1)
    if (first == "\"") return json_decode(raw) !~ /^[[:space:]]*$/
    if (first == "{") { i = ws(raw, 2); return substr(raw, i, 1) != "}" }
    if (first == "[") { i = ws(raw, 2); return substr(raw, i, 1) != "]" }
    return 1
}

function persisted_string(obj, name, nonempty) {
    object_get(obj, name)
    return GET_PRESENT && substr(GET_RAW, 1, 1) == "\"" && (!nonempty || GET_STRING !~ /^[[:space:]]*$/)
}

function persisted_optional_string(obj, name) {
    object_get(obj, name)
    return !GET_PRESENT || substr(GET_RAW, 1, 1) == "\""
}

function persisted_kind(obj, expected) {
    object_get(obj, "kind")
    return GET_PRESENT && GET_RAW == json_escape(expected)
}

function persisted_json_field(obj, name, first, raw) {
    object_get(obj, name); raw = (GET_PRESENT ? GET_RAW : "")
    return raw != "" && valid_json(raw) && (first == "" || substr(raw, 1, 1) == first)
}

function persisted_identifier(obj, name) { object_get(obj, name); return GET_PRESENT && substr(GET_RAW, 1, 1) == "\"" && GET_STRING !~ /^[[:space:]]*$/ && length(GET_STRING) <= MAX_IDENTIFIER_TEXT }

function persisted_scope_shape(raw, i, e, k_end, key, start) {
    if (substr(raw, 1, 1) != "{" || !valid_json(raw)) return 0
    i = ws(raw, 2)
    while (i <= length(raw) && substr(raw, i, 1) != "}") {
        if (substr(raw, i, 1) != "\"") return 0
        k_end = string_end(raw, i); if (k_end < 0) return 0
        key = json_decode(substr(raw, i, k_end - i + 1))
        if (key != "project" && key != "task" && key != "ecosystem") return 0
        start = ws(raw, k_end + 1); if (substr(raw, start, 1) != ":") return 0
        e = value_end(raw, ws(raw, start + 1)); if (e < start) return 0
        i = ws(raw, e + 1)
        if (substr(raw, i, 1) == ",") i = ws(raw, i + 1)
        else if (substr(raw, i, 1) != "}") return 0
    }
    return substr(raw, i, 1) == "}"
}

function persisted_scope(raw, field) {
    if (!persisted_scope_shape(raw)) return 0
    for (field in persisted_scope_fields) delete persisted_scope_fields[field]
    object_get(raw, "project"); if (GET_PRESENT) { if (substr(GET_RAW, 1, 1) != "\"" || GET_STRING ~ /^[[:space:]]*$/) return 0; persisted_scope_fields["project"] = 1 }
    object_get(raw, "task"); if (GET_PRESENT) { if (substr(GET_RAW, 1, 1) != "\"" || GET_STRING ~ /^[[:space:]]*$/) return 0; persisted_scope_fields["task"] = 1 }
    object_get(raw, "ecosystem"); if (GET_PRESENT) { if (substr(GET_RAW, 1, 1) != "\"" || GET_STRING ~ /^[[:space:]]*$/) return 0; persisted_scope_fields["ecosystem"] = 1 }
    return 1
}

function persisted_experience_ids(raw, i, start, e, item) {
    if (substr(raw, 1, 1) != "[" || !valid_json(raw)) return 0
    for (item in persisted_experience_id_seen) delete persisted_experience_id_seen[item]
    i = ws(raw, 2)
    if (substr(raw, i, 1) == "]") return 0
    while (i <= length(raw)) {
        start = ws(raw, i); e = value_end(raw, start)
        if (e < start || substr(raw, start, 1) != "\"") return 0
        item = json_decode(substr(raw, start, e - start + 1))
        if (item == "" || length(item) > MAX_IDENTIFIER_TEXT || !(item in exp_json) || (item in persisted_experience_id_seen)) return 0
        persisted_experience_id_seen[item] = 1
        i = ws(raw, e + 1)
        if (substr(raw, i, 1) == ",") i = ws(raw, i + 1)
        else if (substr(raw, i, 1) == "]") return 1
        else return 0
    }
    return 0
}

function persisted_observation(item) {
    object_get(item, "project"); if (!GET_PRESENT || substr(GET_RAW, 1, 1) != "\"" || GET_STRING ~ /^[[:space:]]*$/) return 0
    object_get(item, "result"); if (!GET_PRESENT || substr(GET_RAW, 1, 1) != "\"" || GET_STRING ~ /^[[:space:]]*$/) return 0
    object_get(item, "evidence"); if (!GET_PRESENT || !valid_json(GET_RAW) || !meaningful_raw(GET_RAW)) return 0
    object_get(item, "task"); if (GET_PRESENT && substr(GET_RAW, 1, 1) != "\"") return 0
    object_get(item, "ecosystem"); if (GET_PRESENT && substr(GET_RAW, 1, 1) != "\"") return 0
    object_get(item, "observed_at"); if (GET_PRESENT && substr(GET_RAW, 1, 1) != "\"") return 0
    return 1
}

function persisted_evidence(raw, i, start, e, item, success, failure, other, observations, observed_success, observed_failure, observed_other, result) {
    if (substr(raw, 1, 1) != "{" || !valid_json(raw)) return 0
    object_get(raw, "success"); if (!GET_PRESENT || GET_RAW !~ /^[0-9]+$/) return 0; success = GET_RAW + 0
    object_get(raw, "failure"); if (!GET_PRESENT || GET_RAW !~ /^[0-9]+$/) return 0; failure = GET_RAW + 0
    object_get(raw, "other"); if (!GET_PRESENT || GET_RAW !~ /^[0-9]+$/) return 0; other = GET_RAW + 0
    object_get(raw, "observations"); if (!GET_PRESENT || substr(GET_RAW, 1, 1) != "[" || !valid_json(GET_RAW)) return 0
    observations = GET_RAW; observed_success = 0; observed_failure = 0; observed_other = 0; i = ws(observations, 2)
    while (i <= length(observations) && substr(observations, i, 1) != "]") {
        start = ws(observations, i); e = value_end(observations, start)
        if (e < start || substr(observations, start, 1) != "{" || !valid_json(substr(observations, start, e - start + 1))) return 0
        item = substr(observations, start, e - start + 1)
        if (!persisted_observation(item)) return 0
        object_get(item, "result"); result = tolower(GET_STRING)
        if (result == "success" || result == "pass" || result == "passed") observed_success++
        else if (result == "failure" || result == "fail" || result == "failed") observed_failure++
        else observed_other++
        i = ws(observations, e + 1)
        if (substr(observations, i, 1) == ",") i = ws(observations, i + 1)
        else if (substr(observations, i, 1) != "]") return 0
    }
    return substr(observations, i, 1) == "]" && observed_success == success && observed_failure == failure && observed_other == other
}

function persisted_experience(obj) {
    return persisted_kind(obj, "experience") && persisted_identifier(obj, "id") && persisted_string(obj, "project", 1) && persisted_string(obj, "task", 1) && persisted_string(obj, "action", 1) && persisted_json_field(obj, "outcome", "") && meaningful_raw(GET_RAW) && persisted_json_field(obj, "evidence", "") && meaningful_raw(GET_RAW) && persisted_optional_string(obj, "occurred_at")
}

function persisted_adaptation(obj, scope, sources, evidence, status) {
    if (!(persisted_kind(obj, "adaptation") && persisted_identifier(obj, "id") && persisted_string(obj, "guidance", 1))) return 0
    object_get(obj, "scope"); if (!GET_PRESENT || !persisted_scope(GET_RAW)) return 0; scope = GET_RAW
    object_get(obj, "source_experience_ids"); if (!GET_PRESENT || !persisted_experience_ids(GET_RAW)) return 0; sources = GET_RAW
    object_get(obj, "evidence"); if (!GET_PRESENT || !persisted_evidence(GET_RAW)) return 0; evidence = GET_RAW
    object_get(obj, "status"); if (!GET_PRESENT || substr(GET_RAW, 1, 1) != "\"") return 0; status = GET_STRING
    return status == "active" || status == "retired"
}

function array_item_count(raw, i, start, e, count) {
    count = 0; i = ws(raw, 2)
    if (substr(raw, i, 1) == "]") return 0
    while (i <= length(raw)) {
        start = ws(raw, i); e = value_end(raw, start)
        if (e < start) return count
        count++; i = ws(raw, e + 1)
        if (substr(raw, i, 1) == ",") i = ws(raw, i + 1)
        else break
    }
    return count
}

function observation_count(raw, observations) {
    object_get(raw, "observations")
    if (!GET_PRESENT || substr(GET_RAW, 1, 1) != "[") return 0
    return array_item_count(GET_RAW)
}

function evidence_summary(raw, success, failure, other, observations) {
    success = count_evidence(raw, "success"); failure = count_evidence(raw, "failure"); other = count_evidence(raw, "other"); observations = observation_count(raw)
    return "{\"success\":" success ",\"failure\":" failure ",\"other\":" other ",\"observation_count\":" observations "}"
}

function recent_observations(raw, limit, i, start, e, count, item, first, list) {
    object_get(raw, "observations")
    if (!GET_PRESENT || substr(GET_RAW, 1, 1) != "[") return "{\"items\":[],\"truncated\":false}"
    raw = GET_RAW; limit = 5; count = 0
    for (item in recent_items) delete recent_items[item]
    i = ws(raw, 2)
    while (i <= length(raw) && substr(raw, i, 1) != "]") {
        start = ws(raw, i); e = value_end(raw, start)
        if (e < start) break
        recent_items[++count] = substr(raw, start, e - start + 1)
        i = ws(raw, e + 1)
        if (substr(raw, i, 1) == ",") i = ws(raw, i + 1)
        else break
    }
    first = count - limit + 1; if (first < 1) first = 1
    list = "["
    for (i = first; i <= count; i++) { if (i > first) list = list ","; list = list observation_summary(recent_items[i]) }
    return "{\"items\":" list "],\"truncated\":" (count > limit ? "true" : "false") "}"
}

function adaptation_summary(id, source_ids, source_count, source_truncated, out) {
    source_ids = bounded_string_array(adapt_sources[id]); source_count = ARRAY_COUNT; source_truncated = ARRAY_TRUNCATED
    out = "{\"id\":" json_escape(id) ",\"kind\":\"adaptation\"," bounded_text_field("guidance", adapt_guidance[id]) ",\"scope\":" bounded_raw(adapt_scope[id]) (length(adapt_scope[id]) > MAX_CONTEXT_TEXT ? ",\"scope_truncated\":true" : "") ",\"source_experience_ids\":" source_ids ",\"source_experience_count\":" source_count
    if (source_truncated) out = out ",\"source_experience_ids_truncated\":true"
    return out ",\"evidence\":" evidence_summary(adapt_evidence[id]) ",\"status\":" json_escape(adapt_status[id]) "}"
}

function experience_summary(id, out) {
    out = "{\"id\":" json_escape(id) ",\"kind\":\"experience\"," bounded_text_field("project", exp_project[id]) "," bounded_text_field("task", exp_task[id]) "," bounded_text_field("action", exp_action[id]) "," bounded_raw_field("outcome", exp_outcome[id]) "," bounded_raw_field("evidence", exp_evidence[id])
    if (exp_occurred[id] != "") out = out "," bounded_text_field("occurred_at", exp_occurred[id])
    return out "}"
}

function observation_summary(raw, out) {
    out = "{"
    object_get(raw, "project"); if (GET_PRESENT) out = out bounded_text_field("project", GET_STRING)
    object_get(raw, "result"); if (GET_PRESENT) out = out "," bounded_text_field("result", GET_STRING)
    object_get(raw, "evidence"); if (GET_PRESENT) out = out "," bounded_raw_field("evidence", GET_RAW)
    object_get(raw, "task"); if (GET_PRESENT) out = out "," bounded_text_field("task", GET_STRING)
    object_get(raw, "ecosystem"); if (GET_PRESENT) out = out "," bounded_text_field("ecosystem", GET_STRING)
    object_get(raw, "observed_at"); if (GET_PRESENT) out = out "," bounded_text_field("observed_at", GET_STRING)
    return out "}"
}

function required_meaningful_raw(obj, name, label) {
    object_get(obj, name)
    if (!GET_PRESENT || !meaningful_raw(GET_RAW)) return fail(label " requires non-empty argument '" name "'")
    if (!valid_json(GET_RAW)) return fail(label " requires valid JSON argument '" name "'")
    return GET_RAW
}

function required_object(obj, name, label) {
    object_get(obj, name)
    if (!GET_PRESENT || substr(GET_RAW, 1, 1) != "{" || !valid_json(GET_RAW)) return fail(label " requires a valid object argument '" name "'")
    return GET_RAW
}

function valid_scope(raw, label, i, k_end, key, start, e) {
    if (substr(raw, 1, 1) != "{" || !valid_json(raw)) return fail(label " requires a valid object argument 'scope'")
    i = ws(raw, 2)
    while (i <= length(raw) && substr(raw, i, 1) != "}") {
        if (substr(raw, i, 1) != "\"") return fail(label " scope must be an object")
        k_end = string_end(raw, i); if (k_end < 0) return fail(label " requires a valid object argument 'scope'")
        key = json_decode(substr(raw, i, k_end - i + 1))
        if (key != "project" && key != "task" && key != "ecosystem") return fail(label " scope contains unknown field '" key "'")
        start = ws(raw, k_end + 1); if (substr(raw, start, 1) != ":") return fail(label " requires a valid object argument 'scope'")
        e = value_end(raw, ws(raw, start + 1)); if (e < start) return fail(label " requires a valid object argument 'scope'")
        if (substr(raw, ws(raw, start + 1), 1) != "\"") return fail(label " scope field '" key "' must be a non-empty string")
        object_get(raw, key)
        if (GET_STRING ~ /^[[:space:]]*$/) return fail(label " scope field '" key "' must be a non-empty string")
        i = ws(raw, e + 1)
        if (substr(raw, i, 1) == ",") i = ws(raw, i + 1)
        else if (substr(raw, i, 1) != "}") return fail(label " requires a valid object argument 'scope'")
    }
    if (substr(raw, i, 1) != "}") return fail(label " requires a valid object argument 'scope'")
    return 1
}

function validate_experience_ids(raw, label, i, start, e, item) {
    if (substr(raw, 1, 1) != "[" || !valid_json(raw)) return fail(label " must be a valid JSON array")
    for (item in validated_experience_ids) delete validated_experience_ids[item]
    i = ws(raw, 2)
    if (substr(raw, i, 1) == "]") return fail(label " requires at least one experience id")
    while (i <= length(raw)) {
        start = ws(raw, i); e = value_end(raw, start)
        if (e < start || substr(raw, start, 1) != "\"") return fail(label " must contain experience id strings")
        item = json_decode(substr(raw, start, e - start + 1))
        if (item == "" || !(item in exp_json)) return fail(label " references unknown experience: " item)
        if (item in validated_experience_ids) return fail(label " contains duplicate experience id: " item)
        validated_experience_ids[item] = 1
        i = ws(raw, e + 1)
        if (substr(raw, i, 1) == ",") i = ws(raw, i + 1)
        else if (substr(raw, i, 1) == "]") return 1
        else return fail(label " must be an array")
    }
    return fail(label " must be an array")
}

function handle_request(line, method, id_present, params) {
    REQUEST_NOTIFICATION = (line !~ /"id"[[:space:]]*:/)
    if (length(line) > MAX_REQUEST_TEXT) { ID_RAW = "null"; rpc_error(-32600, "request exceeds " MAX_REQUEST_TEXT " characters"); return }
    if (!valid_json(line)) { ID_RAW = "null"; rpc_error(-32700, "parse error"); return }
    object_get(line, "id"); REQUEST_NOTIFICATION = !GET_PRESENT
    object_get(line, "jsonrpc")
    if (!GET_PRESENT || GET_RAW != "\"2.0\"") { ID_RAW = "null"; rpc_error(-32600, "request requires jsonrpc 2.0"); return }
    ID_RAW = "null"; object_get(line, "id"); id_present = GET_PRESENT
    if (id_present) {
        ID_RAW = GET_RAW
        if (!valid_rpc_id(ID_RAW)) { ID_RAW = "null"; rpc_error(-32600, "request id must be a string, number, or null"); return }
    }
    REQUEST_NOTIFICATION = !id_present
    object_get(line, "method")
    if (!GET_PRESENT || substr(GET_RAW, 1, 1) != "\"") { if (id_present) rpc_error(-32600, "request requires string method"); return }
    method = GET_STRING
    object_get(line, "params")
    if (GET_PRESENT && substr(GET_RAW, 1, 1) != "{" && substr(GET_RAW, 1, 1) != "[") { if (id_present) rpc_error(-32600, "request params must be an object or array"); return }
    if (method == "notifications/initialized" || method == "notifications/cancelled") return
    if (method == "exit") exit 0
    if (SHUTDOWN_REQUESTED) { if (id_present) rpc_error(-32600, "server is shutting down"); return }
    if (method == "initialize") { rpc_result("{\"protocolVersion\":\"2024-11-05\",\"capabilities\":{\"tools\":{},\"resources\":{\"subscribe\":false,\"listChanged\":false}},\"serverInfo\":{\"name\":\"owlgrowth\",\"version\":\"0.1.0\"}}"); return }
    if (method == "ping") { rpc_result("{}"); return }
    if (method == "tools/list") { rpc_result(tools_json()); return }
    if (method == "resources/list") { rpc_result(resources_json()); return }
    if (method == "resources/read") { object_get(line, "params"); params = (GET_PRESENT ? GET_RAW : "{}"); resource_read(params); return }
    if (method == "tools/call") { object_get(line, "params"); params = (GET_PRESENT ? GET_RAW : "{}"); tool_call(params); return }
    if (method == "shutdown") { SHUTDOWN_REQUESTED = 1; rpc_result("null"); return }
    if (id_present) rpc_error(-32601, "method not found: " method)
}

function rpc_result(result) { if (REQUEST_NOTIFICATION) return; print "{\"jsonrpc\":\"2.0\",\"id\":" ID_RAW ",\"result\":" result "}"; fflush() }
function rpc_error(code, message) { if (REQUEST_NOTIFICATION) return; print "{\"jsonrpc\":\"2.0\",\"id\":" ID_RAW ",\"error\":{\"code\":" code ",\"message\":" json_escape(message) "}}"; fflush() }
function tool_text(message, is_error) {
    if (REQUEST_NOTIFICATION) return
    if (length(message) > MAX_RESPONSE_TEXT) message = "{\"truncated\":true,\"bytes\":" length(message) "}"
    print "{\"jsonrpc\":\"2.0\",\"id\":" ID_RAW ",\"result\":{\"content\":[{\"type\":\"text\",\"text\":" json_escape(message) "}]" (is_error ? ",\"isError\":true" : "") "}}"
    fflush()
}

function tools_json() {
    return "{\"tools\":[" \
      "{\"name\":\"discover\",\"description\":\"Explain when to use OwlGrowth and route the small public surface. Read-only.\",\"inputSchema\":{\"type\":\"object\",\"properties\":{}}}," \
      "{\"name\":\"find_experiences\",\"description\":\"Find observed task/action/outcome records. Never turns an interpretation into an experience. Results are hard-capped at 20.\",\"inputSchema\":{\"type\":\"object\",\"properties\":{\"query\":{\"type\":\"string\"},\"project\":{\"type\":\"string\"},\"limit\":{\"type\":\"integer\",\"minimum\":1,\"maximum\":20}}}}," \
      "{\"name\":\"record_experience\",\"description\":\"Append one observed Task/Action/Outcome/Evidence event. Evidence is required.\",\"inputSchema\":{\"type\":\"object\",\"required\":[\"task\",\"action\",\"outcome\",\"evidence\"],\"properties\":{\"task\":{\"type\":\"string\"},\"action\":{\"type\":\"string\"},\"outcome\":{},\"evidence\":{},\"project\":{\"type\":\"string\"},\"occurred_at\":{\"type\":\"string\"},\"experience_id\":{\"type\":\"string\"}}}}," \
      "{\"name\":\"record_adaptation\",\"description\":\"Record scoped action guidance separately from experiences; at least one existing experience must support it.\",\"inputSchema\":{\"type\":\"object\",\"required\":[\"guidance\",\"scope\",\"source_experience_ids\"],\"properties\":{\"guidance\":{\"type\":\"string\"},\"scope\":{},\"source_experience_ids\":{\"type\":\"array\",\"minItems\":1},\"adaptation_id\":{\"type\":\"string\"}}}}," \
      "{\"name\":\"revise_adaptation\",\"description\":\"Revise guidance or narrow its scope while preserving its observed evidence and history.\",\"inputSchema\":{\"type\":\"object\",\"required\":[\"adaptation_id\",\"guidance\",\"scope\",\"reason\"],\"properties\":{\"adaptation_id\":{\"type\":\"string\"},\"guidance\":{\"type\":\"string\"},\"scope\":{},\"reason\":{\"type\":\"string\"},\"source_experience_ids\":{\"type\":\"array\"}}}}," \
      "{\"name\":\"observe_adaptation\",\"description\":\"Evaluate guidance with an externally observable outcome and append the observation.\",\"inputSchema\":{\"type\":\"object\",\"required\":[\"adaptation_id\",\"result\",\"evidence\"],\"properties\":{\"adaptation_id\":{\"type\":\"string\"},\"result\":{\"type\":\"string\"},\"evidence\":{},\"project\":{\"type\":\"string\"},\"task\":{\"type\":\"string\"},\"ecosystem\":{\"type\":\"string\"},\"observed_at\":{\"type\":\"string\"}}}}," \
      "{\"name\":\"recommend_action\",\"description\":\"Return up to a bounded number of active scoped adaptations that may improve the next action. Results are hard-capped at 20 and include evidence counts, not full history.\",\"inputSchema\":{\"type\":\"object\",\"properties\":{\"task\":{\"type\":\"string\"},\"scope\":{},\"project\":{\"type\":\"string\"},\"limit\":{\"type\":\"integer\",\"minimum\":1,\"maximum\":20}}}}," \
      "{\"name\":\"review_adaptation\",\"description\":\"Summarize external evidence, show up to five recent observations, and recommend strengthen, refine/narrow, or gather-more.\",\"inputSchema\":{\"type\":\"object\",\"required\":[\"adaptation_id\"],\"properties\":{\"adaptation_id\":{\"type\":\"string\"}}}}," \
      "{\"name\":\"retire_adaptation\",\"description\":\"Stop recommending an adaptation while preserving its history.\",\"inputSchema\":{\"type\":\"object\",\"required\":[\"adaptation_id\"],\"properties\":{\"adaptation_id\":{\"type\":\"string\"}}}}]}"
}

function resources_json() { return "{\"resources\":[{\"uri\":\"owlgrowth://guidance\",\"name\":\"Current action guidance\",\"description\":\"Active scoped adaptations with observed evidence.\",\"mimeType\":\"text/plain\"}]}" }

function resource_read(params, uri) {
    object_get(params, "uri")
    if (!GET_PRESENT || substr(GET_RAW, 1, 1) != "\"") { rpc_error(-32602, "resources/read requires uri"); return }
    uri = GET_STRING
    if (uri != "owlgrowth://guidance") { rpc_error(-32001, "unknown resource: " uri); return }
    rpc_result("{\"contents\":[{\"uri\":\"owlgrowth://guidance\",\"mimeType\":\"text/plain\",\"text\":" json_escape(guidance_text()) "}]}")
}

function next_active_adaptation(used, best, id) {
    best = ""
    for (id in adapt_json) if (adapt_status[id] == "active" && !(id in used) && (best == "" || id < best)) best = id
    return best
}

function adaptation_matches(id, task, project, scope_raw) {
    if (adapt_status[id] != "active") return 0
    if (task != "" && index(adapt_search[id], tolower(task)) == 0) return 0
    return match_scope(adapt_scope[id], scope_raw, task, project)
}

function next_matching_adaptation(used, task, project, scope_raw, best, id) {
    best = ""
    for (id in adapt_json) if (!(id in used) && adaptation_matches(id, task, project, scope_raw) && (best == "" || id < best)) best = id
    return best
}

function next_experience(used, query, project, best, id) {
    best = ""
    for (id in exp_json) if (!(id in used) && (project == "" || exp_project[id] == project) && (query == "" || index(exp_search[id], tolower(query)) > 0) && (best == "" || id < best)) best = id
    return best
}

function guidance_text(id, out) {
    out = "Use only guidance whose scope matches the current task. Use recommend_action for a targeted result.\n"
    guidance_count = 0; omitted_count = 0
    for (id in guidance_used) delete guidance_used[id]
    while ((id = next_active_adaptation(guidance_used)) != "") {
        guidance_used[id] = 1
        guidance_count++
        if (guidance_count <= MAX_CONTEXT_ITEMS) out = out "- [" id "] " bounded_text(adapt_guidance[id]) " | scope=" bounded_text(adapt_scope[id]) " | evidence=" evidence_summary(adapt_evidence[id]) "\n"
        else omitted_count++
    }
    if (guidance_count == 0) out = out "No active adaptation has been recorded."
    else if (omitted_count > 0) out = out "- ... " omitted_count " more adaptation(s) omitted; call recommend_action with task/project/scope.\n"
    return out
}

function tool_call(params, name, args) {
    object_get(params, "name")
    if (!GET_PRESENT || substr(GET_RAW, 1, 1) != "\"") { rpc_error(-32602, "tools/call requires name"); return }
    name = GET_STRING; object_get(params, "arguments"); args = (GET_PRESENT ? GET_RAW : "{}")
    if (substr(args, 1, 1) != "{") { rpc_error(-32602, "tool arguments must be an object"); return }
    TOOL_ERROR = ""
    if (name == "discover") discover()
    else if (name == "find_experiences") find_experiences(args)
    else if (name == "record_experience") record_experience(args)
    else if (name == "record_adaptation") record_adaptation(args)
    else if (name == "revise_adaptation") revise_adaptation(args)
    else if (name == "observe_adaptation") observe_adaptation(args)
    else if (name == "recommend_action") recommend_action(args)
    else if (name == "review_adaptation") review_adaptation(args)
    else if (name == "retire_adaptation") retire_adaptation(args)
    else { rpc_error(-32602, "unknown tool: " name); return }
    if (TOOL_ERROR != "") tool_text(TOOL_ERROR, 1)
}

function discover() {
    tool_text("OwlGrowth records how observed outcomes change future actions.\n\nRouting:\n- find_experiences: inspect project-scoped observed events.\n- record_experience: append Task, Action, Outcome, and external Evidence.\n- record_adaptation: separate reusable guidance with an explicit scope.\n- recommend_action: read matching active guidance before acting.\n- observe_adaptation: attach an externally observable result after acting.\n- review_adaptation: decide whether evidence strengthens, refines/narrows, or retires guidance.\n- revise_adaptation: apply a justified guidance or scope change while preserving evidence.\n- retire_adaptation: preserve history but stop recommending unsuitable guidance.\n\nDo not store specifications, decisions, or general project knowledge here. Experience is fact; Adaptation is a revisable action improvement. Self-assessment alone is not evidence.")
}

function record_experience(args, task, action, outcome, evidence, project, occurred, id, record) {
    if (!required_nonempty_string(args, "task", "record_experience")) return; task = GET_STRING
    if (!required_nonempty_string(args, "action", "record_experience")) return; action = GET_STRING
    outcome = required_meaningful_raw(args, "outcome", "record_experience"); if (!outcome) return
    evidence = required_meaningful_raw(args, "evidence", "record_experience"); if (!evidence) return
    project = optional_nonempty_string(args, "project", "current", "record_experience"); if (TOOL_ERROR != "") return
    occurred = optional_string(args, "occurred_at", "", "record_experience"); if (TOOL_ERROR != "") return
    id = optional_string(args, "experience_id", "", "record_experience"); if (TOOL_ERROR != "") return
    if (id != "" && !valid_identifier(id, "record_experience")) return
    if (id == "") id = next_id("exp")
    if (id in exp_json) { fail("experience already exists: " id); return }
    record = "{\"id\":" json_escape(id) ",\"kind\":\"experience\",\"project\":" json_escape(project) ",\"task\":" json_escape(task) ",\"action\":" json_escape(action) ",\"outcome\":" outcome ",\"evidence\":" evidence
    if (occurred != "") record = record ",\"occurred_at\":" json_escape(occurred)
    record = record "}"
    append_record(exp_file, record); exp_json[id] = record; exp_project[id] = project; exp_task[id] = task; exp_action[id] = action; exp_outcome[id] = outcome; exp_evidence[id] = evidence; exp_occurred[id] = occurred; exp_search[id] = tolower(project " " task " " action " " outcome " " evidence)
    tool_text("Recorded observed experience " id ".\n" experience_summary(id))
}

function record_adaptation(args, guidance, scope, sources, evidence, id, record) {
    if (!required_nonempty_string(args, "guidance", "record_adaptation")) return; guidance = GET_STRING
    scope = required_object(args, "scope", "record_adaptation"); if (!scope) return
    if (!valid_scope(scope, "record_adaptation")) return
    object_get(args, "source_experience_ids"); sources = (GET_PRESENT ? GET_RAW : "[]")
    if (substr(sources, 1, 1) != "[") { fail("record_adaptation source_experience_ids must be an array"); return }
    if (!validate_experience_ids(sources, "record_adaptation source_experience_ids")) return
    object_get(args, "evidence"); if (GET_PRESENT) { fail("record_adaptation does not accept evidence; use observe_adaptation") ; return }
    evidence = "{\"success\":0,\"failure\":0,\"other\":0,\"observations\":[]}"
    id = optional_string(args, "adaptation_id", "", "record_adaptation"); if (TOOL_ERROR != "") return
    if (id == "") id = next_id("adapt")
    if (!valid_identifier(id, "record_adaptation")) return
    if (id in adapt_json) { fail("adaptation already exists: " id); return }
    record = "{\"id\":" json_escape(id) ",\"kind\":\"adaptation\",\"guidance\":" json_escape(guidance) ",\"scope\":" scope ",\"source_experience_ids\":" sources ",\"evidence\":" evidence ",\"status\":\"active\"}"
    append_record(adapt_file, record); adapt_json[id] = record; adapt_guidance[id] = guidance; adapt_scope[id] = scope; adapt_sources[id] = sources; adapt_evidence[id] = evidence; adapt_status[id] = "active"; adapt_search[id] = tolower(guidance " " scope)
    tool_text("Recorded scoped adaptation " id ".\n" adaptation_summary(id))
}

function revise_adaptation(args, id, guidance, scope, sources, reason, record) {
    if (!required_string(args, "adaptation_id", "revise_adaptation")) return; id = GET_STRING
    if (!(id in adapt_json)) { fail("unknown adaptation: " id); return }
    if (adapt_status[id] == "retired") { fail("cannot revise retired adaptation: " id); return }
    if (!required_nonempty_string(args, "guidance", "revise_adaptation")) return; guidance = GET_STRING
    scope = required_object(args, "scope", "revise_adaptation"); if (!scope) return
    if (!valid_scope(scope, "revise_adaptation")) return
    if (!required_nonempty_string(args, "reason", "revise_adaptation")) return; reason = GET_STRING
    object_get(args, "source_experience_ids"); sources = (GET_PRESENT ? GET_RAW : adapt_sources[id])
    if (substr(sources, 1, 1) != "[") { fail("revise_adaptation source_experience_ids must be an array"); return }
    if (!validate_experience_ids(sources, "revise_adaptation source_experience_ids")) return
    record = "{\"id\":" json_escape(id) ",\"kind\":\"adaptation\",\"guidance\":" json_escape(guidance) ",\"scope\":" scope ",\"source_experience_ids\":" sources ",\"evidence\":" adapt_evidence[id] ",\"status\":\"active\"}"
    append_record(adapt_file, record); adapt_json[id] = record; adapt_guidance[id] = guidance; adapt_scope[id] = scope; adapt_sources[id] = sources; adapt_search[id] = tolower(guidance " " scope)
    tool_text("Revised adaptation " id " (" bounded_text(reason) "); prior external evidence was preserved.\n" adaptation_summary(id))
}

function count_evidence(raw, field) { object_get(raw, field); if (GET_PRESENT && GET_RAW ~ /^[0-9]+$/) return GET_RAW + 0; return 0 }
function observations_raw(raw) { object_get(raw, "observations"); if (GET_PRESENT && substr(GET_RAW, 1, 1) == "[") return GET_RAW; return "[]" }
function append_array(array_raw, item) { if (array_raw == "[]") return "[" item "]"; return substr(array_raw, 1, length(array_raw) - 1) "," item "]" }

function observe_adaptation(args, id, result, evidence, project, task, ecosystem, observed, old_evidence, success, failure, other, observations, observation, record) {
    if (!required_string(args, "adaptation_id", "observe_adaptation")) return; id = GET_STRING
    if (!(id in adapt_json)) { fail("unknown adaptation: " id); return }
    if (!required_nonempty_string(args, "result", "observe_adaptation")) return; result = GET_STRING
    evidence = required_meaningful_raw(args, "evidence", "observe_adaptation"); if (!evidence) return
    if (adapt_status[id] == "retired") { fail("cannot observe retired adaptation: " id); return }
    project = optional_nonempty_string(args, "project", "current", "observe_adaptation"); if (TOOL_ERROR != "") return
    task = optional_string(args, "task", "", "observe_adaptation"); if (TOOL_ERROR != "") return
    ecosystem = optional_string(args, "ecosystem", "", "observe_adaptation"); if (TOOL_ERROR != "") return
    observed = optional_string(args, "observed_at", "", "observe_adaptation"); if (TOOL_ERROR != "") return
    if (!observation_scope_allows(adapt_scope[id], project, task, ecosystem)) return
    old_evidence = adapt_evidence[id]; success = count_evidence(old_evidence, "success"); failure = count_evidence(old_evidence, "failure"); other = count_evidence(old_evidence, "other")
    if (tolower(result) == "success" || tolower(result) == "pass" || tolower(result) == "passed") success++
    else if (tolower(result) == "failure" || tolower(result) == "fail" || tolower(result) == "failed") failure++
    else other++
    observations = observations_raw(old_evidence); observation = "{\"project\":" json_escape(project) ",\"result\":" json_escape(result) ",\"evidence\":" evidence
    if (task != "") observation = observation ",\"task\":" json_escape(task)
    if (ecosystem != "") observation = observation ",\"ecosystem\":" json_escape(ecosystem)
    if (observed != "") observation = observation ",\"observed_at\":" json_escape(observed)
    observation = observation "}"; observations = append_array(observations, observation)
    record = "{\"id\":" json_escape(id) ",\"kind\":\"adaptation\",\"guidance\":" json_escape(adapt_guidance[id]) ",\"scope\":" adapt_scope[id] ",\"source_experience_ids\":" adapt_sources[id] ",\"evidence\":{\"success\":" success ",\"failure\":" failure ",\"other\":" other ",\"observations\":" observations "},\"status\":" json_escape(adapt_status[id]) "}"
    append_record(adapt_file, record); adapt_json[id] = record; adapt_evidence[id] = "{\"success\":" success ",\"failure\":" failure ",\"other\":" other ",\"observations\":" observations "}"
    tool_text("Observed " bounded_text(result) " for adaptation " id ". External evidence was appended.\n" adaptation_summary(id))
}

function observation_scope_allows(scope_raw, project, task, ecosystem, scoped_project, scoped_task, scoped_ecosystem) {
    scoped_project = scope_value(scope_raw, "project")
    if (scoped_project != "" && project != scoped_project) return fail("observe_adaptation project is outside adaptation scope: " project)
    scoped_task = scope_value(scope_raw, "task")
    if (scoped_task != "" && task == "") return fail("observe_adaptation requires task for task-scoped adaptation")
    if (scoped_task != "" && index(tolower(task), tolower(scoped_task)) == 0 && index(tolower(scoped_task), tolower(task)) == 0) return fail("observe_adaptation task is outside adaptation scope: " task)
    scoped_ecosystem = scope_value(scope_raw, "ecosystem")
    if (scoped_ecosystem != "" && ecosystem == "") return fail("observe_adaptation requires ecosystem for ecosystem-scoped adaptation")
    if (scoped_ecosystem != "" && ecosystem != scoped_ecosystem) return fail("observe_adaptation ecosystem is outside adaptation scope: " ecosystem)
    return 1
}

function scope_value(raw, field) {
    object_get(raw, field)
    if (GET_PRESENT && substr(GET_RAW, 1, 1) == "\"") return GET_STRING
    return ""
}

function match_scope(scope_raw, query_raw, query_text, project, field, requested, scoped) {
    if (query_raw != "" && query_raw != "null") {
        for (field in scope_fields) {
            requested = scope_value(query_raw, scope_fields[field])
            if (requested == "") continue
            scoped = scope_value(scope_raw, scope_fields[field])
            if (scoped != "" && scoped != requested) return 0
        }
    }
    if (project == "" && scope_value(query_raw, "project") == "" && scope_value(scope_raw, "project") != "") return 0
    if (project != "") {
        scoped = scope_value(scope_raw, "project")
        if (scoped != "" && scoped != project) return 0
    }
    if (query_text != "" && index(tolower(scope_raw), tolower(query_text)) == 0) {
        # A scope without a task field is general guidance; task text in the
        # guidance itself is still sufficient for the route.
        if (scope_value(scope_raw, "task") != "") return 0
    }
    return 1
}

function find_experiences(args, query, project, limit, id, count, list, truncated) {
    query = optional_string(args, "query", "", "find_experiences"); if (TOOL_ERROR != "") return
    project = optional_string(args, "project", "", "find_experiences"); if (TOOL_ERROR != "") return
    limit = bounded_limit(args, "limit", MAX_CONTEXT_ITEMS); if (TOOL_ERROR != "") return
    for (id in experience_used) delete experience_used[id]
    list = "["; count = 0
    while (count < limit && (id = next_experience(experience_used, query, project)) != "") { experience_used[id] = 1; if (count > 0) list = list ","; list = list experience_summary(id); count++ }
    truncated = (next_experience(experience_used, query, project) != "")
    tool_text("{\"count\":" count ",\"truncated\":" (truncated ? "true" : "false") ",\"experiences\":" list "]}")
}

function recommend_action(args, task, project, scope_raw, id, count, list, limit, truncated) {
    task = optional_string(args, "task", "", "recommend_action"); if (TOOL_ERROR != "") return
    project = optional_string(args, "project", "", "recommend_action"); if (TOOL_ERROR != "") return
    object_get(args, "scope"); scope_raw = (GET_PRESENT ? GET_RAW : "")
    if (scope_raw != "" && !valid_scope(scope_raw, "recommend_action")) return
    limit = bounded_limit(args, "limit", MAX_CONTEXT_ITEMS); if (TOOL_ERROR != "") return
    split("project ecosystem task", scope_fields, " ")
    for (id in recommendation_used) delete recommendation_used[id]
    list = "["; count = 0; truncated = 0
    while (count < limit && (id = next_matching_adaptation(recommendation_used, task, project, scope_raw)) != "") { recommendation_used[id] = 1; if (count > 0) list = list ","; list = list adaptation_summary(id); count++ }
    if (next_matching_adaptation(recommendation_used, task, project, scope_raw) != "") truncated = 1
    tool_text("{\"count\":" count ",\"truncated\":" (truncated ? "true" : "false") ",\"task\":" bounded_json_string(task) ",\"project\":" bounded_json_string(project) ",\"adaptations\":" list "]}")
}

function review_adaptation(args, id, e, success, failure, other, recommendation) {
    if (!required_string(args, "adaptation_id", "review_adaptation")) return; id = GET_STRING
    if (!(id in adapt_json)) { fail("unknown adaptation: " id); return }
    e = adapt_evidence[id]; success = count_evidence(e, "success"); failure = count_evidence(e, "failure"); other = count_evidence(e, "other")
    if (success == 0 && failure == 0) recommendation = "gather-more"
    else if (failure > success) recommendation = "refine-or-narrow"
    else if (success > failure) recommendation = "strengthen"
    else recommendation = "gather-more"
    tool_text("{\"adaptation\":" adaptation_summary(id) ",\"recent_observations\":" recent_observations(adapt_evidence[id]) ",\"recommendation\":" json_escape(recommendation) ",\"reason\":\"Based on externally observed success/failure counts; self-assessment is not counted.\"}")
}

function retire_adaptation(args, id, record) {
    if (!required_string(args, "adaptation_id", "retire_adaptation")) return; id = GET_STRING
    if (!(id in adapt_json)) { fail("unknown adaptation: " id); return }
    if (adapt_status[id] == "retired") { fail("adaptation is already retired: " id); return }
    record = "{\"id\":" json_escape(id) ",\"kind\":\"adaptation\",\"guidance\":" json_escape(adapt_guidance[id]) ",\"scope\":" adapt_scope[id] ",\"source_experience_ids\":" adapt_sources[id] ",\"evidence\":" adapt_evidence[id] ",\"status\":\"retired\"}"
    append_record(adapt_file, record); adapt_json[id] = record; adapt_status[id] = "retired"
    tool_text("Retired adaptation " id "; its evidence and history remain available.\n" adaptation_summary(id))
}
