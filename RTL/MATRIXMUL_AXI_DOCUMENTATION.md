# MatrixMul AXI Wrapper - Documentation

## Overview

This is an AXI4-Lite wrapper for the MatrixMulEngine, designed to be used as a hardware accelerator co-processor with MicroBlaze or other RISC-V cores in an FPGA.

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                matrixmul_axi_wrapper (TOP)              │
│                                                          │
│  ┌────────────────┐      ┌──────────────────────┐     │
│  │                │      │  Dual-Port BRAMs     │     │
│  │  AXI4-Lite     │◄────►│  - Matrix A (MxK)    │     │
│  │  Slave         │      │  - Matrix B (KxN)    │     │
│  │  Interface     │      │  - Matrix C (MxN)    │     │
│  │                │      │                      │     │
│  └────────────────┘      └──────┬───────────────┘     │
│                                  │                      │
│                          ┌───────▼──────────┐          │
│                          │ MatrixMulEngine  │          │
│                          │    (BRAM Ver)    │          │
│                          └──────────────────┘          │
└─────────────────────────────────────────────────────────┘
```

## Module Hierarchy

1. **matrixmul_axi_wrapper.v** - Top-level module with AXI4-Lite interface
2. **matrixmul_axi_slave.v** - AXI4-Lite protocol implementation
3. **MatrixMulEngine_BRAM.v** - Modified engine with BRAM-style ports
4. **dual_port_bram** - Synthesizable dual-port Block RAM

## Memory Map

| Address | Register Name          | Access | Description                                    |
|---------|------------------------|--------|------------------------------------------------|
| 0x00    | CONTROL_REG            | R/W    | Control register for engine operations         |
| 0x04    | STATUS_REG             | R      | Status register (done, busy flags)             |
| 0x08    | M_DIM_REG              | R/W    | M dimension (rows of A, rows of C)             |
| 0x0C    | K_DIM_REG              | R/W    | K dimension (cols of A, rows of B)             |
| 0x10    | N_DIM_REG              | R/W    | N dimension (cols of B, cols of C)             |
| 0x14    | MEM_ADDR_REG           | R/W    | Memory address for data access                 |
| 0x18    | MEM_WDATA_REG          | W      | Memory write data (triggers write)             |
| 0x1C    | MEM_RDATA_REG          | R      | Memory read data (read after addr set)         |

### Register Bit Fields

#### CONTROL_REG (0x00)
```
Bit [31:4] - Reserved
Bit [3:2]  - MEM_SEL: Memory select
             00 = Matrix A
             01 = Matrix B  
             10 = Matrix C
             11 = Reserved
Bit [1]    - RESET: Software reset (not implemented yet)
Bit [0]    - START: Write 1 to start computation (auto-clears)
```

#### STATUS_REG (0x04)
```
Bit [31:3] - Reserved
Bit [2]    - ERROR: Error flag (not implemented yet)
Bit [1]    - BUSY: Engine is computing (1 = busy, 0 = idle)
Bit [0]    - DONE: Computation complete (1 = done, 0 = not done)
```

## Usage Flow

### 1. Initialize Dimensions
```
1. Write M dimension to M_DIM_REG (0x08)
2. Write K dimension to K_DIM_REG (0x0C)
3. Write N dimension to N_DIM_REG (0x10)
```

### 2. Load Matrix A
```
For each element in Matrix A (row-major order):
    1. Set MEM_SEL = 00 in CONTROL_REG
    2. Write element address to MEM_ADDR_REG (0x14)
    3. Write element value to MEM_WDATA_REG (0x18)
```

### 3. Load Matrix B
```
For each element in Matrix B (row-major order):
    1. Set MEM_SEL = 01 in CONTROL_REG
    2. Write element address to MEM_ADDR_REG (0x14)
    3. Write element value to MEM_WDATA_REG (0x18)
```

### 4. Start Computation
```
1. Write START bit (bit 0) in CONTROL_REG to 1
```

### 5. Poll for Completion
```
1. Read STATUS_REG (0x04)
2. Check DONE bit (bit 0)
3. Wait until DONE = 1
```

### 6. Read Result Matrix C
```
For each element in Matrix C (row-major order):
    1. Set MEM_SEL = 10 in CONTROL_REG
    2. Write element address to MEM_ADDR_REG (0x14)
    3. Read element value from MEM_RDATA_REG (0x1C)
