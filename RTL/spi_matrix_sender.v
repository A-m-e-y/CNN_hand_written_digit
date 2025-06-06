`timescale 1ns/1ps

module spi_matrix_sender #(
    parameter MAX_M = 10,
    parameter MAX_N = 10
)(
    input  wire        clk,
    input  wire        rst_n,

    // SPI interface
    input  wire        sclk,
    input  wire        mosi,
    input  wire        cs_n,
    output reg        miso,

    // Control
    input  wire        start_tx,
    input  wire [31:0] matrix_C [0:MAX_M*MAX_N-1],
    input  wire [15:0] C_size,
    output reg         done_tx
);

    // SPI slave instance
    wire [31:0] rx_data;
    wire        rx_valid;
    wire        rx_ready = 1'b0;

    reg  [31:0] tx_data;
    reg         tx_valid;
    wire        tx_ready;

    spi_slave spi_inst (
        .clk       (clk),
        .rst_n     (rst_n),
        .sclk      (sclk),
        .mosi      (mosi),
        .cs_n      (cs_n),
        .miso      (miso),
        .rx_data   (rx_data),
        .rx_valid  (rx_valid),
        .rx_ready  (rx_ready),
        .tx_data   (tx_data),
        .tx_valid  (tx_valid),
        .tx_ready  (tx_ready)
    );

    // FSM states
    typedef enum logic [2:0] {
        IDLE       = 3'b000,
        WAIT_CS_LOW = 3'b001,
        PULSE_VALID = 3'b010,
        WAIT_READY  = 3'b011,
        WAIT_CS_HIGH = 3'b100,
        DONE       = 3'b101
    } state_t;

    state_t state;
    reg [15:0] send_index;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state      <= IDLE;
            send_index <= 0;
            tx_data    <= 0;
            tx_valid   <= 0;
            done_tx    <= 0;
        end else begin
            case (state)
                IDLE: begin
                    tx_valid <= 0;
                    done_tx  <= 0;
                    if (start_tx) begin
                        send_index <= 0;
                        tx_data <= matrix_C[0];
                        state <= WAIT_CS_LOW;
                    end
                end

                WAIT_CS_LOW: begin
                    tx_valid <= 0;
                    if (cs_n == 0) begin
                        state <= PULSE_VALID;
                    end
                end

                PULSE_VALID: begin
                    tx_valid <= 1;
                    state <= WAIT_READY;
                end

                WAIT_READY: begin
                    if (tx_ready) begin
                        tx_valid <= 0; // drop valid after tx_ready pulse
                        state <= WAIT_CS_HIGH;
                    end
                end

                WAIT_CS_HIGH: begin
                    if (cs_n == 1) begin
                        send_index <= send_index + 1;
                        if (send_index + 1 == C_size) begin
                            state <= DONE;
                        end else begin
                            tx_data <= matrix_C[send_index + 1];
                            state <= WAIT_CS_LOW;
                        end
                    end
                end

                DONE: begin
                    done_tx <= 1;
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule
