import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
import struct
import random

@cocotb.test()
async def matrixmul_spi_test(dut):
    """
    Cocotb test for SPI-based matrix multiplication hardware.

    Loads matrices A and B from 'input_buffer.txt', sends them to the DUT over SPI,
    waits for the multiplication to complete, triggers transmission of matrix C,
    receives the result over SPI, and writes it to 'output_buffer.txt'.
    """

    # --- Helper functions ---
    def float_to_hex(f):
        return struct.unpack('<I', struct.pack('<f', f))[0]

    def hex_to_float(h):
        return struct.unpack('<f', struct.pack('<I', h))[0]

    def encode_word_as_int(f):
        return struct.unpack('<I', struct.pack('<I', f))[0]

    def make_header(tag, rows, cols):
        return (tag << 24) | ((rows & 0xFFF) << 12) | (cols & 0xFFF)


    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    await Timer(100, units="ns")

    # Load matrix info from input_buffer.txt
    with open("input_buffer.txt", "r") as f:
        lines = f.readlines()

    M = int(lines[0].split()[1])
    K = int(lines[1].split()[1])
    N = int(lines[2].split()[1])
    A_flat = list(map(float, lines[3].split()[1:]))
    B_flat = list(map(float, lines[4].split()[1:]))

    # Reset DUT
    dut.rst_n.value = 0
    dut.cs_n.value = 1
    dut.sclk.value = 0
    dut.mosi.value = 0
    dut.send_c.value = 0
    await Timer(100, units="ns")
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test size: small for verification
    # M, K, N = 4, 4, 4
    dut.M_in.value = M
    dut.K_in.value = K
    dut.N_in.value = N

    # for i, val in enumerate(A_flat):
    #     dut._log.info(f"[INFO] A[{i}] = {val:.5f} = {float_to_hex(val):08x}")

    # --- Send A ---
    await spi_send_word(dut, encode_word_as_int(make_header(0x0A, M, K)))
    for word in A_flat:
        await spi_send_word(dut, float_to_hex(word))

    while True:
        # Wait for A to be loaded
        await RisingEdge(dut.clk)
        if dut.A_loaded.value.integer == 1:
            dut._log.info(f"Matrix A loaded: {dut.M_in.value.integer}x{dut.K_in.value.integer}")
            break

    # for i, val in enumerate(B_flat):
    #     dut._log.info(f"[INFO] B[{i}] = {val:.5f} = {float_to_hex(val):08x}")

    # --- Send B ---
    await spi_send_word(dut, encode_word_as_int(make_header(0x0B, K, N)))
    for word in B_flat:
        await spi_send_word(dut, float_to_hex(word))

    while True:
        await RisingEdge(dut.clk)
        if dut.B_loaded.value.integer == 1:
            dut._log.info(f"Matrix B loaded: {dut.K_in.value.integer}x{dut.N_in.value.integer}")
            break

    # --- Wait for matrix multiplication to complete ---
    dut._log.info("Waiting for mul_done...")
    while True:
        await RisingEdge(dut.clk)
        if dut.mul_done.value.integer == 1:
            dut._log.info("Matrix multiplication complete.")
            break

    # --- Trigger matrix C transmission ---
    dut.send_c.value = 1
    await Timer(20, units="ns")
    dut.send_c.value = 0

    # --- Receive matrix C from SPI ---
    received_C = []
    for _ in range(M * N):
        word = await spi_receive_word(dut)
        received_C.append(hex_to_float(word))

    with open("output_buffer.txt", "w") as f:
        f.write("C " + " ".join(map(str, received_C)) + "\n")

    dut._log.info(f"Received matrix C: {dut.M_in.value.integer}x{dut.N_in.value.integer}")

# --- SPI helpers ---
async def spi_send_word(dut, data):
    """
    Sends a 32-bit word to the DUT over SPI.

    Args:
        dut: The cocotb DUT object.
        data (int): 32-bit integer to send over SPI.
    """
    dut.cs_n.value = 0
    dut.mosi.value = 0
    dut.sclk.value = 0
    await Timer(10, units="ns")
    dut.sclk.value = 1
    await Timer(10, units="ns")
    for i in range(32):
        bit = (data >> (31 - i)) & 1
        dut.mosi.value = bit
        dut.sclk.value = 0
        await Timer(10, units="ns")
        dut.sclk.value = 1
        await Timer(10, units="ns")
    dut.sclk.value = 0
    dut.cs_n.value = 1
    dut.mosi.value = 0
    await Timer(40, units="ns")


async def spi_receive_word(dut):
    """
    Receives a 32-bit word from the DUT over SPI.

    Args:
        dut: The cocotb DUT object.

    Returns:
        int: The received 32-bit integer from SPI.
    """
    result = 0
    dut.cs_n.value = 0
    await Timer(10, units="ns")

    for i in range(32):
        dut.sclk.value = 0
        await Timer(10, units="ns")

        dut.sclk.value = 1
        await Timer(10, units="ns")

        await Timer(10, units="ns")
        try:
            bit = int(dut.miso.value)
            result = (result << 1) | bit
        except ValueError:
            bit = 0
            result = (result << 1) | bit

    dut.sclk.value = 0
    dut.cs_n.value = 1
    await Timer(40, units="ns")
    return result
