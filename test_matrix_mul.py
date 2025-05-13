import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import numpy as np

@cocotb.test()
async def matrix_mul_test(dut):
    cocotb.log.info("Starting matrix_mul_test...")

    # Start clock: 10ns period
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())

    # Load input_buffer.txt
    with open("input_buffer.txt", "r") as f:
        lines = f.readlines()

    M = int(lines[0].split()[1])
    K = int(lines[1].split()[1])
    N = int(lines[2].split()[1])
    A_flat = list(map(float, lines[3].split()[1:]))
    B_flat = list(map(float, lines[4].split()[1:]))

    # Set dimensions
    dut.M_val.value = M
    dut.K_val.value = K
    dut.N_val.value = N

    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Load matrix_A and matrix_B
    for i, val in enumerate(A_flat):
        dut.matrix_A[i].value = int(val)
    for i, val in enumerate(B_flat):
        dut.matrix_B[i].value = int(val)

    # Start pulse
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    # Wait for done
    while dut.done.value == 0:
        await RisingEdge(dut.clk)

    # Read matrix_C
    C_flat = []
    for i in range(M * N):
        C_flat.append(int(dut.matrix_C[i].value))

    # Write output_buffer.txt
    with open("output_buffer.txt", "w") as f:
        f.write("C " + " ".join(map(str, C_flat)) + "\n")
