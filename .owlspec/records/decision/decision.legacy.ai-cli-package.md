+++
version = 2
id = "decision.legacy.ai-cli-package"
kind = "decision"
retired = true
+++

# 企画書に記載されたAI CLI/APM導入案（現在は不採用）

企画書には、最初から専用CLIを作らず、Claude CodeやCodexのSkills、Instructions、Hooks、shell executionを使い、APMパッケージを`apm install owlgrowth`で導入する案が記載されていた。APMパッケージは`owlgrowth/SKILL.md`と`scripts/`から構成し、実装段階として、SKILL.mdだけで実験し、データ形式を定義し、AI自身に読み書きさせ、壊れやすい部分だけscript化し、必要性が証明された場合のみCLIを追加する流れも記載されていた。scriptが必要な場合はbash、jq、git程度で実現し、bashやjq自体は仕様に含めずデータ形式を環境非依存にする案も含まれていた。

これは企画書上の旧案を履歴として保持するrecordであり、現在のMCP-only・sh+awk方針では採用しない。
