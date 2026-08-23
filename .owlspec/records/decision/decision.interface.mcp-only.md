+++
version = 2
id = "decision.interface.mcp-only"
kind = "decision"

[[relations]]
type = "constrained_by"
to = "constraint.implementation.sh-awk-only"

[[relations]]
type = "supersedes"
to = "decision.legacy.ai-cli-package"
+++

# MCPだけを公開インターフェースにする

OwlGrowthはMCP serverとして提供し、MCP clientからtoolとresourceを利用する。sh+awkによるstdio MCP実装を製品の唯一の操作境界とし、専用CLI、HTTP API、別形式の操作入口を製品仕様に含めない。

APM Skillや通常ファイル操作を主インターフェースにする旧案は、利用経路を増やしtoolの利用規範を分散させるため採用しない。
