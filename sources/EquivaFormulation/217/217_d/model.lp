\ LP format - for model browsing. Use MPS format to capture full model detail.
Minimize
  10 h_0 + 100 h_1 + 6 d_0 + 60 d_1
Subject To
 R0: h_0 + 10 h_1 + d_0 + 10 d_1 <= 150
 R1: d_0 + 10 d_1 >= 10
 R2: - 0.3 h_0 - 3 h_1 + 0.7 d_0 + 7 d_1 <= 0
Bounds
 h_0 <= 9
 h_1 <= 9
 d_0 <= 9
 d_1 <= 9
Generals
 h_0 h_1 d_0 d_1
End
