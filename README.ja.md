# OwlGrowth

[英語版](README.md)

## プロジェクト概要

OwlGrowthは、作業で観測された結果を次の行動改善につなげる、軽量なMCPサーバーです。経験と行動指針をプロジェクト単位で扱い、標準入出力でCodexやClaudeなどのMCPクライアントから利用できます。

## コンセプト

観測された作業・行動・結果・根拠を「経験」として記録し、複数の経験から再利用可能な「改善指針」を作ります。「改善指針」は固定的な知識ではなく、外部から観測した結果によって強化・修正・縮小・終了されます。

## 解決するシナリオ

- 同じ失敗を繰り返さず、過去の結果に基づいて次の行動を選ぶ
- 成功した手順を、適用範囲を保ちながら別のタスクで再利用する
- 自己評価だけでなく、テスト結果や終了コードなどの根拠で行動指針を見直す

## 導入方法

APMを使う場合:

```sh
apm install owo-x-project/owlgrowth --target codex,claude
```

ソースから使う場合:

```sh
git clone https://github.com/owo-x-project/owlgrowth.git
cd owlgrowth
./bin/owlgrowth-mcp
```

## ライセンス

MITライセンス。詳細は [ライセンス本文](LICENSE) を参照してください。
