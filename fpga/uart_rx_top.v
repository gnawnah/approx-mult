`timescale 1ns / 1ps
module top (
    input  wire clk,              // Y9, 50 MHz
    input  wire rx,               // PL_UART_RXD, N15 — incoming serial line
    output reg  [7:0] led         // show the received byte
);
    localparam integer CLKS_PER_BIT = 434;   // 50e6 / 115200, one bit-time
    localparam integer HALF_BIT     = 217;   // half a bit, to reach bit centre

    // the four states
    localparam IDLE  = 2'd0,
               START = 2'd1,
               DATA  = 2'd2,
               STOP  = 2'd3;

    reg [1:0] state = IDLE;
    reg [8:0] clk_count = 0;      // counts ticks within the current bit (0..433)
    reg [2:0] bit_index = 0;      // which data bit we're on (0..7)
    reg [7:0] rx_shift = 0;       // collects the 8 bits as they arrive

    // --- synchronizer: clean the async rx into our clock domain ---
    // rx comes from the PC, unrelated to our 50MHz clock. Passing it through
    // two flip-flops before use prevents metastability. Use rx_in, not rx.
    reg rx_sync1 = 1'b1, rx_sync2 = 1'b1;
    always @(posedge clk) begin
        rx_sync1 <= rx;
        rx_sync2 <= rx_sync1;
    end
    wire rx_in = rx_sync2;

    // --- the state machine ---
    always @(posedge clk) begin
        case (state)

            IDLE: begin                       // watch for the start bit
                clk_count <= 0;
                bit_index <= 0;
                if (rx_in == 1'b0)            // line dropped low = start edge
                    state <= START;
            end

            START: begin                      // wait half a bit, land at centre
                if (clk_count == HALF_BIT - 1) begin
                    if (rx_in == 1'b0) begin  // still low = real start (not a glitch)
                        clk_count <= 0;
                        state <= DATA;
                    end else
                        state <= IDLE;        // false alarm, go back
                end else
                    clk_count <= clk_count + 1;
            end

            DATA: begin                       // sample each bit at its centre
                if (clk_count == CLKS_PER_BIT - 1) begin
                    clk_count <= 0;
                    rx_shift[bit_index] <= rx_in;   // grab the bit (LSB first)
                    if (bit_index == 7)
                        state <= STOP;               // got all 8
                    else
                        bit_index <= bit_index + 1;
                end else
                    clk_count <= clk_count + 1;
            end

            STOP: begin                       // ride out the stop bit
                if (clk_count == CLKS_PER_BIT - 1) begin
                    led <= rx_shift;          // present the finished byte
                    state <= IDLE;
                end else
                    clk_count <= clk_count + 1;
            end

        endcase
    end
endmodule