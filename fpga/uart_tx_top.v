`timescale 1ns / 1ps
module top (
    input  wire clk,          // Y9, 50 MHz
    output reg  tx            // PL_UART_TXD, P15
);
    localparam integer CLKS_PER_BIT = 434;   // 50e6 / 115200
    localparam [7:0] DATA = 8'h55;           // 'U', alternating pattern

    reg [9:0] frame = {1'b1, 8'h55, 1'b0};   // {stop=1, data, start=0}, sent LSB first
    reg [3:0] bit_index = 0;
    reg [8:0] clk_count = 0;

    initial tx = 1'b1;        // idle high

    always @(posedge clk) begin
        if (clk_count < CLKS_PER_BIT - 1) begin
            clk_count <= clk_count + 1;
        end else begin
            clk_count <= 0;
            tx <= frame[bit_index];
            if (bit_index < 9)
                bit_index <= bit_index + 1;
            else begin
                bit_index <= 0;
                frame <= {1'b1, DATA, 1'b0};   // reload
            end
        end
    end
endmodule