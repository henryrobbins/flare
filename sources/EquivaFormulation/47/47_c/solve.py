import sys
import os
import lippy as lp

c_vec = [-1.0, -1.0]
a_matrix = [[-30.0, -20.0], [5.0, 4.0], [1.0, -1.0]]
b_vec = [-500.0, 90.0, 0.0]

gomory = lp.CuttingPlaneMethod(c_vec, a_matrix, b_vec, log_mode=lp.LogMode.MEDIUM_LOG)

# Redirect stdout to the log file
log_file_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "log.txt")
with open(log_file_path, "w") as f:
    sys.stdout = f
    gomory.solve()

# Reset stdout if needed
sys.stdout = sys.__stdout__
