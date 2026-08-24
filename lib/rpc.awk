# JSON-RPC request routing and response helpers for OwlGrowth.

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
