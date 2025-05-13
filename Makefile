# Makefile for cocotb simulation

TOPLEVEL_LANG = verilog

VERILOG_SOURCES = $(shell pwd)/RTL/MatrixMulEngine.v
TOPLEVEL = MatrixMulEngine
MODULE = test_matrix_mul

# Choose your simulator: iverilog or vcs
SIM = icarus
# EXTRA_ARGS += -y $(shell pwd)/RTL/
# For VCS, uncomment below:
# SIM = vcs
# ulimit -v $((4 * 1024 * 1024))  # 4 GB limit

include $(shell cocotb-config --makefiles)/Makefile.sim
