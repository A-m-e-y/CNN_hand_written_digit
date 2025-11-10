# MatrixMul AXI Wrapper - Quick Start

## Files Created

### RTL Files
1. **matrixmul_axi_wrapper.v** - Top-level AXI4-Lite wrapper module
2. **matrixmul_axi_slave.v** - AXI4-Lite slave interface implementation
3. **MatrixMulEngine_BRAM.v** - Modified MatrixMulEngine with BRAM-style ports
4. **MATRIXMUL_AXI_DOCUMENTATION.md** - Complete documentation with C driver

## Quick Integration

### 1. Add Files to Vivado Project
Add all three .v files to your Vivado project sources:
- matrixmul_axi_wrapper.v (set as top)
- matrixmul_axi_slave.v
- MatrixMulEngine_BRAM.v
- DotProductEngine.v (your existing file)

### 2. Parameters (in matrixmul_axi_wrapper.v)
```verilog
parameter MAX_M = 16,  // Start with 16x16 for POC
parameter MAX_K = 16,
parameter MAX_N = 16
```

### 3. Top Module Ports
The wrapper exposes standard AXI4-Lite interface:
- Clock: s00_axi_aclk
- Reset: s00_axi_aresetn (active low)
- AXI4-Lite signals: s00_axi_*

### 4. Memory Map Summary
| Address | Register | Function |
|---------|----------|----------|
| 0x00 | CONTROL | Start bit + Memory select |
| 0x04 | STATUS | Done/Busy flags |
| 0x08 | M_DIM | M dimension |
| 0x0C | K_DIM | K dimension |
| 0x10 | N_DIM | N dimension |
| 0x14 | MEM_ADDR | Memory address |
| 0x18 | MEM_WDATA | Write data (triggers write) |
| 0x1C | MEM_RDATA | Read data |

## C Code Integration

Copy these files to your Vitis workspace:
- matrixmul_hw.h
- matrixmul_hw.c

Basic usage:
```c
#include "matrixmul_hw.h"

float A[16], B[16], C[16];  // 4x4 matrices
// ... initialize A and B ...

// Compute C = A * B
matrixmul_compute(BASEADDR, A, B, C, 4, 4, 4);
```

## Design Features

✅ **Synthesizable** - No 2D arrays on top-level ports  
✅ **Standard AXI4-Lite** - Compatible with Xilinx IP Integrator  
✅ **Dual-Port BRAMs** - Efficient memory architecture  
✅ **Scalable** - Adjust MAX_M/K/N parameters  
✅ **Simple API** - Easy C driver for MicroBlaze/RISC-V  

## Testing Strategy

### Simulation
1. Create testbench to exercise AXI transactions
2. Load test matrices
3. Verify computation results
4. Check timing and handshaking

### Hardware
1. Use small matrices (4x4) initially
2. Verify with identity matrix multiplication
3. Compare with software computation
4. Test larger matrices incrementally

## Memory Requirements

| Size | A | B | C | Total |
|------|---|---|---|-------|
| 16×16 | 1KB | 1KB | 1KB | 3KB |
| 32×32 | 4KB | 4KB | 4KB | 12KB |
| 64×64 | 16KB | 16KB | 16KB | 48KB |

## Next Steps

1. **Simulate** - Create AXI testbench
2. **Synthesize** - Check resource utilization
3. **Integrate** - Add to block design with MicroBlaze
4. **Test** - Run example C application
5. **Scale** - Increase matrix dimensions
6. **Optimize** - Add DMA, interrupts, pipelining

## Architecture Benefits

This design solves the 2D array problem by:
- Using dual-port BRAMs instead of 2D ports
- Providing sequential access via address/data registers
- Keeping matrix storage internal to the module
- Exposing only standard AXI4-Lite interface

The AXI interface allows:
- Easy integration with any AXI master (MicroBlaze, RISC-V, ARM)
- Standard IP packaging in Vivado
- Software control from C/C++ applications
- Use as a co-processor accelerator

## Support

See MATRIXMUL_AXI_DOCUMENTATION.md for:
- Detailed register specifications
- Complete C driver implementation
- Example applications
- Vivado integration steps
- Troubleshooting guide
