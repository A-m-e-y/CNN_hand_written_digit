# Makefile for cocotb simulation

TOPLEVEL_LANG = verilog

VERILOG_SOURCES = $(shell pwd)/RTL/MatrixMulEngine.v \
                  $(shell pwd)/RTL/Compressor32.v \
                  $(shell pwd)/RTL/Compressor42.v \
                  $(shell pwd)/RTL/DotProductEngine.v \
                  $(shell pwd)/RTL/EACAdder.v \
                  $(shell pwd)/RTL/FullAdder.v \
                  $(shell pwd)/RTL/LeadingOneDetector_Top.v \
                  $(shell pwd)/RTL/MAC32_top.v \
                  $(shell pwd)/RTL/MatrixMul_top.v \
                  $(shell pwd)/RTL/MSBIncrementer.v \
                  $(shell pwd)/RTL/Normalizer.v \
                  $(shell pwd)/RTL/PISO_MatrixRegs.v \
                  $(shell pwd)/RTL/PreNormalizer.v \
                  $(shell pwd)/RTL/R4Booth.v \
                  $(shell pwd)/RTL/Rounder.v \
                  $(shell pwd)/RTL/SIPO_MatrixRegs.v \
                  $(shell pwd)/RTL/SpecialCaseDetector.v \
                  $(shell pwd)/RTL/WallaceTree.v \
                  $(shell pwd)/RTL/ZeroDetector_Base.v \
                  $(shell pwd)/RTL/ZeroDetector_Group.v
				  
TOPLEVEL = MatrixMulEngine
MODULE = test_matrix_mul

# Choose your simulator: iverilog or vcs
SIM = icarus
# EXTRA_ARGS += -y $(shell pwd)/RTL/
# For VCS, uncomment below:
# SIM = vcs
# ulimit -v $((4 * 1024 * 1024))  # 4 GB limit

include $(shell cocotb-config --makefiles)/Makefile.sim
