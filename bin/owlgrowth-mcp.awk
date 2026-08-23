# OwlGrowth's only product boundary is MCP over stdio.
# This file intentionally uses only POSIX awk.

BEGIN {
    exp_file = data_dir "/experiences.jsonl"
    adapt_file = data_dir "/adaptations.jsonl"
    sequence = 0
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

function json_decode(s, i, c, out, hex, n) {
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
                if (n >= 32 && n < 127) out = out sprintf("%c", n)
                else out = out "\\u" hex
                i += 4
            } else out = out c
        } else if (c == "\"") return out
        else out = out c
        i++
    }
    return out
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

function json_escape(s, i, c, out) {
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

function load_experiences(line, id) {
    while ((getline line < exp_file) > 0) {
        if (object_get(line, "id") && GET_PRESENT) {
            id = GET_STRING; exp_json[id] = line
            object_get(line, "project"); exp_project[id] = GET_STRING
            object_get(line, "task"); exp_task[id] = GET_STRING
            object_get(line, "action"); exp_action[id] = GET_STRING
            object_get(line, "outcome"); exp_outcome[id] = GET_RAW
            object_get(line, "evidence"); exp_evidence[id] = GET_RAW
            exp_search[id] = tolower(exp_project[id] " " exp_task[id] " " exp_action[id] " " exp_outcome[id] " " exp_evidence[id])
            sequence++
        }
    }
    close(exp_file)
}

function load_adaptations(line, id) {
    while ((getline line < adapt_file) > 0) {
        if (object_get(line, "id") && GET_PRESENT) {
            id = GET_STRING; adapt_json[id] = line
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

function next_id(prefix) { sequence++; return prefix "-" systime() "-" sequence }
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

function optional_string(obj, name, default_value) {
    object_get(obj, name)
    if (GET_PRESENT && substr(GET_RAW, 1, 1) == "\"") return GET_STRING
    return default_value
}

function required_raw(obj, name, label) {
    object_get(obj, name)
    if (!GET_PRESENT || GET_RAW == "null") return fail(label " requires argument '" name "'")
    return GET_RAW
}

function meaningful_raw(raw) {
    return raw != "" && raw != "null" && raw != "\"\"" && raw != "{}" && raw != "[]"
}

function required_meaningful_raw(obj, name, label) {
    object_get(obj, name)
    if (!GET_PRESENT || !meaningful_raw(GET_RAW)) return fail(label " requires non-empty argument '" name "'")
    return GET_RAW
}

function required_object(obj, name, label) {
    object_get(obj, name)
    if (!GET_PRESENT || substr(GET_RAW, 1, 1) != "{") return fail(label " requires object argument '" name "'")
    return GET_RAW
}

function validate_experience_ids(raw, label, i, start, e, item) {
    i = ws(raw, 2)
    if (substr(raw, i, 1) == "]") return 1
    while (i <= length(raw)) {
        start = ws(raw, i); e = value_end(raw, start)
        if (e < start || substr(raw, start, 1) != "\"") return fail(label " must contain experience id strings")
        item = json_decode(substr(raw, start, e - start + 1))
        if (item == "" || !(item in exp_json)) return fail(label " references unknown experience: " item)
        i = ws(raw, e + 1)
        if (substr(raw, i, 1) == ",") i = ws(raw, i + 1)
        else if (substr(raw, i, 1) == "]") return 1
        else return fail(label " must be an array")
    }
    return fail(label " must be an array")
}

function handle_request(line, method, id_present, params) {
    ID_RAW = "null"; object_get(line, "id"); id_present = GET_PRESENT
    if (id_present) ID_RAW = GET_RAW
    object_get(line, "method")
    if (!GET_PRESENT || substr(GET_RAW, 1, 1) != "\"") { if (id_present) rpc_error(-32600, "request requires string method"); return }
    method = GET_STRING
    if (method == "notifications/initialized" || method == "notifications/cancelled") return
    if (method == "initialize") { rpc_result("{\"protocolVersion\":\"2024-11-05\",\"capabilities\":{\"tools\":{},\"resources\":{\"subscribe\":false,\"listChanged\":false}},\"serverInfo\":{\"name\":\"owlgrowth\",\"version\":\"0.1.0\"}}"); return }
    if (method == "ping") { rpc_result("{}"); return }
    if (method == "tools/list") { rpc_result(tools_json()); return }
    if (method == "resources/list") { rpc_result(resources_json()); return }
    if (method == "resources/read") { object_get(line, "params"); params = (GET_PRESENT ? GET_RAW : "{}"); resource_read(params); return }
    if (method == "tools/call") { object_get(line, "params"); params = (GET_PRESENT ? GET_RAW : "{}"); tool_call(params); return }
    if (method == "shutdown") { rpc_result("null"); return }
    if (id_present) rpc_error(-32601, "method not found: " method)
}

function rpc_result(result) { print "{\"jsonrpc\":\"2.0\",\"id\":" ID_RAW ",\"result\":" result "}"; fflush() }
function rpc_error(code, message) { print "{\"jsonrpc\":\"2.0\",\"id\":" ID_RAW ",\"error\":{\"code\":" code ",\"message\":" json_escape(message) "}}"; fflush() }
function tool_text(message, is_error) {
    print "{\"jsonrpc\":\"2.0\",\"id\":" ID_RAW ",\"result\":{\"content\":[{\"type\":\"text\",\"text\":" json_escape(message) "}]" (is_error ? ",\"isError\":true" : "") "}}"
    fflush()
}

function tools_json() {
    return "{\"tools\":[" \
      "{\"name\":\"discover\",\"description\":\"Explain when to use OwlGrowth and route the small public surface. Read-only.\",\"inputSchema\":{\"type\":\"object\",\"properties\":{}}}," \
      "{\"name\":\"find_experiences\",\"description\":\"Find observed task/action/outcome records. Never turns an interpretation into an experience.\",\"inputSchema\":{\"type\":\"object\",\"properties\":{\"query\":{\"type\":\"string\"},\"project\":{\"type\":\"string\"},\"limit\":{\"type\":\"integer\"}}}}," \
      "{\"name\":\"record_experience\",\"description\":\"Append one observed Task/Action/Outcome/Evidence event. Evidence is required.\",\"inputSchema\":{\"type\":\"object\",\"required\":[\"task\",\"action\",\"outcome\",\"evidence\"],\"properties\":{\"task\":{\"type\":\"string\"},\"action\":{\"type\":\"string\"},\"outcome\":{},\"evidence\":{},\"project\":{\"type\":\"string\"},\"occurred_at\":{\"type\":\"string\"},\"experience_id\":{\"type\":\"string\"}}}}," \
      "{\"name\":\"record_adaptation\",\"description\":\"Record scoped action guidance separately from experiences; at least one existing experience must support it.\",\"inputSchema\":{\"type\":\"object\",\"required\":[\"guidance\",\"scope\",\"source_experience_ids\"],\"properties\":{\"guidance\":{\"type\":\"string\"},\"scope\":{},\"source_experience_ids\":{\"type\":\"array\",\"minItems\":1},\"adaptation_id\":{\"type\":\"string\"}}}}," \
      "{\"name\":\"revise_adaptation\",\"description\":\"Revise guidance or narrow its scope while preserving its observed evidence and history.\",\"inputSchema\":{\"type\":\"object\",\"required\":[\"adaptation_id\",\"guidance\",\"scope\",\"reason\"],\"properties\":{\"adaptation_id\":{\"type\":\"string\"},\"guidance\":{\"type\":\"string\"},\"scope\":{},\"reason\":{\"type\":\"string\"},\"source_experience_ids\":{\"type\":\"array\"}}}}," \
      "{\"name\":\"observe_adaptation\",\"description\":\"Evaluate guidance with an externally observable outcome and append the observation.\",\"inputSchema\":{\"type\":\"object\",\"required\":[\"adaptation_id\",\"result\",\"evidence\"],\"properties\":{\"adaptation_id\":{\"type\":\"string\"},\"result\":{\"type\":\"string\"},\"evidence\":{},\"project\":{\"type\":\"string\"},\"task\":{\"type\":\"string\"},\"observed_at\":{\"type\":\"string\"}}}}," \
      "{\"name\":\"recommend_action\",\"description\":\"Return up to a bounded number of active scoped adaptations that may improve the next action.\",\"inputSchema\":{\"type\":\"object\",\"properties\":{\"task\":{\"type\":\"string\"},\"scope\":{},\"project\":{\"type\":\"string\"},\"limit\":{\"type\":\"integer\",\"minimum\":1}}}}," \
      "{\"name\":\"review_adaptation\",\"description\":\"Summarize external evidence and recommend strengthen, refine/narrow, or gather-more.\",\"inputSchema\":{\"type\":\"object\",\"required\":[\"adaptation_id\"],\"properties\":{\"adaptation_id\":{\"type\":\"string\"}}}}," \
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
        if (guidance_count <= 20) out = out "- [" id "] " adapt_guidance[id] " | scope=" adapt_scope[id] " | evidence=" adapt_evidence[id] "\n"
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
    project = optional_string(args, "project", "current"); occurred = optional_string(args, "occurred_at", ""); id = optional_string(args, "experience_id", "")
    if (id == "") id = next_id("exp")
    if (id in exp_json) { fail("experience already exists: " id); return }
    record = "{\"id\":" json_escape(id) ",\"kind\":\"experience\",\"project\":" json_escape(project) ",\"task\":" json_escape(task) ",\"action\":" json_escape(action) ",\"outcome\":" outcome ",\"evidence\":" evidence
    if (occurred != "") record = record ",\"occurred_at\":" json_escape(occurred)
    record = record "}"
    append_record(exp_file, record); exp_json[id] = record; exp_project[id] = project; exp_task[id] = task; exp_action[id] = action; exp_outcome[id] = outcome; exp_evidence[id] = evidence; exp_search[id] = tolower(project " " task " " action " " outcome " " evidence)
    tool_text("Recorded observed experience " id ".\n" record)
}

function record_adaptation(args, guidance, scope, sources, evidence, id, record) {
    if (!required_nonempty_string(args, "guidance", "record_adaptation")) return; guidance = GET_STRING
    scope = required_object(args, "scope", "record_adaptation"); if (!scope) return
    object_get(args, "source_experience_ids"); sources = (GET_PRESENT ? GET_RAW : "[]")
    if (substr(sources, 1, 1) != "[") { fail("record_adaptation source_experience_ids must be an array"); return }
    if (sources == "[]") { fail("record_adaptation requires at least one source experience"); return }
    if (!validate_experience_ids(sources, "record_adaptation source_experience_ids")) return
    object_get(args, "evidence"); if (GET_PRESENT) { fail("record_adaptation does not accept evidence; use observe_adaptation") ; return }
    evidence = "{\"success\":0,\"failure\":0,\"other\":0,\"observations\":[]}"
    id = optional_string(args, "adaptation_id", ""); if (id == "") id = next_id("adapt")
    if (id in adapt_json) { fail("adaptation already exists: " id); return }
    record = "{\"id\":" json_escape(id) ",\"kind\":\"adaptation\",\"guidance\":" json_escape(guidance) ",\"scope\":" scope ",\"source_experience_ids\":" sources ",\"evidence\":" evidence ",\"status\":\"active\"}"
    append_record(adapt_file, record); adapt_json[id] = record; adapt_guidance[id] = guidance; adapt_scope[id] = scope; adapt_sources[id] = sources; adapt_evidence[id] = evidence; adapt_status[id] = "active"; adapt_search[id] = tolower(guidance " " scope)
    tool_text("Recorded scoped adaptation " id ".\n" record)
}

function revise_adaptation(args, id, guidance, scope, sources, reason, record) {
    if (!required_string(args, "adaptation_id", "revise_adaptation")) return; id = GET_STRING
    if (!(id in adapt_json)) { fail("unknown adaptation: " id); return }
    if (adapt_status[id] == "retired") { fail("cannot revise retired adaptation: " id); return }
    if (!required_string(args, "guidance", "revise_adaptation")) return; guidance = GET_STRING
    scope = required_object(args, "scope", "revise_adaptation"); if (!scope) return
    if (!required_nonempty_string(args, "reason", "revise_adaptation")) return; reason = GET_STRING
    object_get(args, "source_experience_ids"); sources = (GET_PRESENT ? GET_RAW : adapt_sources[id])
    if (substr(sources, 1, 1) != "[") { fail("revise_adaptation source_experience_ids must be an array"); return }
    if (!validate_experience_ids(sources, "revise_adaptation source_experience_ids")) return
    record = "{\"id\":" json_escape(id) ",\"kind\":\"adaptation\",\"guidance\":" json_escape(guidance) ",\"scope\":" scope ",\"source_experience_ids\":" sources ",\"evidence\":" adapt_evidence[id] ",\"status\":\"active\"}"
    append_record(adapt_file, record); adapt_json[id] = record; adapt_guidance[id] = guidance; adapt_scope[id] = scope; adapt_sources[id] = sources; adapt_search[id] = tolower(guidance " " scope)
    tool_text("Revised adaptation " id " (" reason "); prior external evidence was preserved.\n" record)
}

function count_evidence(raw, field) { object_get(raw, field); if (GET_PRESENT && GET_RAW ~ /^[0-9]+$/) return GET_RAW + 0; return 0 }
function observations_raw(raw) { object_get(raw, "observations"); if (GET_PRESENT && substr(GET_RAW, 1, 1) == "[") return GET_RAW; return "[]" }
function append_array(array_raw, item) { if (array_raw == "[]") return "[" item "]"; return substr(array_raw, 1, length(array_raw) - 1) "," item "]" }

function observe_adaptation(args, id, result, evidence, project, task, observed, old_evidence, success, failure, other, observations, observation, record) {
    if (!required_string(args, "adaptation_id", "observe_adaptation")) return; id = GET_STRING
    if (!(id in adapt_json)) { fail("unknown adaptation: " id); return }
    if (!required_string(args, "result", "observe_adaptation")) return; result = GET_STRING
    evidence = required_meaningful_raw(args, "evidence", "observe_adaptation"); if (!evidence) return
    project = optional_string(args, "project", "current"); task = optional_string(args, "task", ""); observed = optional_string(args, "observed_at", "")
    if (!observation_scope_allows(adapt_scope[id], project, task)) return
    old_evidence = adapt_evidence[id]; success = count_evidence(old_evidence, "success"); failure = count_evidence(old_evidence, "failure"); other = count_evidence(old_evidence, "other")
    if (tolower(result) == "success" || tolower(result) == "pass" || tolower(result) == "passed") success++
    else if (tolower(result) == "failure" || tolower(result) == "fail" || tolower(result) == "failed") failure++
    else other++
    observations = observations_raw(old_evidence); observation = "{\"project\":" json_escape(project) ",\"result\":" json_escape(result) ",\"evidence\":" evidence
    if (task != "") observation = observation ",\"task\":" json_escape(task)
    if (observed != "") observation = observation ",\"observed_at\":" json_escape(observed)
    observation = observation "}"; observations = append_array(observations, observation)
    record = "{\"id\":" json_escape(id) ",\"kind\":\"adaptation\",\"guidance\":" json_escape(adapt_guidance[id]) ",\"scope\":" adapt_scope[id] ",\"source_experience_ids\":" adapt_sources[id] ",\"evidence\":{\"success\":" success ",\"failure\":" failure ",\"other\":" other ",\"observations\":" observations "},\"status\":" json_escape(adapt_status[id]) "}"
    append_record(adapt_file, record); adapt_json[id] = record; adapt_evidence[id] = "{\"success\":" success ",\"failure\":" failure ",\"other\":" other ",\"observations\":" observations "}"
    tool_text("Observed " result " for adaptation " id ". External evidence was appended.\n" record)
}

function observation_scope_allows(scope_raw, project, task, scoped_project, scoped_task) {
    scoped_project = scope_value(scope_raw, "project")
    if (scoped_project != "" && project != scoped_project) return fail("observe_adaptation project is outside adaptation scope: " project)
    scoped_task = scope_value(scope_raw, "task")
    if (scoped_task != "" && task == "") return fail("observe_adaptation requires task for task-scoped adaptation")
    if (scoped_task != "" && index(tolower(task), tolower(scoped_task)) == 0 && index(tolower(scoped_task), tolower(task)) == 0) return fail("observe_adaptation task is outside adaptation scope: " task)
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

function find_experiences(args, query, project, limit, id, count, list) {
    query = optional_string(args, "query", ""); project = optional_string(args, "project", ""); object_get(args, "limit"); limit = (GET_PRESENT && GET_RAW ~ /^[0-9]+$/ ? GET_RAW + 0 : 20); if (limit < 1) limit = 1
    for (id in experience_used) delete experience_used[id]
    list = "["; count = 0
    while (count < limit && (id = next_experience(experience_used, query, project)) != "") { experience_used[id] = 1; if (count > 0) list = list ","; list = list exp_json[id]; count++ }
    tool_text("{\"count\":" count ",\"experiences\":" list "]}")
}

function recommend_action(args, task, project, scope_raw, id, count, list, limit, truncated) {
    task = optional_string(args, "task", ""); project = optional_string(args, "project", ""); object_get(args, "scope"); scope_raw = (GET_PRESENT ? GET_RAW : "")
    object_get(args, "limit"); limit = (GET_PRESENT && GET_RAW ~ /^[0-9]+$/ ? GET_RAW + 0 : 20); if (limit < 1) limit = 1
    split("project ecosystem task", scope_fields, " ")
    for (id in recommendation_used) delete recommendation_used[id]
    list = "["; count = 0; truncated = 0
    while (count < limit && (id = next_matching_adaptation(recommendation_used, task, project, scope_raw)) != "") { recommendation_used[id] = 1; if (count > 0) list = list ","; list = list adapt_json[id]; count++ }
    if (next_matching_adaptation(recommendation_used, task, project, scope_raw) != "") truncated = 1
    tool_text("{\"count\":" count ",\"truncated\":" (truncated ? "true" : "false") ",\"task\":" json_escape(task) ",\"project\":" json_escape(project) ",\"adaptations\":" list "]}")
}

function review_adaptation(args, id, e, success, failure, other, recommendation) {
    if (!required_string(args, "adaptation_id", "review_adaptation")) return; id = GET_STRING
    if (!(id in adapt_json)) { fail("unknown adaptation: " id); return }
    e = adapt_evidence[id]; success = count_evidence(e, "success"); failure = count_evidence(e, "failure"); other = count_evidence(e, "other")
    if (success == 0 && failure == 0) recommendation = "gather-more"
    else if (failure > success) recommendation = "refine-or-narrow"
    else if (success > failure) recommendation = "strengthen"
    else recommendation = "gather-more"
    tool_text("{\"adaptation\":" adapt_json[id] ",\"recommendation\":" json_escape(recommendation) ",\"reason\":\"Based on externally observed success/failure counts; self-assessment is not counted.\"}")
}

function retire_adaptation(args, id, record) {
    if (!required_string(args, "adaptation_id", "retire_adaptation")) return; id = GET_STRING
    if (!(id in adapt_json)) { fail("unknown adaptation: " id); return }
    if (adapt_status[id] == "retired") { fail("adaptation is already retired: " id); return }
    record = "{\"id\":" json_escape(id) ",\"kind\":\"adaptation\",\"guidance\":" json_escape(adapt_guidance[id]) ",\"scope\":" adapt_scope[id] ",\"source_experience_ids\":" adapt_sources[id] ",\"evidence\":" adapt_evidence[id] ",\"status\":\"retired\"}"
    append_record(adapt_file, record); adapt_json[id] = record; adapt_status[id] = "retired"
    tool_text("Retired adaptation " id "; its evidence and history remain available.\n" record)
}