```

## C Driver Example for MicroBlaze

### Header File (matrixmul_hw.h)

```c
#ifndef MATRIXMUL_HW_H
#define MATRIXMUL_HW_H

#include <stdint.h>
#include <stdbool.h>

// Register offsets
#define MATRIXMUL_CONTROL_REG_OFFSET    0x00
#define MATRIXMUL_STATUS_REG_OFFSET     0x04
#define MATRIXMUL_M_DIM_REG_OFFSET      0x08
#define MATRIXMUL_K_DIM_REG_OFFSET      0x0C
#define MATRIXMUL_N_DIM_REG_OFFSET      0x10
#define MATRIXMUL_MEM_ADDR_REG_OFFSET   0x14
#define MATRIXMUL_MEM_WDATA_REG_OFFSET  0x18
#define MATRIXMUL_MEM_RDATA_REG_OFFSET  0x1C

// Control register bits
#define MATRIXMUL_CTRL_START_MASK       0x00000001
#define MATRIXMUL_CTRL_RESET_MASK       0x00000002
#define MATRIXMUL_CTRL_MEMSEL_MASK      0x0000000C
#define MATRIXMUL_CTRL_MEMSEL_A         0x00000000
#define MATRIXMUL_CTRL_MEMSEL_B         0x00000004
#define MATRIXMUL_CTRL_MEMSEL_C         0x00000008

// Status register bits
#define MATRIXMUL_STATUS_DONE_MASK      0x00000001
#define MATRIXMUL_STATUS_BUSY_MASK      0x00000002
#define MATRIXMUL_STATUS_ERROR_MASK     0x00000004

// Maximum dimensions (change to match RTL parameters)
#define MATRIXMUL_MAX_M                 16
#define MATRIXMUL_MAX_K                 16
#define MATRIXMUL_MAX_N                 16

// Helper macros for register access
#define MATRIXMUL_WRITE_REG(base, offset, val) \
    (*((volatile uint32_t *)((base) + (offset))) = (val))

#define MATRIXMUL_READ_REG(base, offset) \
    (*((volatile uint32_t *)((base) + (offset))))

// Function prototypes
void matrixmul_set_dimensions(uint32_t base_addr, uint32_t m, uint32_t k, uint32_t n);
void matrixmul_write_matrix_a(uint32_t base_addr, const float *matrix, uint32_t m, uint32_t k);
void matrixmul_write_matrix_b(uint32_t base_addr, const float *matrix, uint32_t k, uint32_t n);
void matrixmul_start(uint32_t base_addr);
bool matrixmul_is_done(uint32_t base_addr);
void matrixmul_wait_done(uint32_t base_addr);
void matrixmul_read_matrix_c(uint32_t base_addr, float *matrix, uint32_t m, uint32_t n);
int matrixmul_compute(uint32_t base_addr, const float *A, const float *B, float *C,
                      uint32_t m, uint32_t k, uint32_t n);

#endif // MATRIXMUL_HW_H
```

### Implementation File (matrixmul_hw.c)

```c
#include "matrixmul_hw.h"
#include <string.h>

// Helper function to convert float to 32-bit representation
static inline uint32_t float_to_uint32(float f) {
    union {
        float f;
        uint32_t u;
    } converter;
    converter.f = f;
    return converter.u;
}

// Helper function to convert 32-bit to float representation
static inline float uint32_to_float(uint32_t u) {
    union {
        float f;
        uint32_t u;
    } converter;
    converter.u = u;
    return converter.f;
}

/**
 * Set matrix dimensions
 */
void matrixmul_set_dimensions(uint32_t base_addr, uint32_t m, uint32_t k, uint32_t n) {
    MATRIXMUL_WRITE_REG(base_addr, MATRIXMUL_M_DIM_REG_OFFSET, m);
    MATRIXMUL_WRITE_REG(base_addr, MATRIXMUL_K_DIM_REG_OFFSET, k);
    MATRIXMUL_WRITE_REG(base_addr, MATRIXMUL_N_DIM_REG_OFFSET, n);
}

/**
 * Write Matrix A to hardware (row-major order)
 */
