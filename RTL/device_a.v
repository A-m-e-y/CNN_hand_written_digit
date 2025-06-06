// device_a.v
module device_a (
    input         clk,
    input         rst_n,
    input  [31:0] in_data,
    input         response_ready,   // From B
    input         miso,             // From B
    output        sclk,
    output        mosi,
    output        cs_n,
    output [31:0] out_data,         // Response received from B
    output        done_B_to_A       // Pulses after response is received
);

    reg [3:0]  state;
    reg        start;
    reg        hold_cs;
    reg [31:0] tx_data;
    wire       busy;

    reg [31:0] rx_shift;
    reg [5:0]  bit_cnt;
    reg        done;

    // SCLK edge tracking
    reg sclk_d;
    wire sclk_rising = (sclk && !sclk_d);

    assign done_B_to_A = done;

    // SPI master instance
    spi_master u_spi_master (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .hold_cs(hold_cs),
        .data_in(tx_data),
        .sclk(sclk),
        .mosi(mosi),
        .cs_n(cs_n),
        .busy(busy)
    );

    localparam IDLE         = 4'd0;
    localparam SEND_PHASE1  = 4'd1;
    localparam WAIT1        = 4'd2;
    localparam WAIT_RESP    = 4'd3;
    localparam LOAD_DUMMY   = 4'd4;
    localparam SEND_PHASE2  = 4'd5;
    localparam RECEIVE      = 4'd6;
    localparam DONE         = 4'd7;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= IDLE;
            start     <= 1'b0;
            tx_data   <= 32'd0;
            rx_shift  <= 32'd0;
            bit_cnt   <= 6'd0;
            done      <= 1'b0;
            hold_cs   <= 1'b1;
            sclk_d    <= 1'b0;
        end else begin
            start  <= 1'b0;
            done   <= 1'b0;
            sclk_d <= sclk;

            case (state)
                IDLE: begin
                    tx_data <= in_data;
                    hold_cs <= 1'b1;  // hold CS through both phases
                    state   <= SEND_PHASE1;
                end

                SEND_PHASE1: begin
                    start <= 1'b1;
                    state <= WAIT1;
                end

                WAIT1: begin
                    if (!busy)
                        state <= WAIT_RESP;
                end

                WAIT_RESP: begin
                    if (response_ready)
                        state <= LOAD_DUMMY;
                end

                LOAD_DUMMY: begin
                    tx_data <= 32'd0;
                    state   <= SEND_PHASE2;
                end

                SEND_PHASE2: begin
                    start   <= 1'b1;
                    rx_shift <= 32'd0;
                    bit_cnt <= 6'd0;
                    state   <= RECEIVE;
                end

                RECEIVE: begin
                    if (sclk_rising) begin
                        rx_shift <= {rx_shift[30:0], miso};
                        bit_cnt <= bit_cnt + 1;

                        if (bit_cnt == 6'd31) begin
                            done  <= 1'b1;
                            state <= DONE;
                        end
                    end
                end

                DONE: begin
                    state <= IDLE;
                    hold_cs <= 1'b0;  // release CS after this transfer
                end
            endcase
        end
    end

    assign out_data = rx_shift;

endmodule
