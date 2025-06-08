module MatrixMul_top #(
    parameter MAX_M = 10, // Maximum number of rows in matrix A
    parameter MAX_K = 10,   // Maximum number of columns in matrix A / rows in matrix B
    parameter MAX_N = 10    // Maximum number of columns in matrix B
) (
    input  wire                   clk,
    input  wire                   rst_n,

    // user-driven dimensions (≤ MAX_*)
    input  wire [ $clog2(MAX_M):0 ] M_in,
    input  wire [ $clog2(MAX_K):0 ] K_in,
    input  wire [ $clog2(MAX_N):0 ] N_in,

    // SPI interface
    input sclk,
    input mosi,
    input cs_n,
    output miso,

    input send_c,
    output reg mul_done,
    output reg done
);
    
    
    wire [31:0] matrix_A [0:MAX_M*MAX_K-1];
    wire [31:0] matrix_B [0:MAX_K*MAX_N-1];
    wire [31:0] matrix_C [0:MAX_M*MAX_N-1];
    wire A_loaded, B_loaded;

    reg [15:0] c_size; // Size of matrix C, calculated as M * N

    assign c_size = M_in * N_in;

    spi_matrix_loader #(
        .MAX_M(MAX_M),
        .MAX_K(MAX_K),
        .MAX_N(MAX_N)
    ) spi_loader (
        .clk(clk),
        .rst_n(rst_n),
        .sclk(sclk), // Assuming Serial_in[0] is SCLK
        .mosi(mosi), // Assuming Serial_in[1] is MOSI
        .cs_n(cs_n), // Assuming Serial_in[2] is CS_N
        // .miso(miso),   // MISO output
        .matrix_A(matrix_A),
        .matrix_B(matrix_B),
        .matrix_A_ready(A_loaded), // Ready signal for matrix A
        .matrix_B_ready(B_loaded)   // Ready signal for matrix B
    );

    MatrixMulEngine #(
        .MAX_M(MAX_M),
        .MAX_K(MAX_K),
        .MAX_N(MAX_N)
    ) m_mul (
        .clk(clk),
        .rst_n(rst_n),
        .start(A_loaded && B_loaded),
        .done(mul_done),
        .M_val(M_in),
        .K_val(K_in),
        .N_val(N_in),
        .matrix_A(matrix_A),
        .matrix_B(matrix_B),
        .matrix_C(matrix_C)
    );

    spi_matrix_sender #(
        .MAX_M(MAX_M),
        .MAX_N(MAX_N)
    ) spi_sender (
        .clk(clk),
        .rst_n(rst_n),
        .C_size(c_size), // Assuming C_size is M * N
        .sclk(sclk), // Assuming Serial_in[0] is SCLK
        // .mosi(mosi), // Assuming Serial_in[1] is MOSI
        .miso(miso), // MISO output
        .cs_n(cs_n), // Assuming Serial_in[2] is CS_N
        .start_tx(send_c),
        .matrix_C(matrix_C),
        .done_tx(done)
    );

endmodule