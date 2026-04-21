\ LP format - for model browsing. Use MPS format to capture full model detail.
Minimize
  s + r
Subject To
 R0: - slack_0 + 20 s + 30 r = 500
 R1: slack_2 + 4 s + 5 r = 90
 R2: slack_1 - s + r = 0
Bounds
Generals
 s r
End
