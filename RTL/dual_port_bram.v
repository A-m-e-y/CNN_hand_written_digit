
// Dual-Port Block RAM module
module dual_port_bram #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 10,
    parameter DEPTH = 1024
)(
    input wire clk,
    
    // Port A
    input wire [ADDR_WIDTH-1:0] addr_a,
    input wire [DATA_WIDTH-1:0] din_a,
    input wire we_a,
    output reg [DATA_WIDTH-1:0] dout_a,
    
    // Port B
    input wire [ADDR_WIDTH-1:0] addr_b,
    input wire [DATA_WIDTH-1:0] din_b,
    input wire we_b,
    output reg [DATA_WIDTH-1:0] dout_b
);

    // Memory array
    reg [DATA_WIDTH-1:0] ram [0:DEPTH-1];
    
    // Port A operations
    always @(posedge clk) begin
        if (we_a) begin
            ram[addr_a] <= din_a;
        end
        dout_a <= ram[addr_a];
    end
    
    // Port B operations
    always @(posedge clk) begin
        if (we_b) begin
            ram[addr_b] <= din_b;
        end
        dout_b <= ram[addr_b];
    end

endmodule
