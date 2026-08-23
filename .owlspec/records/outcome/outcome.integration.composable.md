+++
version = 2
id = "outcome.integration.composable"
kind = "outcome"

[[relations]]
type = "constrained_by"
to = "constraint.project.independence"

[[relations]]
type = "verified_by"
to = "verification.growth.composable-mcp"
+++

# OwlGrowthを他の基盤と組み合わせて利用できる

OwlGrowth単独、OwlGrowthとOwlspec、OwlGrowthとOwlKnowledge、3ツール併用のすべてを、OwlGrowthが相手の専用APIや専用参照形式を認知しなくても成立させる。
