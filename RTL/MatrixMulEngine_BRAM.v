`timescale 1ns/1ps

module MatrixMulEngine_BRAM #(
    parameter MAX_M = 16,
    parameter MAX_K = 16,
    parameter MAX_N = 16,
    parameter ADDR_M_BITS = $clog2(MAX_M),
    parameter ADDR_K_BITS = $clog2(MAX_K),
    parameter ADDR_N_BITS = $clog2(MAX_N),
    parameter ADDR_A_BITS = $clog2(MAX_M * MAX_K),
    parameter ADDR_B_BITS = $clog2(MAX_K * MAX_N),
    parameter ADDR_C_BITS = $clog2(MAX_M * MAX_N),
    parameter ADDR_WIDTH = $clog2((MAX_M > MAX_K ? (MAX_M > MAX_N ? MAX_M : MAX_N) : (MAX_K > MAX_N ? MAX_K : MAX_N)))
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    output reg done,

    input [ADDR_M_BITS:0] M_val,
    input [ADDR_K_BITS:0] K_val,
    input [ADDR_N_BITS:0] N_val,

    // BRAM interface for Matrix A (read-only during computation)
    output reg [ADDR_A_BITS-1:0] matrix_A_addr,
    input wire [31:0] matrix_A_rdata,
    
    // BRAM interface for Matrix B (read-only during computation)
    output reg [ADDR_B_BITS-1:0] matrix_B_addr,
    input wire [31:0] matrix_B_rdata,
    
    // BRAM interface for Matrix C (write-only during computation)
    output reg matrix_C_we,
    output reg [ADDR_C_BITS-1:0] matrix_C_addr,
    output reg [31:0] matrix_C_wdata
);

    reg [2:0] state;
    localparam IDLE = 3'b000,
               LOAD_A = 3'b001,
               LOAD_B = 3'b010,
               COMPUTE = 3'b011,
               WAIT_DPE = 3'b100,
               STORE = 3'b101;

    reg [ADDR_M_BITS-1:0] row_idx;
    reg [ADDR_N_BITS-1:0] col_idx;

    reg dpe_start;
    wire dpe_done;
    wire [31:0] dpe_result;
    wire [ADDR_WIDTH-1:0] dpe_patch_addr, dpe_filter_addr;
    reg [31:0] dpe_patch_data, dpe_filter_data;

    wire [ADDR_A_BITS-1:0] a_index = row_idx * K_val + dpe_patch_addr;
    wire [ADDR_B_BITS-1:0] b_index = dpe_filter_addr * N_val + col_idx;
    wire [ADDR_C_BITS-1:0] c_index = row_idx * N_val + col_idx;

    wire [ADDR_WIDTH-1:0] vec_len_ext = K_val;
    
    // Pipeline registers for BRAM reads
    reg [ADDR_A_BITS-1:0] matrix_A_addr_d;
    reg [ADDR_B_BITS-1:0] matrix_B_addr_d;
    reg data_valid;

    DotProductEngine #(
        .ADDR_WIDTH(ADDR_WIDTH)
    ) dpe_inst (
        .clk(clk),
        .rst_n(rst_n),
        .start(dpe_start),
        .vec_length(vec_len_ext),
        .patch_data(dpe_patch_data),
        .filter_data(dpe_filter_data),
        .done(dpe_done),
        .result(dpe_result),
        .patch_addr(dpe_patch_addr),
        .filter_addr(dpe_filter_addr)
    );

    // BRAM read logic with 1-cycle delay handling
    always @(posedge clk) begin
        matrix_A_addr_d <= matrix_A_addr;
        matrix_B_addr_d <= matrix_B_addr;
        
        if (state == LOAD_A || state == LOAD_B || state == COMPUTE || state == WAIT_DPE) begin
            data_valid <= 1'b1;
        end else begin
            data_valid <= 1'b0;
        end
    end
    
    // Register BRAM outputs for DPE
    always @(posedge clk) begin
        if (data_valid) begin
            dpe_patch_data <= matrix_A_rdata;
            dpe_filter_data <= matrix_B_rdata;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            row_idx <= 0;
            col_idx <= 0;
            dpe_start <= 0;
            done <= 0;
            matrix_A_addr <= 0;
            matrix_B_addr <= 0;
            matrix_C_we <= 0;
            matrix_C_addr <= 0;
            matrix_C_wdata <= 0;
        end else begin
            case (state)
                IDLE: begin
                    matrix_C_we <= 0;
                    if (start) begin
                        done <= 0;  // Clear done only when starting new computation
                        row_idx <= 0;
                        col_idx <= 0;
                        matrix_A_addr <= 0;
                        matrix_B_addr <= 0;
                        state <= LOAD_A;
                    end
                end

                LOAD_A: begin
                    // Pre-load first A address
                    matrix_A_addr <= a_index;
                    state <= LOAD_B;
                end

                LOAD_B: begin
                    // Pre-load first B address
                    matrix_B_addr <= b_index;
                    state <= COMPUTE;
                end

                COMPUTE: begin
                    // Start DPE after data is available
                    dpe_start <= 1;
                    state <= WAIT_DPE;
                end

                WAIT_DPE: begin
                    dpe_start <= 0;
                    
                    // Update addresses as DPE requests them
                    matrix_A_addr <= a_index;
                    matrix_B_addr <= b_index;
                    
                    if (dpe_done) begin
                        state <= STORE;
                    end
                end

                STORE: begin
                    matrix_C_we <= 1;
                    matrix_C_addr <= c_index;
                    matrix_C_wdata <= dpe_result;
                    
                    if (col_idx < N_val - 1) begin
                        col_idx <= col_idx + 1;
                        state <= LOAD_A;
                    end else if (row_idx < M_val - 1) begin
                        row_idx <= row_idx + 1;
                        col_idx <= 0;
                        state <= LOAD_A;
                    end else begin
                        done <= 1;
                        matrix_C_we <= 0;
                        state <= IDLE;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule
