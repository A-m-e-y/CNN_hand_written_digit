`timescale 1ns/1ps

module spi_matrix_loader #(
    parameter MAX_M = 784, // Maximum number of rows in matrix A
    parameter MAX_K = 288,   // Maximum number of columns in matrix A / rows in matrix B
    parameter MAX_N = 64    // Maximum number of columns in matrix B
)(
    input  wire        clk,
    input  wire        rst_n,

    // SPI signals
    input  wire        sclk,
    input  wire        mosi,
    input  wire        cs_n,
    output wire        miso,

    // Outputs
    output reg  [31:0] matrix_A [0:MAX_M*MAX_K-1],
    output reg  [31:0] matrix_B [0:MAX_K*MAX_N-1],
    output reg         matrix_A_ready,
    output reg         matrix_B_ready
);

    // SPI interface
    wire [31:0] rx_data;
    reg [31:0] rx_data_d;
    wire        rx_valid;
    reg         rx_ready;

    wire [31:0] tx_data = 32'h00000000;
    wire        tx_valid = 0;
    wire        tx_ready;

    spi_slave spi_inst (
        .clk       (clk),
        .rst_n     (rst_n),
        .sclk      (sclk),
        .mosi      (mosi),
        .cs_n      (cs_n),
        .miso      (miso),
        .rx_data   (rx_data),
        .rx_valid  (rx_valid),
        .rx_ready  (rx_ready),
        .tx_data   (tx_data),
        .tx_valid  (tx_valid),
        .tx_ready  (tx_ready)
    );

    // FSM states
    localparam IDLE       = 0,
               LOAD_DATA  = 1;

    reg [1:0] state;
    reg current_matrix;  // 0 = A, 1 = B
    reg [11:0] rows, cols;
    reg [15:0] load_count;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            rows <= 0;
            cols <= 0;
            load_count <= 0;
            current_matrix <= 0;
            matrix_A_ready <= 0;
            matrix_B_ready <= 0;
            rx_ready <= 1;
            rx_data_d <= 0;
        end else begin
            rx_ready <= 1;
            rx_data_d <= rx_data;
            case (state)
                IDLE: begin
                    if (rx_valid) begin
                        // Parse header
                        case (rx_data[27:24])
                            4'hA: begin
                                current_matrix <= 0;
                                matrix_A_ready <= 0;
                            end
                            4'hB: begin
                                current_matrix <= 1;
                                matrix_B_ready <= 0;
                            end
                            default: begin
                                // Unknown header; ignore and stay in IDLE
                            end
                        endcase
                
                        rows <= rx_data[23:12];
                        cols <= rx_data[11:0];
                        load_count <= 0;
                        state <= LOAD_DATA;
                    end
                end

                LOAD_DATA: begin
                    if (rx_valid) begin
                        if (!current_matrix)
                            matrix_A[load_count] <= rx_data;
                        else
                            matrix_B[load_count] <= rx_data;

                        load_count <= load_count + 1;

                        if (load_count == (rows * cols - 1)) begin
                            if (!current_matrix)
                                matrix_A_ready <= 1;
                            else
                                matrix_B_ready <= 1;

                            state <= IDLE;
                        end
                    end
                end
            endcase
        end
    end

endmodule
