+++
version = 2
id = "design.implementation.mcp-server"
kind = "design"
target = "bin/owlgrowth-mcp.awk"
+++

# OwlGrowth MCP server

The stdio MCP protocol, tool routing, JSONL persistence, scoped adaptations, and evidence-based review are implemented here. Durable records retain complete observed values, while public MCP projections cap result counts at 20, text/raw values at 512 characters, and recent review observations at five. JSON-RPC envelopes, JSON values, identifiers, and known scope fields are validated before append-only writes; project, task, and ecosystem scope values must be non-empty strings.
