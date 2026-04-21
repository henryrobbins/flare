\ LP format - for model browsing. Use MPS format to capture full model detail.
Minimize
  + 20 Constant
Subject To
 R0: 30 c + 40 p >= 2000
 R1: - 0.5 c + p <= 0
 R2: c >= 15
Bounds
 c >= 15
 Constant = 1
Generals
 c p
End
