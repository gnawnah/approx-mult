`timescale 1ns / 1ps
module top(
    input  wire clk,
    input  wire rx,
    output reg  tx,
    output reg  led
);
    localparam integer CLKS_PER_BIT = 434;
    localparam integer HALF_BIT     = 217;

    // synchronize the async rx input into our clock domain
    reg rx_sync1 = 1'b1, rx_sync2 = 1'b1;
    always @(posedge clk) begin
        rx_sync1 <= rx;
        rx_sync2 <= rx_sync1;
    end
    wire rx_in = rx_sync2;

    localparam S_RX_IDLE  = 3'd0;
    localparam S_RX_START = 3'd1;
    localparam S_RX_DATA  = 3'd2;
    localparam S_RX_STOP  = 3'd3;
    localparam S_TX_START = 3'd4;
    localparam S_TX_DATA  = 3'd5;
    localparam S_TX_STOP  = 3'd6;
    
    reg [2:0] state = S_RX_IDLE;
    reg operand_sel = 0; // 0 is op a, 1 is op b
    reg byte_sel = 0; // 0 means now sending high byte (MSB), 1 means now sending low byte
    reg [8:0] count = 9'd0;
    reg [2:0] bit_i = 3'd0;
    reg [7:0] rx_all_bits = 8'd0;
    
    
    // instantiating multiplier
    reg [7:0] mult_a = 0;
    reg [7:0] mult_b = 0;
    wire [15:0] product;
    mult_approx #(.WIDTH(8), .TRUNC_BITS(2), .CORRECTION(0)) u_mult(
        .a(mult_a), .b(mult_b), .product(product)
    );
    
    wire [7:0] tx_high_byte = product[15:8];
    wire [7:0] tx_low_byte = product[7:0];

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

            S_RX_DATA: begin
                if (count == CLKS_PER_BIT - 1) begin
                    count <= 9'd0;
                    rx_all_bits[bit_i] <= rx_in;
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
                    if(!operand_sel) begin
                        mult_a <= rx_all_bits;
                        state <= S_RX_IDLE;
                        operand_sel <= 1;
                    end else begin
                        mult_b <= rx_all_bits;
                        state <= S_TX_START;
                        operand_sel <= 0;
                    end
                end else
                    count <= count + 1'b1;
            end

            // tx
            S_TX_START: begin
                tx <= 1'b0;                  // start bit
                bit_i <= 3'd0;
                if (count == CLKS_PER_BIT - 1) begin
                    count <= 9'd0;
                    state <= S_TX_DATA;
                end else
                    count <= count + 1'b1;
            end

            S_TX_DATA: begin
                if(!byte_sel)
                    tx <= tx_high_byte[bit_i];
                else
                    tx <= tx_low_byte[bit_i];
                
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
                    if(!byte_sel) begin
                        bit_i <= 3'd0;
                        state <= S_TX_START;
                        byte_sel <= 1'b1;
                    end else begin
                        state <= S_RX_IDLE;
                        byte_sel <= 1'b0;
                    end
                end else
                    count <= count + 1'b1;
            end

        endcase
    end
endmodule