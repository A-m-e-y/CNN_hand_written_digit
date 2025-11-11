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

    // New FSM reworked to prefetch entire row of A and column of B into local buffers
    // before starting DotProductEngine, restoring original combinational access semantics.
    reg [2:0] state;
    localparam IDLE        = 3'b000,
               PREFETCH_A  = 3'b001,
               PREFETCH_B  = 3'b010,
               START_DPE   = 3'b011,
               WAIT_DPE    = 3'b100,
               STORE       = 3'b101;

    reg [ADDR_M_BITS-1:0] row_idx;
    reg [ADDR_N_BITS-1:0] col_idx;

    reg dpe_start;
    wire dpe_done;
    wire [31:0] dpe_result;
    wire [ADDR_WIDTH-1:0] dpe_patch_addr, dpe_filter_addr;

    // Prefetch buffers for one row of A and one column of B
    reg [31:0] row_buf [0:MAX_K-1];
    reg [31:0] col_buf [0:MAX_K-1];
    reg [ADDR_K_BITS:0] prefetch_idx; // counts 0..K_val-1
    // Prefetch phase encoding: 0=ISSUE address, 1=WAIT (BRAM latency), 2=CAPTURE data
    reg [1:0] prefetch_phase;

    // Indices for BRAM addressing during prefetch
    wire [ADDR_A_BITS-1:0] a_prefetch_addr = row_idx * K_val + prefetch_idx;
    wire [ADDR_B_BITS-1:0] b_prefetch_addr = prefetch_idx * N_val + col_idx;

    // Address for writing C
    wire [ADDR_C_BITS-1:0] c_index = row_idx * N_val + col_idx;

    // During computation (DotProductEngine running), supply data from buffers
    wire [31:0] dpe_patch_data = row_buf[dpe_patch_addr];
    wire [31:0] dpe_filter_data = col_buf[dpe_filter_addr];

    wire [ADDR_WIDTH-1:0] vec_len_ext = K_val;

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

    // Prefetch FSM phases handled in main always block below.

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
                        done <= 0;
                        row_idx <= 0;
                        col_idx <= 0;
                        prefetch_idx <= 0;
                        prefetch_phase <= 0;
                        matrix_A_addr <= 0;
                        matrix_B_addr <= 0;
                        state <= PREFETCH_A;
                    end
                end

                // Prefetch entire row of A
                PREFETCH_A: begin
                    matrix_C_we <= 0;
                    case (prefetch_phase)
                        2'd0: begin
                            // ISSUE address
                            matrix_A_addr <= a_prefetch_addr;
                            prefetch_phase <= 2'd1; // WAIT
                        end
                        2'd1: begin
                            // WAIT one cycle for BRAM data to become valid
                            prefetch_phase <= 2'd2; // CAPTURE next
                        end
                        2'd2: begin
                            // CAPTURE data
                            row_buf[prefetch_idx] <= matrix_A_rdata;
                            prefetch_phase <= 2'd0; // back to ISSUE for next element
                            if (prefetch_idx < K_val - 1) begin
                                prefetch_idx <= prefetch_idx + 1;
                            end else begin
                                // Move to column prefetch
                                prefetch_idx <= 0;
                                prefetch_phase <= 2'd0;
                                state <= PREFETCH_B;
                            end
                        end
                    endcase
                end

                // Prefetch entire column of B
                PREFETCH_B: begin
                    case (prefetch_phase)
                        2'd0: begin
                            matrix_B_addr <= b_prefetch_addr; // ISSUE
                            prefetch_phase <= 2'd1; // WAIT
                        end
                        2'd1: begin
                            prefetch_phase <= 2'd2; // CAPTURE next
                        end
                        2'd2: begin
                            col_buf[prefetch_idx] <= matrix_B_rdata; // CAPTURE
                            prefetch_phase <= 2'd0; // back to ISSUE
                            if (prefetch_idx < K_val - 1) begin
                                prefetch_idx <= prefetch_idx + 1;
                            end else begin
                                // Ready to start dot product
                                prefetch_idx <= 0;
                                // Debug dump of prefetched buffers for first/last row
                                // if (row_idx == 0 || row_idx == M_val-1) begin
                                //     // integer dbg_i;
                                //     // // $display("BRAM_Engine: Prefetch complete for row=%0d col=%0d", row_idx, col_idx);
                                //     // for (dbg_i = 0; dbg_i < K_val; dbg_i = dbg_i + 1) begin
                                //     //     // $display("  row_buf[%0d]=%h col_buf[%0d]=%h", dbg_i, row_buf[dbg_i], dbg_i, col_buf[dbg_i]);
                                    // end
                                // end
                                dpe_start <= 1;
                                state <= START_DPE;
                            end
                        end
                    endcase
                end

                START_DPE: begin
                    // Pulse start only one cycle
                    dpe_start <= 0;
                    if (row_idx == 0 || row_idx == 3) begin
                        // $display("BRAM_Engine: Starting DPE for C[%0d,%0d]", row_idx, col_idx);
                    end
                    state <= WAIT_DPE;
                end

                WAIT_DPE: begin
                    if (dpe_done) begin
                        state <= STORE;
                    end
                end

                STORE: begin
                    matrix_C_we <= 1;
                    matrix_C_addr <= c_index;
                    matrix_C_wdata <= dpe_result;
                    if (row_idx == 0 || row_idx == 3) begin
                        // $display("BRAM_Engine: Writing C[%0d,%0d] = 0x%08h", row_idx, col_idx, dpe_result);
                    end
                    // Prepare next element
                    if (col_idx < N_val - 1) begin
                        col_idx <= col_idx + 1;
                        prefetch_idx <= 0;
                        prefetch_phase <= 0;
                        state <= PREFETCH_A;
                    end else if (row_idx < M_val - 1) begin
                        row_idx <= row_idx + 1;
                        col_idx <= 0;
                        prefetch_idx <= 0;
                        prefetch_phase <= 0;
                        state <= PREFETCH_A;
                    end else begin
                        done <= 1;
                        state <= IDLE;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule
