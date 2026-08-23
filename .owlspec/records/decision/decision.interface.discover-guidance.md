+++
version = 2
id = "decision.interface.discover-guidance"
kind = "decision"

[[relations]]
type = "constrained_by"
to = "constraint.tool.low-cognitive-load"
+++

# discoverで利用判断を支援する

OwlGrowthには、MCPを使うべき場面、各toolへの簡単なルーティング、書き込みとEvidenceに関する基本規範を説明するread-onlyのdiscoverを設ける。discoverは実際の処理を行わず、tool選択に迷ったときにも再確認できる案内にする。

各toolの長い説明だけに依存して利用方法を伝える案は、toolが増減したときに全体の利用判断を把握しにくくなるため採用しない。