void matrixmul_write_matrix_a(uint32_t base_addr, const float *matrix, uint32_t m, uint32_t k) {
    uint32_t control = MATRIXMUL_CTRL_MEMSEL_A;
    MATRIXMUL_WRITE_REG(base_addr, MATRIXMUL_CONTROL_REG_OFFSET, control);
    
    for (uint32_t i = 0; i < m * k; i++) {
        MATRIXMUL_WRITE_REG(base_addr, MATRIXMUL_MEM_ADDR_REG_OFFSET, i);
        MATRIXMUL_WRITE_REG(base_addr, MATRIXMUL_MEM_WDATA_REG_OFFSET, float_to_uint32(matrix[i]));
    }
}

/**
 * Write Matrix B to hardware (row-major order)
 */
void matrixmul_write_matrix_b(uint32_t base_addr, const float *matrix, uint32_t k, uint32_t n) {
    uint32_t control = MATRIXMUL_CTRL_MEMSEL_B;
    MATRIXMUL_WRITE_REG(base_addr, MATRIXMUL_CONTROL_REG_OFFSET, control);
    
    for (uint32_t i = 0; i < k * n; i++) {
        MATRIXMUL_WRITE_REG(base_addr, MATRIXMUL_MEM_ADDR_REG_OFFSET, i);
        MATRIXMUL_WRITE_REG(base_addr, MATRIXMUL_MEM_WDATA_REG_OFFSET, float_to_uint32(matrix[i]));
    }
}

/**
 * Start computation
 */
void matrixmul_start(uint32_t base_addr) {
    uint32_t control = MATRIXMUL_CTRL_START_MASK;
    MATRIXMUL_WRITE_REG(base_addr, MATRIXMUL_CONTROL_REG_OFFSET, control);
}

/**
 * Check if computation is done
 */
bool matrixmul_is_done(uint32_t base_addr) {
    uint32_t status = MATRIXMUL_READ_REG(base_addr, MATRIXMUL_STATUS_REG_OFFSET);
    return (status & MATRIXMUL_STATUS_DONE_MASK) != 0;
}

/**
 * Wait for computation to complete
 */
void matrixmul_wait_done(uint32_t base_addr) {
    while (!matrixmul_is_done(base_addr)) {
        // Polling loop
    }
}

/**
 * Read result Matrix C from hardware (row-major order)
 */
void matrixmul_read_matrix_c(uint32_t base_addr, float *matrix, uint32_t m, uint32_t n) {
    uint32_t control = MATRIXMUL_CTRL_MEMSEL_C;
    MATRIXMUL_WRITE_REG(base_addr, MATRIXMUL_CONTROL_REG_OFFSET, control);
    
    for (uint32_t i = 0; i < m * n; i++) {
        MATRIXMUL_WRITE_REG(base_addr, MATRIXMUL_MEM_ADDR_REG_OFFSET, i);
        uint32_t data = MATRIXMUL_READ_REG(base_addr, MATRIXMUL_MEM_RDATA_REG_OFFSET);
        matrix[i] = uint32_to_float(data);
    }
}

/**
 * Complete matrix multiplication: C = A * B
 * Returns 0 on success, -1 on error
 */
int matrixmul_compute(uint32_t base_addr, const float *A, const float *B, float *C,
                      uint32_t m, uint32_t k, uint32_t n) {
    // Validate dimensions
    if (m > MATRIXMUL_MAX_M || k > MATRIXMUL_MAX_K || n > MATRIXMUL_MAX_N) {
        return -1;
    }
    
    // Set dimensions
    matrixmul_set_dimensions(base_addr, m, k, n);
    
    // Load input matrices
    matrixmul_write_matrix_a(base_addr, A, m, k);
    matrixmul_write_matrix_b(base_addr, B, k, n);
    
    // Start computation
    matrixmul_start(base_addr);
    
    // Wait for completion
    matrixmul_wait_done(base_addr);
    
    // Read result
    matrixmul_read_matrix_c(base_addr, C, m, n);
    
    return 0;
}
```

### Example Application (main.c)

```c
#include <stdio.h>
#include "matrixmul_hw.h"
#include "xparameters.h"  // Xilinx BSP header

// Base address of the MatrixMul IP core (from Vivado address editor)
#define MATRIXMUL_BASEADDR XPAR_MATRIXMUL_AXI_WRAPPER_0_S00_AXI_BASEADDR

