# CNN_hand_written_digit

This project implements a handwritten digit recognition system using a Convolutional Neural Network (CNN) with a unique hardware/software co-design. The core matrix multiplication operations of the CNN are offloaded to a custom Verilog hardware accelerator, which is simulated and tested via Python using cocotb and a custom SPI protocol. The project is structured to allow easy switching between pure software and hardware-accelerated matrix operations.

---

## Table of Contents

- [Project Overview](#project-overview)
- [High-Level Architecture](#high-level-architecture)
- [How to run the flow](#how-to-run-the-flow)
- [Python Software Stack](#python-software-stack)
  - [Neural Network Layers](#neural-network-layers)
  - [Hardware Integration](#hardware-integration)
  - [Training and Inference](#training-and-inference)
  - [Python File-by-File Breakdown](#python-file-by-file-breakdown)
- [RTL Hardware Stack](#rtl-hardware-stack)
  - [Top-Level RTL Modules](#top-level-rtl-modules)
  - [RTL File-by-File Breakdown](#rtl-file-by-file-breakdown)
- [Python ↔ RTL Integration](#python--rtl-integration)
  - [SPI Protocol and Data Exchange](#spi-protocol-and-data-exchange)
  - [Simulation Flow](#simulation-flow)
- [Testbenches and Verification](#testbenches-and-verification)
- [Build and Run Instructions](#build-and-run-instructions)
- [File Map](#file-map)
- [References](#references)

---

## Project Overview

This project demonstrates a hybrid software/hardware approach to CNN-based handwritten digit recognition. The CNN is implemented in Python (NumPy), but all matrix multiplications (the computational bottleneck in CNNs) are offloaded to a custom-designed hardware accelerator written in Verilog. The hardware is simulated using cocotb, and Python communicates with the hardware via a simulated SPI protocol.

---

## High-Level Architecture

```
+--------------------+      SPI (via cocotb)      +---------------------+
|   Python (NumPy)   | <----------------------->  |   Verilog RTL Core  |
|  CNN + Driver Code |                            |  (MatrixMul Engine) |
+--------------------+                            +---------------------+
         |                                                 |
         | 1. Prepares matrices (A, B)                     |
         | 2. Sends over SPI (simulated)                   |
         | 3. Waits for result (C)                         |
         | 4. Receives C over SPI                          |
         |                                                 |
         +----------------- cocotb testbench --------------+
```

---

## How to run the flow
- Ensure you have the required Python packages installed.
- Train the CNN model:
  ```
  python CNN_digit_recognizer.py train
  ```
- For training the model, you need a dataset of handwritten digits (e.g., MNIST).
- Edit the `CNN_digit_recognizer.py` line no 12 with variable `DATA_DIR` to point to your dataset.
- Dataset should be structured with images in subdirectories named by their labels (e.g., `0/`, `1/`, ..., `9/`).
- Script will automatically load images, preprocess them, and train the CNN.
- Script will save the trained model to `trained_model.pkl` in cwd.
- For training, script will use `matrix_mul_sw`, `matrix_mul_hw` will be used only for inference.
- For inference, run:
  ```
  python CNN_digit_recognizer.py infer path_to_image.jpg
  ```
- Replace `path_to_image.jpg` with the path to an image of a handwritten digit.
- The script will preprocess the image, run it through the trained CNN, and print the predicted digit.


## Python Software Stack

### Neural Network Layers

The CNN is implemented from scratch using NumPy, with the following layers:

- **Conv2D**: Convolutional layer, offloads matrix multiplication to hardware.
- **ReLU**: Activation function.
- **Flatten**: Flattens 4D tensors to 2D for dense layers.
- **Dense**: Fully connected layer, also offloads matrix multiplication to hardware.
- **Softmax**: Output activation for classification.

### Hardware Integration

- **matrix_hw_wrapper.py**: Provides the `matrix_mul_hw` function, which:
  - Serializes matrices A and B to `input_buffer.txt`.
  - Invokes the cocotb/Verilog simulation via `make`.
  - Waits for `output_buffer.txt` with result matrix C.
  - Reads and returns C as a NumPy array.

- **conv2d.py** and **dense.py**: Both use `matrix_mul_hw` for their core matrix multiplication, thus transparently offloading heavy computation to hardware.

### Training and Inference

- **CNN_digit_recognizer.py**: Main script for training and inference.
  - Loads images, preprocesses, trains the CNN, or runs inference.
  - During forward/backward passes, all matrix multiplications are performed by the hardware accelerator.

- **simple_cnn.py**: Defines the CNN architecture and serialization logic.


### Python File-by-File Breakdown

#### `CNN_digit_recognizer.py`
- Main entry point for training and inference.
- Loads images, handles data preprocessing, batching, and evaluation.
- Calls into `SimpleCNN` for model operations.

#### `simple_cnn.py`
- Implements the `SimpleCNN` class, which wires together all layers.
- Handles forward and backward propagation, as well as model save/load.

#### `conv2d.py`
- Implements the convolutional layer.
- Converts convolution into matrix multiplication (im2col), then calls `matrix_mul_hw`.
- Handles bias addition and output reshaping.

#### `dense.py`
- Implements the fully connected layer.
- Calls `matrix_mul_hw` for matrix multiplication.

#### `flatten.py`
- Implements the flattening operation between convolutional and dense layers.

#### `relu_softmax.py`
- Implements ReLU and Softmax activation functions.

#### `neuron.py`
- Implements a single neuron (not used in main CNN, but useful for extension).

#### `matrix_hw_wrapper.py`
- Handles all communication with the hardware accelerator.
- Serializes matrices to `input_buffer.txt`, invokes cocotb/Verilog simulation, and reads results from `output_buffer.txt`.

#### `do_matrix_mul.py`
- Standalone script to test hardware matrix multiplication.
- Generates random matrices, calls `matrix_mul_hw`, and compares results to NumPy.

#### `run_profiler.py`
- Profiles the inference function for performance analysis.

#### `test_matrix_mul_spi.py`
- cocotb testbench for end-to-end SPI-based matrix multiplication.
- Drives the Verilog hardware with matrices from `input_buffer.txt` and writes results to `output_buffer.txt`.

#### `input_buffer.txt` / `output_buffer.txt`
- Temporary files for passing matrix data between Python and the hardware simulation.

---

## RTL Hardware Stack

### Top-Level RTL Modules

- **MatrixMul_top.v**: Top-level module for matrix multiplication accelerator. Handles SPI communication, matrix loading, computation, and result sending.
- **MatrixMulEngine.v**: Implements the actual matrix multiplication FSM, orchestrating dot products using the DotProductEngine.
- **DotProductEngine.v**: Computes the dot product of two vectors using a pipelined MAC unit.
- **MAC32_top.v**: Implements a 32-bit floating-point multiply-accumulate (MAC) unit, supporting IEEE-754 arithmetic.
- **SPI Protocol Modules**: `spi_master.v`, `spi_slave.v`, `spi_matrix_loader.v`, `spi_matrix_sender.v` handle SPI communication for loading matrices and sending results.

### RTL File-by-File Breakdown

#### Top-Level and Integration

- **MatrixMul_top.v**: 
  - Instantiates SPI loader, matrix multiplication engine, and SPI sender.
  - Coordinates loading of matrices A and B, triggers computation, and sends matrix C over SPI.

- **MatrixMulEngine.v**:
  - FSM that iterates over rows and columns, invoking the DotProductEngine for each output element.
  - Handles matrix addressing and result storage.

- **DotProductEngine.v**:
  - FSM that fetches elements from patch/filter memories, performs dot product using MAC32_top, and accumulates results.

#### Floating-Point Arithmetic Pipeline

- **MAC32_top.v**:
  - Implements a pipelined IEEE-754 floating-point MAC.
  - Handles normalization, rounding, special cases (NaN, Inf, Zero), and denormalized numbers.
  - Uses submodules for Booth encoding, Wallace tree reduction, normalization, and rounding.

- **R4Booth.v**: Radix-4 Booth multiplier for partial product generation.
- **WallaceTree.v**: Wallace tree adder for fast summation of partial products.
- **EACAdder.v**, **FullAdder.v**, **Compressor32.v**, **Compressor42.v**: Various adder/compressor modules for fast arithmetic.
- **LeadingOneDetector_Top.v**: Detects leading ones for normalization.
- **Normalizer.v**, **PreNormalizer.v**, **Rounder.v**: Handle normalization and rounding of floating-point results.
- **SpecialCaseDetector.v**: Detects special floating-point cases (NaN, Inf, Zero, Denorm).

#### SPI and Matrix I/O

- **spi_master.v**, **spi_slave.v**: SPI protocol logic for master/slave communication.
- **spi_matrix_loader.v**: Receives matrices A and B over SPI, parses headers, and stores data.
- **spi_matrix_sender.v**: Sends matrix C over SPI after computation.
- **SIPO_MatrixRegs.v**, **PISO_MatrixRegs.v**: Serial-in/parallel-out and parallel-in/serial-out registers for matrix data.

#### Testbenches

- **tb_DotProductEngine_basic.v**, **tb_DotProductEngine.v**: Testbenches for the dot product engine.
- **tb_MatrixMulEngine.v**: Testbench for the matrix multiplication engine, generates random matrices, and checks results.
- **tb_spi_top.v**: Testbench for the full SPI roundtrip.

---

## Python ↔ RTL Integration

### SPI Protocol and Data Exchange

- **Data Flow**:
  1. Python writes matrices A and B to `input_buffer.txt`.
  2. Python invokes the cocotb testbench via `make`.
  3. The cocotb testbench (`test_matrix_mul_spi.py`) reads `input_buffer.txt`, drives the SPI signals to the Verilog hardware, and loads matrices A and B.
  4. The hardware computes matrix C.
  5. The testbench triggers the hardware to send matrix C over SPI.
  6. The testbench writes matrix C to `output_buffer.txt`.
  7. Python reads `output_buffer.txt` and returns C as a NumPy array.

- **SPI Protocol**:
  - Each matrix is preceded by a header word indicating which matrix (A or B), and its dimensions.
  - Data is sent/received 32 bits at a time, MSB first.
  - Matrix C is sent back in the same order.

### Simulation Flow

1. **Python** calls `matrix_mul_hw(A, B)`.
2. **matrix_hw_wrapper.py** writes `input_buffer.txt`, runs `make` (which launches cocotb and Verilog simulation).
3. **test_matrix_mul_spi.py** (cocotb) reads `input_buffer.txt`, drives SPI to load A and B, waits for computation, triggers C transmission, and writes `output_buffer.txt`.
4. **Python** reads `output_buffer.txt` and continues computation.

---

## Testbenches and Verification

- **tb_MatrixMulEngine.v**: Verifies matrix multiplication logic with random matrices, dumps results for comparison.
- **tb_DotProductEngine_basic.v**, **tb_DotProductEngine.v**: Test dot product and MAC units with known and random vectors.
- **tb_spi_top.v**: Verifies SPI roundtrip between devices.
- **test_matrix_mul_spi.py**: End-to-end testbench for Python ↔ SPI ↔ Verilog integration.

---

## Build and Run Instructions

### Prerequisites

- Python 3.x with NumPy, PIL, cocotb, etc.
- Icarus Verilog (for simulation)
- cocotb (for Python-driven simulation)
- Make

### Running Matrix Multiplication (Python ↔ Verilog)

1. Prepare your matrices in Python.
2. Call `matrix_mul_hw(A, B)` from Python.
3. The hardware simulation will run automatically and return the result.

### Training and Inference

- **Training**:
  ```
  python CNN_digit_recognizer.py train
  ```
- **Inference**:
  ```
  python CNN_digit_recognizer.py infer path_to_image.jpg
  ```

### Standalone Matrix Test

- Run `do_matrix_mul.py` to test hardware matrix multiplication and compare with NumPy.

---

## File Map

### Python

- `CNN_digit_recognizer.py` - Main script for training/inference.
- `simple_cnn.py` - CNN architecture.
- `conv2d.py` - Convolutional layer.
- `dense.py` - Dense layer.
- `flatten.py` - Flatten layer.
- `relu_softmax.py` - Activation functions.
- `neuron.py` - Single neuron (for extension).
- `matrix_hw_wrapper.py` - Hardware interface.
- `do_matrix_mul.py` - Matrix multiplication test.
- `run_profiler.py` - Profiling script.
- `test_matrix_mul_spi.py` - cocotb testbench.
- `input_buffer.txt`, `output_buffer.txt` - Data exchange files.

### RTL (Verilog)

- `MatrixMul_top.v` - Top-level matrix multiplier.
- `MatrixMulEngine.v` - Matrix multiplication FSM.
- `DotProductEngine.v` - Dot product engine.
- `MAC32_top.v` - Floating-point MAC.
- `R4Booth.v`, `WallaceTree.v`, `EACAdder.v`, `FullAdder.v`, `Compressor32.v`, `Compressor42.v` - Arithmetic pipeline.
- `Normalizer.v`, `PreNormalizer.v`, `Rounder.v`, `LeadingOneDetector_Top.v`, `SpecialCaseDetector.v` - Floating-point support.
- `spi_master.v`, `spi_slave.v`, `spi_matrix_loader.v`, `spi_matrix_sender.v` - SPI protocol and matrix I/O.
- `SIPO_MatrixRegs.v`, `PISO_MatrixRegs.v` - Matrix registers.
- `device_a.v`, `device_b.v` - SPI test devices.
- `tb_*.v` - Testbenches.

---

## References

- [IEEE-754 Floating Point Standard](https://en.wikipedia.org/wiki/IEEE_754)
- [cocotb documentation](https://docs.cocotb.org/)
- [NumPy documentation](https://numpy.org/doc/)

---

## Summary

This project demonstrates a full-stack, hardware/software co-design for CNN inference, with a focus on offloading matrix multiplication to a custom Verilog accelerator. The Python code is modular and hardware-agnostic, while the Verilog RTL is highly parameterized and testable. The integration via cocotb and SPI simulation enables rapid prototyping and verification of hardware-accelerated neural networks.