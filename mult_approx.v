module mult_approx #(parameter TRUNC_BITS = 2) (
    input wire [7:0] a,
    input wire [7:0] b,
    output wire [15:0] product
);
    wire [7:0] a_trunc;
    wire [7:0] b_trunc;
    // by shifting to the right by TRUNC_BITS and shifting to the left by TRUNC_BITS, the TRUNC_BITS amount of LSB becomes 0
    assign a_trunc = (a >> TRUNC_BITS) << TRUNC_BITS; // if TRUNC_BITS = 0, a is just a
    assign b_trunc = (b >> TRUNC_BITS) << TRUNC_BITS;
    assign product = a_trunc * b_trunc;
endmodule
