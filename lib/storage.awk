# Persistence, reload validation, and storage-side query helpers for OwlGrowth.

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
