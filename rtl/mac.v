module mac #(
    parameter WIDTH = 8,
    parameter TRUNC_BITS = 2,
    parameter CORRECTION = 0
) (
    input wire clk,
    input wire rst,
    input wire [WIDTH-1:0] a,
    input wire [WIDTH-1:0] b,
    input wire valid,
    output reg [4*WIDTH-1:0] acc
);
    wire [2*WIDTH-1:0] product; // this is an internal signal
    mult_approx #(
        .WIDTH(WIDTH),
        .TRUNC_BITS(TRUNC_BITS),
        .CORRECTION(CORRECTION)
    ) u_mult (.a(a), .b(b), .product(product)); // find the product using mult_approx.v

    always @(posedge clk) begin
        if(rst)
            acc<=32'd0;
        else if (valid)
            acc<=acc+product;
    end

endmodule