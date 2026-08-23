+++
version = 2
id = "decision.boundary.memory-context"
kind = "decision"
+++

# MemoryとContext基盤とは責務を分けて併用する

Claude Code Memoryや一般的なエージェントメモリの主目的は必要な情報を次のセッションでも覚えること、LeanCTXなどのContext基盤の主目的は必要なコンテキストや過去情報を効率的に取得することである。OwlGrowthは経験の結果によって次の行動方法を変える責務を持ち、Memory基盤やContext基盤そのものと競合せず併用可能とする。
