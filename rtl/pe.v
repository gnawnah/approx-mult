// 2x2
module pe #(
    parameter WIDTH = 8,
    parameter TRUNC_BITS = 2,
    parameter CORRECTION = 0,
    parameter ACC_WIDTH = 32
) (
    input wire clk,
    input wire rst,
    input wire [WIDTH-1:0] a_in,
    input wire [WIDTH-1:0] b_in,
    output reg [WIDTH-1:0] a_out, // a_in passed right (1 cycle delay)
    output reg [WIDTH-1:0] b_out,
    output reg [ACC_WIDTH-1:0] c // accumulated result
);
    wire [2*WIDTH-1:0] product; // driven by mult_approx
    mult_approx #(
        .WIDTH(WIDTH),
        .TRUNC_BITS(TRUNC_BITS),
        .CORRECTION(CORRECTION)
    ) u_mult (.a(a_in), .b(b_in), .product(product));

    always @(posedge clk) begin
        if(rst) begin
            c <= 0;
            a_out <= 0;
            b_out <= 0;
        end else begin
            c <= c + product;
            a_out <= a_in;
            b_out <= b_in;
        end
    end
endmodule