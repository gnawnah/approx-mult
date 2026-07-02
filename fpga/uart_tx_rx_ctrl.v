`timescale 1ns / 1ps
module top(
    input  wire clk,
    input  wire rx,
    output reg  tx,
    output reg  led
);
    localparam integer CLKS_PER_BIT = 434;
    localparam integer HALF_BIT     = 217;

    // synchroniswe to present metastability
    reg rx_sync1 = 1'b1, rx_sync2 = 1'b1;
    always @(posedge clk) begin
        rx_sync1 <= rx;
        rx_sync2 <= rx_sync1;
    end
    wire rx_in = rx_sync2;

    // states
    localparam S_RX_IDLE  = 3'd0;
    localparam S_RX_START = 3'd1;
    localparam S_RX_DATA  = 3'd2;
    localparam S_RX_STOP  = 3'd3;
    localparam S_TX_START = 3'd4;
    localparam S_TX_DATA  = 3'd5;
    localparam S_TX_STOP  = 3'd6;

    reg [2:0] state = S_RX_IDLE;
    reg [8:0] count = 9'd0;
    reg [2:0] bit_i = 3'd0;
    reg [7:0] shift = 8'd0;

    initial begin
        tx  = 1'b1;
        led = 1'b0;
    end

    always @(posedge clk) begin
        case (state)

            // receive
            S_RX_IDLE: begin
                tx    <= 1'b1;
                count <= 9'd0;
                bit_i <= 3'd0;
                if (rx_in == 1'b0)
                    state <= S_RX_START;
            end

            S_RX_START: begin
                if (count == HALF_BIT - 1) begin
                    count <= 9'd0;
                    if (rx_in == 1'b0)
                        state <= S_RX_DATA;
                    else
                        state <= S_RX_IDLE;
                end else
                    count <= count + 1'b1;
            end
            end

            S_RX_DATA: begin
                if (count == CLKS_PER_BIT - 1) begin
                    count <= 9'd0;
                    shift[bit_i] <= rx_in;
                    if (bit_i == 3'd7)
                        state <= S_RX_STOP;
                    else
                        bit_i <= bit_i + 1'b1;
                end else
                    count <= count + 1'b1;
            end

            S_RX_STOP: begin
                if (count == CLKS_PER_BIT - 1) begin
                    count <= 9'd0;
                    bit_i <= 3'd0;
                    state <= S_TX_START;     // received byte is in `shift`, now send it
                end else
                    count <= count + 1'b1;
            end

            // transmit
            S_TX_START: begin
                tx <= 1'b0;                  // start bit
                if (count == CLKS_PER_BIT - 1) begin
                    count <= 9'd0;
                    state <= S_TX_DATA;
                end else
                    count <= count + 1'b1;
            end

            S_TX_DATA: begin
                tx <= shift[bit_i];          // data bits, LSB first
                if (count == CLKS_PER_BIT - 1) begin
                    count <= 9'd0;
                    if (bit_i == 3'd7)
                        state <= S_TX_STOP;
                    else
                        bit_i <= bit_i + 1'b1;
                end else
                    count <= count + 1'b1;
            end

            S_TX_STOP: begin
                tx <= 1'b1;                  // stop bit
                if (count == CLKS_PER_BIT - 1) begin
                    count <= 9'd0;
                    led   <= ~led;           // blink on each completed echo
                    state <= S_RX_IDLE;
                end else
                    count <= count + 1'b1;
            end

        endcase
    end
endmodule