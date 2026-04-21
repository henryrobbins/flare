\ LP format - for model browsing. Use MPS format to capture full model detail.
Minimize
  s_0 + 10 s_1 + r_0 + 10 r_1
Subject To
 R0: 20 s_0 + 200 s_1 + 30 r_0 + 300 r_1 >= 500
 R1: 4 s_0 + 40 s_1 + 5 r_0 + 50 r_1 <= 90
 R2: - s_0 - 10 s_1 + r_0 + 10 r_1 <= 0
Bounds
 s_0 <= 9
 s_1 <= 9
 r_0 <= 9
 r_1 <= 9
Generals
 s_0 s_1 r_0 r_1
End
