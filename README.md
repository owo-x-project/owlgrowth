OwlGrowth 企画書

1. 概要

OwlGrowth は、AIエージェントがプロジェクトで得た経験と結果を蓄積し、その経験から行動を継続的に改善するための軽量な成長基盤である。

一般的なAIメモリが「何を覚えているか」を中心に扱うのに対し、OwlGrowthは、

«過去の経験によって、次回のAIの行動が実際に改善されること»

を目的とする。

OwlGrowthはKnowledgeや仕様、決定事項を管理しない。

---

2. 解決する問題

AI駆動開発では、同じプロジェクトを継続して扱ってもAIが、

- 過去と同じ失敗を繰り返す
- 成功した手順を再利用しない
- 過去に得たコツを一般化できない
- プロジェクトを跨ぐと経験が完全に失われる
- メモリが増えても行動品質が向上しているとは限らない

という問題がある。

Claude Code Memoryや一般的なエージェントメモリは情報保持には有効だが、経験 → 評価 → 行動改善そのものを中心にはしていない。

OwlGrowthはこの部分だけを担当する。

---

3. 基本モデル

OwlGrowthではKnowledgeという概念を使用しない。

中心となるのは以下の流れである。

Task
 ↓
 Action
  ↓
  Outcome
   ↓
   Experience
    ↓
    Reflection
     ↓
     Adaptation
      ↓
      次のAction

      Experience

      実際に起きた出来事。

      例：

      task: dependency debugging
      action: lockfileを変更せずpackage.jsonを修正した
      outcome: failed
      evidence: npm test failed

      Experienceは原則として観測事実として保持する。

      Adaptation

      複数のExperienceから得られた、今後の行動改善。

      guidance: >
        dependency問題では変更前にlockfileとの差分を確認する

        scope:
          ecosystem: node
            task: dependency-debugging

            evidence:
              success: 12
                failure: 1

                Adaptationは固定された真実ではなく、経験によって継続的に変化する。

                ---

                4. 自己改善

                OwlGrowthの中心機能はAdaptationの継続改善である。

                Adaptationを利用
                       ↓
                       Outcomeを観測
                              ↓
                              有効性を評価
                                     ↓
                                     強化 / 修正 / 適用範囲縮小 / 削除

                                     AI自身の自己評価だけではなく、

                                     - テスト結果
                                     - コマンド終了コード
                                     - ビルド結果
                                     - ユーザーによる承認
                                     - タスク完了状態

                                     など、可能な限り外部から観測可能な結果を使用する。

                                     ---

                                     5. プロジェクト横断成長

                                     Experienceそのものはプロジェクト固有情報を多く含むため、基本的にはプロジェクト内に保持する。

                                     一方でAdaptationは適用範囲を持たせることで他プロジェクトへ転用可能にする。

                                     Project A experience ─┐
                                     Project B experience ─┼→ Node共通Adaptation
                                     Project C experience ─┘

                                     複数環境で成功したAdaptationほど一般化できる。

                                     これにより、

                                     «AIを使うほど、単一プロジェクトだけでなくAIの作業方法そのものが育つ»

                                     状態を目指す。

                                     ---

                                     6. Claude Code Memory / LeanCTXとの差

                                     Claude Code Memory

                                     主目的：

                                     «必要な情報を次のセッションでも覚える。»

                                     OwlGrowth：

                                     «経験の結果によって次の行動方法そのものを変える。»

                                     LeanCTX

                                     主目的：

                                     «必要なコンテキストや過去情報を効率的に取得する。»

                                     OwlGrowth：

                                     «取得された経験をもとに行動方針を改善する。»

                                     したがってOwlGrowthはメモリ基盤やコンテキスト基盤そのものとは競合せず、併用可能とする。

                                     ---

                                     7. 実装方針

                                     AI CLIネイティブを優先する

                                     最初から専用CLIを作らない。

                                     Claude Code / Codexなどが持つ、

                                     - Skills
                                     - Instructions
                                     - Hooks
                                     - shell execution

                                     などを利用し、APMパッケージとして配布する。

                                     apm install owlgrowth

                                     だけで導入できることを目標とする。

                                     実装の段階

                                     1. "SKILL.md"だけで実験
                                     2. データ形式だけ定義
                                     3. AI自身に読み書きさせる
                                     4. AI操作では壊れやすい部分のみscript化
                                     5. 必要性が証明された場合のみCLIを追加

                                     ---

                                     8. 最小構成

                                     例：

                                     .owlgrowth/
                                     ├── experiences.jsonl
                                     └── adaptations.jsonl

                                     APMパッケージ：

                                     owlgrowth/
                                     ├── SKILL.md
                                     └── scripts/

                                     scriptが必要な場合も、可能な限り、

                                     bash
                                     jq
                                     git

                                     程度で実現する。

                                     ただしbashやjq自体をOwlGrowthの仕様には含めず、データ形式を環境非依存に保つ。

                                     ---

                                     9. Owlシリーズとの関係

                                     OwlGrowthは他のOwlツールを認知しない。

                                     OwlspecやOwlKnowledge専用API、専用参照形式などは持たせない。

                                     他ツールが生成したファイルも、OwlGrowthから見れば通常のファイルやEvidenceとして扱う。

                                     これにより、

                                     OwlGrowth単独
                                     OwlGrowth + Owlspec
                                     OwlGrowth + OwlKnowledge
                                     3ツール併用

                                     のすべてを成立させる。

                                     ---

                                     10. 設計原則

                                     1. Knowledgeを管理しない
                                     2. ExperienceとAdaptationを分離する
                                     3. 成長は実際のOutcomeで評価する
                                     4. 生Experienceより再利用可能なAdaptationを育てる
                                     5. プロジェクト横断でAdaptationを一般化できる
                                     6. AI CLIネイティブ機能を最大限利用する
                                     7. 専用CLIを目的化しない
                                     8. 他Owlツールへ依存しない
                                     9. データを単純なファイルとして保持する
                                     10. AIを使い続けるほど行動品質が向上することを最終指標とする

                                     11. 成功条件

                                     OwlGrowthの価値は保存量ではなく、次の指標で評価する。

                                     - 同一失敗の再発率が下がる
                                     - タスク完了までの試行回数が減る
                                     - 過去の成功方法が適切に再利用される
                                     - 不適切なAdaptationが経験によって修正される
                                     - 別プロジェクトでも有効なAdaptationが発見される

                                     「記憶が増えた」ではなく「AIが実際に上手くなった」を成功とする。
