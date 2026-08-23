+++
version = 2
id = "design.implementation.mcp-server"
kind = "design"
target = "bin/owlgrowth-mcp.awk"
+++

# OwlGrowth MCP server

The stdio MCP protocol, tool routing, JSONL persistence, scoped adaptations, and evidence-based review are implemented here. Notifications without an id execute without emitting a response. Durable records retain complete observed values, while public MCP projections cap result counts at 20, text/raw values at 512 characters, and recent review observations at five. JSON-RPC envelopes and values reject duplicate object keys, require object-or-array `params` when present, cap each request line at 65,536 characters, validate identifiers and known scope fields, and require positive integer list limits before append-only writes.

The POSIX shell launcher serializes one request stream per data directory with an exclusive owner-PID lock. It reclaims malformed or dead-owner locks, removes a lock only when the current process still owns it, and signal cleanup terminates the child AWK process without closing its input stream. This prevents concurrent codex exec or MCP processes from losing append-only updates or reusing generated ids. On reload, only complete records with the expected persisted shape and semantics are admitted; malformed or partial lines, unknown adaptation source experiences, duplicate citations, invalid scopes/evidence/status, and invalid references are ignored. Optional string inputs are type-checked, meaningful values cannot be whitespace-only, provenance lists cannot contain duplicate experience ids, and escaped Unicode identifiers are decoded consistently. Ecosystem-scoped observations require a matching ecosystem, and externally supplied observation result text is bounded in public responses.
