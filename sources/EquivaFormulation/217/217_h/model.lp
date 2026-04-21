\ LP format - for model browsing. Use MPS format to capture full model detail.
Minimize
  10 h1 + 6 d1 + 6 d2 + 10 h2
Subject To
 R0: h1 + d1 + d2 + h2 <= 150
 R1: d1 + d2 >= 10
 R2: - 0.3 h1 + 0.7 d1 + 0.7 d2 - 0.3 h2 <= 0
Bounds
Generals
 h1 d1 d2 h2
End
