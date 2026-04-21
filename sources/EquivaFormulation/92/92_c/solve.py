import sys
import os
import lippy as lp

c_vec = [5.0, 3.0]
a_matrix = [[1.0, 1.0], [6.0, 3.0], [4.0, 2.0]]
b_vec = [150.0, 100.0, 30.0]

gomory = lp.CuttingPlaneMethod(c_vec, a_matrix, b_vec, log_mode=lp.LogMode.MEDIUM_LOG)

# Redirect stdout to the log file
log_file_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "log.txt")
with open(log_file_path, "w") as f:
    sys.stdout = f
    gomory.solve()

# Reset stdout if needed
sys.stdout = sys.__stdout__
