// top.v
module spi_top (
    input         clk,
    input         rst_n,
    input  [31:0] in_data_A,        // Data to send from A to B
    output [31:0] out_data_B,       // B receives this
    output [31:0] out_data_A,       // A receives B's response
    output        done_A_to_B,      // Phase 1 complete
    output        response_ready,   // B is ready with incremented value
    output        done_B_to_A       // Phase 2 complete
);

    wire sclk, mosi, cs_n, miso;

    // Device A (Master)
    device_a u_device_a (
        .clk(clk),
        .rst_n(rst_n),
        .in_data(in_data_A),
        .response_ready(response_ready),
        .miso(miso),
        .sclk(sclk),
        .mosi(mosi),
        .cs_n(cs_n),
        .out_data(out_data_A),
        .done_B_to_A(done_B_to_A)
    );

    // Device B (Slave)
    device_b u_device_b (
        .clk(clk),
        .rst_n(rst_n),
        .sclk(sclk),
        .cs_n(cs_n),
        .mosi(mosi),
        .miso(miso),
        .out_data(out_data_B),
        .response_ready(response_ready)
    );

    // Optional: done_A_to_B is just when first phase completes
    assign done_A_to_B = ~cs_n && !mosi;  // placeholder or track in FSM if needed

endmodule
