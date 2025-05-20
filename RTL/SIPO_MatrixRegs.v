module SIPO_MatrixRegs #(
    parameter MAX_M       = 100,
    parameter MAX_K       = 100,
    parameter MAX_N       = 100,
    parameter AWIDTH_A    = $clog2(MAX_M * MAX_K),
    parameter AWIDTH_B    = $clog2(MAX_K * MAX_N)
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

    // pass-through dimensions
    output wire [ $clog2(MAX_M):0 ] M_val,
    output wire [ $clog2(MAX_K):0 ] K_val,
    output wire [ $clog2(MAX_N):0 ] N_val,

    // parallel-matrix outputs
    output reg  [31:0]            matrix_A [0:MAX_M*MAX_K-1],
    output reg  [31:0]            matrix_B [0:MAX_K*MAX_N-1],

    // pulses when loading complete
    output reg                    done
);

  // simply wire the inputs to the outputs
  assign M_val = M_in;
  assign K_val = K_in;
  assign N_val = N_in;

  // pointers into A and B
  reg [AWIDTH_A-1:0] addrA;
  reg [AWIDTH_B-1:0] addrB;

  // SIPO + done logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      addrA <= 0;
      addrB <= 0;
      done  <= 1'b0;
    end else begin
      done <= 1'b0;  // default low

      case (mode)
        2'b01: begin
          matrix_A[ addrA ] <= Serial_in;
          addrA <= addrA + 1;
        end

        2'b10: begin
          matrix_B[ addrB ] <= Serial_in;
          addrB <= addrB + 1;
        end

        2'b11: begin
          done <= 1'b1;   // one-cycle pulse
        end

        default: ;       // idle
      endcase
    end
  end

endmodule
