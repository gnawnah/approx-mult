module mult_approx #(
    parameter WIDTH = 8,
    parameter TRUNC_BITS = 2,
    parameter CORRECTION = 0 // constant added to de-bias
) (
    input wire [WIDTH-1:0] a,
    input wire [WIDTH-1:0] b,
    output wire [2*WIDTH-1:0] product
);
    wire [WIDTH-1:0] a_trunc;
    wire [WIDTH-1:0] b_trunc;
    // by shifting to the right by TRUNC_BITS and shifting to the left by TRUNC_BITS, the TRUNC_BITS amount of LSB becomes 0
    assign a_trunc = (a >> TRUNC_BITS) << TRUNC_BITS; // if TRUNC_BITS = 0, a is just a
    assign b_trunc = (b >> TRUNC_BITS) << TRUNC_BITS;
    assign product = a_trunc * b_trunc + CORRECTION; // adding the de-bias term
endmodule
