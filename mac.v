module mac #(parameter TRUNC_BITS = 2) (
    input wire clk,
    input wire rst,
    input wire [7:0] a,
    input wire [7:0] b,
    input wire valid,
    output reg [31:0] acc
);
    wire [15:0] product; // this is an internal signal
    mult_approx #(TRUNC_BITS) u_mult (.a(a), .b(b), .product(product)); // find the product using mult_approx.v

    always @(posedge clk) begin
        if(rst)
            acc<=32'd0;
        else if (valid)
            acc<=acc+product;
    end

endmodule