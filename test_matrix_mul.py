import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import struct

@cocotb.test()
async def matrix_mul_test(dut):
    """
    Cocotb test for direct matrix multiplication hardware.

    Loads matrices A and B from 'input_buffer.txt', sets up the DUT with these matrices,
    triggers computation, waits for completion, reads the result matrix C, and writes it to 'output_buffer.txt'.
    """

    cocotb.log.info("Starting matrix_mul_test...")

    # Start the clock with 10ns period
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())

    # Load matrix info from input_buffer.txt
    with open("input_buffer.txt", "r") as f:
        lines = f.readlines()

    M = int(lines[0].split()[1])
    K = int(lines[1].split()[1])
    N = int(lines[2].split()[1])
    A_flat = list(map(float, lines[3].split()[1:]))
    B_flat = list(map(float, lines[4].split()[1:]))

    # Set matrix dimensions
    dut.M_val.value = M
    dut.K_val.value = K
    dut.N_val.value = N

    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Load matrix A and B using IEEE-754 encoding
    for i, val in enumerate(A_flat):
        dut.matrix_A[i].value = struct.unpack('I', struct.pack('f', val))[0]
    for i, val in enumerate(B_flat):
        dut.matrix_B[i].value = struct.unpack('I', struct.pack('f', val))[0]

    # Trigger the start signal
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    # Wait for computation to complete
    while dut.done.value == 0:
        await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)  # one extra to latch results

    # Read and decode matrix C
    C_flat = []
    for i in range(M * N):
        raw_val = dut.matrix_C[i].value.integer
        float_val = struct.unpack('f', struct.pack('I', raw_val))[0]
        C_flat.append(float_val)

    # Save results to file
    with open("output_buffer.txt", "w") as f:
        f.write("C " + " ".join(map(str, C_flat)) + "\n")

    cocotb.log.info("Matrix multiplication complete. Results written to output_buffer.txt.")
