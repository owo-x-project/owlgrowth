+++
version = 2
id = "decision.scope.experience-adaptation"
kind = "decision"

[[relations]]
type = "constrained_by"
to = "constraint.scope.lightweight"
+++

# 軽量な成長基盤としてTaskから次のActionまでの経験循環を扱う

OwlGrowthは、AIエージェントがプロジェクトで得た経験と結果を蓄積し、その経験から行動を継続的に改善するための軽量な成長基盤である。中心モデルは、Task → Action → Outcome → Experience → Reflection → Adaptation → 次のActionである。Experienceは実際に起きた出来事であり、Adaptationは複数のExperienceから得られる今後の行動改善である。Adaptationは固定された真実ではなく、経験によって継続的に変化する。

OwlGrowthはKnowledge、仕様、決定事項を管理しない。経験と改善案を単一の汎用メモリ形式に統合する案は、観測事実と行動指針の境界を曖昧にするため採用しない。
