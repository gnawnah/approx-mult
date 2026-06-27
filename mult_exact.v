module mult_exact (
    input wire [7:0] a,
    input wire[7:0] b,
    output wire [15:0] product
);
    assign product = a * b;
endmodule