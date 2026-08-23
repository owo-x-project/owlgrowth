+++
version = 2
id = "decision.surface.minimal-tools-resources"
kind = "decision"

[[relations]]
type = "constrained_by"
to = "constraint.tool.low-cognitive-load"
+++

# 公開面は利用目的ごとに最小化する

OwlGrowthが公開するtoolとresourceは、経験の検索・記録、Adaptationの提案・観測、現在の行動改善の参照など、明確な利用目的に必要なものだけにする。内部ファイルや内部イベント形式をそのまま公開せず、toolとresourceの具体的な一覧は実利用で必要性を確認しながら決める。

内部データを汎用CRUDとして全面公開する案は、認知負荷と誤操作の可能性を増やすため採用しない。
