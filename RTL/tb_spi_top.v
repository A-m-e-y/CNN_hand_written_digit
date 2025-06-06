// tb_top.v
`timescale 1ns/1ps

module tb_top;

    reg clk;
    reg rst_n;
    reg [31:0] in_data_A;
    wire [31:0] out_data_B;
    wire [31:0] out_data_A;
    wire done_A_to_B;
    wire response_ready;
    wire done_B_to_A;

    // Instantiate the top module
    spi_top uut (
        .clk(clk),
        .rst_n(rst_n),
        .in_data_A(in_data_A),
        .out_data_B(out_data_B),
        .out_data_A(out_data_A),
        .done_A_to_B(done_A_to_B),
        .response_ready(response_ready),
        .done_B_to_A(done_B_to_A)
    );

    // Clock generation: 50MHz = 20ns period
    always #10 clk = ~clk;

    // Random float generator function
    function [31:0] random_float32;
        input dummy;
        reg [7:0] exponent;
        reg [22:0] mantissa;
        reg sign;
        begin
            exponent = $urandom_range(120, 130);         // Between ~1.0 and 1000.0
            mantissa = $urandom_range(0, (1<<16)-1);     // 16 bits random mantissa
            sign = $urandom_range(0,1);                  // Random sign
            random_float32 = {sign, exponent, mantissa};
        end
    endfunction

    reg [31:0] expected_send;
    reg [31:0] expected_response;

    initial begin
        $dumpfile("spi_waveform.vcd");      // name of the VCD file
        $dumpvars(0, tb_top);               // dump all variables in tb_top and below
    end


    initial begin
        $display("=== Bi-Directional SPI Round Trip Test ===");

        clk = 0;
        rst_n = 0;
        in_data_A = 32'd0;

        // Apply reset
        repeat (5) @(posedge clk);
        rst_n = 1;

        // Generate a random 32-bit float-style value
        expected_send = random_float32(0);
        expected_response = expected_send + 1;
        in_data_A = expected_send;

        $display("[TB] Sending data to B: 0x%08X", expected_send);

        // Wait until response is received
        wait (done_B_to_A == 1);
        @(posedge clk);  // Let output stabilize

        $display("[TB] B received      : 0x%08X", out_data_B);
        $display("[TB] A received reply: 0x%08X", out_data_A);

        // Check B received the original value
        if (out_data_B !== expected_send) begin
            $display("[FAIL] B did not receive expected data!");
        end else if (out_data_A !== expected_response) begin
            $display("[FAIL] A did not receive correct incremented response!");
        end else begin
            $display("[PASS] Round-trip SPI exchange successful!");
        end

        $finish;
    end

endmodule
