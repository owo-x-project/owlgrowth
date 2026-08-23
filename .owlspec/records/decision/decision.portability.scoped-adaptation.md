+++
version = 2
id = "decision.portability.scoped-adaptation"
kind = "decision"

[[relations]]
type = "constrained_by"
to = "constraint.experience.project-scoped"
+++

# 再利用するのは範囲付きAdaptationにする

Experienceそのものを無制限にプロジェクト横断共有するのではなく、複数プロジェクトの経験から得られたAdaptationを、適用範囲と根拠付きで再利用する。複数環境で成功したAdaptationほど一般化可能性が高いものとして扱う。

プロジェクト固有Experienceをそのまま一般知識として共有する案は、環境依存の手順を誤って適用するため採用しない。
