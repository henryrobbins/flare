\ LP format - for model browsing. Use MPS format to capture full model detail.
Maximize
  5 n1[0] + 3 n1[1] + 5 n2[0] + 3 n2[1]
Subject To
 R0: n1[0] + n1[1] + n2[0] + n2[1] <= 150
 R1: 6 n1[0] + 3 n1[1] + 6 n2[0] + 3 n2[1] <= 100
 R2: 4 n1[0] + 2 n1[1] + 4 n2[0] + 2 n2[1] <= 30
Bounds
End
