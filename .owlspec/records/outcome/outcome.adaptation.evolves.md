+++
version = 2
id = "outcome.adaptation.evolves"
kind = "outcome"

[[relations]]
type = "constrained_by"
to = "constraint.evaluation.external-outcome"

[[relations]]
type = "constrained_by"
to = "constraint.experience.observed-fact"

[[relations]]
type = "verified_by"
to = "verification.growth.adaptation-loop"
+++

# Adaptationが経験によって継続改善される

OwlGrowthの中心機能はAdaptationの継続改善である。Adaptationを利用し、Outcomeを観測し、有効性を評価した結果に応じて、強化・修正・適用範囲縮小・削除する。不適切なAdaptationが新しいExperienceによって修正され、固定された誤りとして残り続けない。評価にはAI自身の自己評価だけでなく、外部から観測可能な結果を使用する。
