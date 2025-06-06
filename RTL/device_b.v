// device_b.v
module device_b (
    input         clk,
    input         rst_n,
    input         sclk,         // From master
    input         cs_n,         // From master
    input         mosi,         // From master
    output        miso,         // To master
    output [31:0] out_data,     // Received data
    output        response_ready // Goes high when response is ready
);

    wire [31:0] data_out_wire;
    wire        valid_wire;
    wire        response_ready_wire;

    // Instantiate the enhanced SPI slave
    spi_slave u_spi_slave (
        .clk(clk),
        .rst_n(rst_n),
        .sclk(sclk),
        .cs_n(cs_n),
        .mosi(mosi),
        .miso(miso),
        .data_out(data_out_wire),
        .valid(valid_wire),
        .response_ready(response_ready_wire)
    );

    reg [31:0] data_buf;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            data_buf <= 32'd0;
        else if (valid_wire)
            data_buf <= data_out_wire;
    end

    assign out_data = data_buf;
    assign response_ready = response_ready_wire;

endmodule
