module PISO_MatrixRegs #(
    parameter MAX_M = 100,
    parameter MAX_K = 100,
    parameter MAX_N = 100,
    // total number of C‐elements:
    localparam TOTAL_C = MAX_M * MAX_N,
    // bits to index them:
    localparam IDX_W = $clog2(TOTAL_C)
) (
    input  wire                 clk,
    input  wire                 rst_n,
    // pulse hi for one cycle to start shifting out
    input  wire                 start,

    // full parallel input
    input  wire [31:0]          matrix_C [0:TOTAL_C-1],

    // serial output
    output reg  [31:0]          Serial_out,
    // asserted while shifting
    output reg                  active,
    // pulses high for one cycle when last word sent
    output reg                  done
);

    // pointer into the C-array:
    reg [IDX_W-1:0]             ptr;

    // On start, reset pointer and go active
    // Then each cycle drive Serial_out <= matrix_C[ptr]
    // When ptr reaches last index, pulse done and deactivate.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ptr       <= 0;
            active    <= 1'b0;
            done      <= 1'b0;
            Serial_out<= 32'd0;
        end else begin
            done      <= 1'b0;           // default
            if (start) begin
                // initialize
                ptr    <= 0;
                active <= 1'b1;
            end else if (active) begin
                // shift out current word
                Serial_out <= matrix_C[ptr];
                if (ptr == TOTAL_C-1) begin
                    // last word done
                    done   <= 1'b1;
                    active <= 1'b0;
                end else begin
                    ptr    <= ptr + 1'b1;
                end
            end
        end
    end

endmodule
