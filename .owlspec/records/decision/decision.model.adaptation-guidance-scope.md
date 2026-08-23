+++
version = 2
id = "decision.model.adaptation-guidance-scope"
kind = "decision"

[[relations]]
type = "constrained_by"
to = "constraint.experience.observed-fact"

[[relations]]
type = "constrained_by"
to = "constraint.experience.project-scoped"
+++

# AdaptationはGuidance・Scope・Evidenceを伴う

企画書のAdaptation例では、今後の行動を示すguidance、適用範囲を示すscope、成功・失敗などのevidenceを伴う。例として、dependency debuggingでlockfileを変更せずpackage.jsonを修正し、`npm test failed`になったExperienceから、「変更前にlockfileとの差分を確認する」というguidanceを、ecosystem=node・task=dependency-debuggingというscopeで適用し、success=12・failure=1のようなevidenceで評価する。

この例を固定スキーマや固定フィールド名として強制するのではなく、改善案が何を勧め、どの範囲に適用でき、どの経験結果に基づくかを失わないことを決定する。
