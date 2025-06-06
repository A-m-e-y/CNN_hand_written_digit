module spi_master (
    input        clk,
    input        rst_n,
    input        start,
    input        hold_cs,         // NEW: keep cs_n low after DONE
    input [31:0] data_in,
    output reg   sclk,
    output reg   mosi,
    output reg   cs_n,
    output reg   busy
);

    reg [1:0] state;
    reg [5:0] bit_cnt;
    reg [31:0] shift_reg;

    localparam IDLE     = 2'd0;
    localparam ASSERT   = 2'd1;
    localparam TRANSFER = 2'd2;
    localparam DONE     = 2'd3;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= IDLE;
            cs_n      <= 1'b1;
            sclk      <= 1'b0;
            mosi      <= 1'b0;
            busy      <= 1'b0;
            bit_cnt   <= 6'd0;
            shift_reg <= 32'd0;
        end else begin
            case (state)
                IDLE: begin
                    if (!hold_cs)
                        cs_n <= 1'b1;  // release only if not holding
                    sclk <= 1'b0;
                    busy <= 1'b0;
                    if (start) begin
                        shift_reg <= data_in;
                        bit_cnt   <= 6'd31;
                        state     <= ASSERT;
                    end
                end

                ASSERT: begin
                    cs_n <= 1'b0;
                    busy <= 1'b1;
                    state <= TRANSFER;
                end

                TRANSFER: begin
                    sclk <= ~sclk;

                    if (sclk == 1'b0) begin
                        mosi <= shift_reg[bit_cnt];
                    end else begin
                        if (bit_cnt == 0) begin
                            state <= DONE;
                        end else begin
                            bit_cnt <= bit_cnt - 1;
                        end
                    end
                end

                DONE: begin
                    if (!hold_cs)
                        cs_n <= 1'b1;  // release only if not holding
                    busy <= 1'b0;
                    sclk <= 1'b0;
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule
