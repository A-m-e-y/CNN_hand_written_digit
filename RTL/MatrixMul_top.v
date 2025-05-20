module MatrixMul_top #(
    parameter MAX_M       = 100,
    parameter MAX_K       = 100,
    parameter MAX_N       = 100
) (
    input  wire                   clk,
    input  wire                   rst_n,

    // user-driven dimensions (≤ MAX_*)
    input  wire [ $clog2(MAX_M):0 ] M_in,
    input  wire [ $clog2(MAX_K):0 ] K_in,
    input  wire [ $clog2(MAX_N):0 ] N_in,

    // serial data in
    input  wire [31:0]            Serial_in,
    input  wire [1:0]             mode,      // 00=idle, 01=load A, 10=load B, 11=finish

    output reg [31:0]            Serial_out,
    output reg active,
    output reg done
);
    
    
    wire [31:0] matrix_A [0:MAX_M*MAX_K-1];
    wire [31:0] matrix_B [0:MAX_K*MAX_N-1];
    wire [31:0] matrix_C [0:MAX_M*MAX_N-1];
    wire sipo_done, mul_done;

    SIPO_MatrixRegs #(
        .MAX_M(MAX_M),
        .MAX_K(MAX_K),
        .MAX_N(MAX_N)
    ) sipo (
        .clk(clk),
        .rst_n(rst_n),
        .M_in(M_in),
        .K_in(K_in),
        .N_in(N_in),
        .Serial_in(Serial_in),
        .mode(mode),
        .matrix_A(matrix_A),
        .matrix_B(matrix_B),
        .done(sipo_done)
    );

    MatrixMulEngine #(
        .MAX_M(MAX_M),
        .MAX_K(MAX_K),
        .MAX_N(MAX_N)
    ) m_mul (
        .clk(clk),
        .rst_n(rst_n),
        .start(sipo_done),
        .done(mul_done),
        .M_val(M_in),
        .K_val(K_in),
        .N_val(N_in),
        .matrix_A(matrix_A),
        .matrix_B(matrix_B),
        .matrix_C(matrix_C)
    );

    PISO_MatrixRegs #(
        .MAX_M(MAX_M),
        .MAX_K(MAX_K),
        .MAX_N(MAX_N)
    ) piso (
        .clk(clk),
        .rst_n(rst_n),
        .start(mul_done),
        .matrix_C(matrix_C),
        .Serial_out(Serial_out),
        .active(active),
        .done(done)
    );

endmodule