int main() {
    printf("MatrixMul Hardware Accelerator Test\n");
    printf("====================================\n\n");
    
    // Example: 4x4 matrix multiplication
    uint32_t m = 4, k = 4, n = 4;
    
    // Input matrices (row-major order)
    float A[16] = {
        1.0f, 2.0f, 3.0f, 4.0f,
        5.0f, 6.0f, 7.0f, 8.0f,
        9.0f, 10.0f, 11.0f, 12.0f,
        13.0f, 14.0f, 15.0f, 16.0f
    };
    
    float B[16] = {
        1.0f, 0.0f, 0.0f, 0.0f,
        0.0f, 1.0f, 0.0f, 0.0f,
        0.0f, 0.0f, 1.0f, 0.0f,
        0.0f, 0.0f, 0.0f, 1.0f
    };
    
    float C[16];
    
    printf("Computing C = A * B...\n");
    
    // Perform matrix multiplication
    int result = matrixmul_compute(MATRIXMUL_BASEADDR, A, B, C, m, k, n);
    
    if (result != 0) {
        printf("Error: Matrix multiplication failed!\n");
        return -1;
    }
    
    printf("Computation complete!\n\n");
    
    // Print result
    printf("Result Matrix C:\n");
    for (uint32_t i = 0; i < m; i++) {
        for (uint32_t j = 0; j < n; j++) {
            printf("%8.2f ", C[i * n + j]);
        }
        printf("\n");
    }
    
    return 0;
}
```

## Integration Steps in Vivado

### 1. Add IP to Vivado Block Design
```
1. Tools → Create and Package New IP
2. Select "Create a new AXI4 peripheral"
3. Use the generated files or import matrixmul_axi_wrapper.v as top
4. Add all required source files to IP sources
```

### 2. Configure IP Parameters
```
- Set MAX_M, MAX_K, MAX_N as desired
- Keep C_S00_AXI_DATA_WIDTH = 32
- Keep C_S00_AXI_ADDR_WIDTH = 8 (supports up to 256 registers)
```

### 3. Connect in Block Design
```
1. Add MicroBlaze or RISC-V processor
2. Add MatrixMul IP core
3. Connect AXI interfaces:
   - Processor M_AXI → AXI Interconnect → MatrixMul S_AXI
   - Connect clocks and resets
4. Assign address (e.g., 0x44A0_0000)
```

### 4. Generate Bitstream and Export Hardware
```
1. Generate bitstream
2. File → Export → Export Hardware (include bitstream)
3. Launch Vitis IDE
```

### 5. Create Application in Vitis
```
1. Create Application Project
2. Add matrixmul_hw.h and matrixmul_hw.c to project
3. Write application using the provided API
4. Build and run on hardware
```

## Performance Notes

- **POC Configuration**: 16x16x16 matrices
- **Memory**: ~3KB BRAM (768 x 32-bit words)
- **Latency**: Depends on K dimension (K multiply-accumulate operations per element)
- **Throughput**: One result element per (K + overhead) cycles

## Scaling Up

To use larger matrices, modify parameters in `matrixmul_axi_wrapper.v`:

```verilog
parameter MAX_M = 64,   // Increase as needed
parameter MAX_K = 64,
parameter MAX_N = 64
```

**Memory requirements**: (M×K + K×N + M×N) × 4 bytes

Examples:
- 16×16×16: 3 KB
- 32×32×32: 12 KB
- 64×64×64: 48 KB
- 128×128×128: 192 KB

## Troubleshooting

### Synthesis Issues
- Ensure all .v files are added to project sources
- Check that DotProductEngine.v is in the file list
- Verify parameter propagation in hierarchy

### Functional Issues
- Check address assignment in Vivado Address Editor
- Verify xparameters.h has correct base address
- Use ILA (Integrated Logic Analyzer) to debug AXI transactions
- Add debug prints in C code to trace execution

### Performance Issues
- Consider pipelining the DotProductEngine
- Use AXI4-Full with DMA for large matrix transfers
- Add interrupt support instead of polling

## Future Enhancements

1. **Interrupt Support**: Add IRQ line to signal completion
2. **DMA Integration**: Use AXI4-Full with DMA for faster data transfer
3. **Multiple Engines**: Instantiate multiple MatrixMulEngines for parallelism
4. **Error Checking**: Add overflow detection and error reporting
5. **Burst Transfers**: Optimize AXI transfers with burst mode
6. **Float16 Support**: Reduce memory footprint with half-precision
