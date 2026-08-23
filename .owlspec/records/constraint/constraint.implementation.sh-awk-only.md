+++
version = 2
id = "constraint.implementation.sh-awk-only"
kind = "constraint"
+++

# 実装はshとawkに限定する

OwlGrowthのMCPサーバー実装はshとawkだけで構成する。Python、jq、SQLite、専用MCP SDK、別の常駐ランタイムなどを実装上の前提にしない。プロトコル境界はMCPに限定し、製品固有のCLIや別APIを追加しない。
