import numpy as np
from matrix_hw_wrapper import matrix_mul_hw  # Ensure this module exists and is in the same directory or PYTHONPATH

def main():
    """
    Tests the hardware-accelerated matrix multiplication function.

    - Generates random matrices A and B.
    - Computes their product using hardware (via matrix_mul_hw).
    - Prints input and output matrices.
    - Compares hardware result to NumPy's matmul for validation.
    - Prints whether the results match within a tolerance.
    """
    # Define test matrices A (M x K) and B (K x N)
    M, K, N = 10, 10, 10
    A = np.random.uniform(-2, 2, size=(M, K)).astype(np.float32)
    B = np.random.uniform(-2, 2, size=(K, N)).astype(np.float32)

    print("Input Matrix A:")
    print(A)
    print("\nInput Matrix B:")
    print(B)

    # Call hardware matrix multiplication
    C = matrix_mul_hw(A, B)

    print("\nOutput Matrix C (from Verilog via SPI):")
    print(C)

    # Compare with software matmul for validation
    C_expected = np.matmul(A, B)
    print("\nExpected Matrix C (from NumPy):")
    print(C_expected)

    # Optional: check error
    if np.allclose(C, C_expected, rtol=1e-3, atol=1e-3):
        print("\n✅ Hardware and software results match!")
    else:
        print("\n❌ Mismatch detected between hardware and software results!")

if __name__ == "__main__":
    main()
