import numpy as np
import subprocess
import time
import os

def matrix_mul_hw(A, B):
    """
    Performs matrix multiplication using hardware via a cocotb testbench.

    Writes matrices A and B to 'input_buffer.txt', invokes the cocotb testbench using 'make',
    waits for the result in 'output_buffer.txt', and reads the resulting matrix C.

    Args:
        A (np.ndarray): Input matrix of shape (M, K).
        B (np.ndarray): Input matrix of shape (K, N).

    Returns:
        np.ndarray: Resulting matrix C of shape (M, N).
    """
    M, K = A.shape
    K2, N = B.shape

    if K != K2:
        raise ValueError(f"Matrix shape mismatch: A is {A.shape}, B is {B.shape} (K != K2)")

    # Flatten data and write to input_buffer.txt
    with open("input_buffer.txt", "w") as f:
        f.write(f"M {M}\n")
        f.write(f"K {K}\n")
        f.write(f"N {N}\n")
        f.write("A " + " ".join(map(str, A.flatten())) + "\n")
        f.write("B " + " ".join(map(str, B.flatten())) + "\n")

    # Run cocotb testbench via Makefile
    make_cmd = ["make"]
    subprocess.run(make_cmd, check=True)

    # Wait for output_buffer.txt
    while not os.path.exists("output_buffer.txt"):
        time.sleep(0.1)

    # Read result matrix C
    with open("output_buffer.txt", "r") as f:
        line = f.readline()
        assert line.startswith("C ")
        values = list(map(float, line.strip().split()[1:]))
        C = np.array(values).reshape(M, N)

    return C
