+++
version = 2
id = "design.implementation.mcp-server"
kind = "design"
target = "bin/owlgrowth-mcp.awk"
+++

# OwlGrowth MCP server

The stdio MCP protocol, tool routing, JSONL persistence, scoped adaptations, and evidence-based review are implemented here. Notifications without an id execute without emitting a response. Durable records retain complete observed values, while public MCP projections cap result counts at 20, text/raw values at 512 characters, and recent review observations at five. JSON-RPC envelopes, JSON values, identifiers, and known scope fields are validated before append-only writes; project, task, and ecosystem scope values must be non-empty strings.

The POSIX shell launcher serializes one request stream per data directory with an exclusive lock and reclaims locks whose owner is no longer alive, preventing concurrent codex exec or MCP processes from losing append-only updates or reusing generated ids. On reload, only complete JSON records with the expected persisted shape are admitted; malformed or partial lines are ignored. Optional string inputs are type-checked, meaningful values cannot be whitespace-only, provenance lists cannot contain duplicate experience ids, and escaped Unicode identifiers are decoded consistently. Ecosystem-scoped observations require a matching ecosystem, and externally supplied observation result text is bounded in public responses.
