+++
version = 2
id = "decision.evaluation.outcome-based"
kind = "decision"

[[relations]]
type = "constrained_by"
to = "constraint.evaluation.external-outcome"
+++

# 成長をOutcomeで評価する

OwlGrowthの中心ループは、Adaptationを利用し、次のOutcomeを観測し、その有効性を評価して、強化・修正・適用範囲縮小・削除する流れとする。保存量を成長の指標にせず、実際の行動品質の変化を指標にする。

AIの自己評価だけでAdaptationを確定する案は、誤った改善案を固定するため採用しない。
