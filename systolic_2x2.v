module systolic_2x2 #(
    parameter WIDTH = 8,
    parameter TRUNC_BITS = 0,
    parameter CORRECTION = 0,
    parameter ACC_WIDTH = 32
) (
    input wire clk,
    input wire rst,
    input wire [WIDTH-1:0] a_row0, a_row1,
    input wire [WIDTH-1:0] b_col0, b_col1,
    output wire [ACC_WIDTH-1:0] c00, c01, c10, c11
);

    wire [WIDTH-1:0] a_00_to_01;
    wire [WIDTH-1:0] a_10_to_11;
    wire [WIDTH-1:0] b_00_to_10;
    wire [WIDTH-1:0] b_01_to_11;

    // useless outputs
    wire [WIDTH-1:0] a_01_out, a_11_out;
    wire [WIDTH-1:0] b_10_out, b_11_out;

    pe #(
        .WIDTH(WIDTH),
        .TRUNC_BITS(TRUNC_BITS),
        .CORRECTION(CORRECTION),
        .ACC_WIDTH(ACC_WIDTH)
    ) pe00 (
        .clk(clk), 
        .rst(rst), 
        .a_in(a_row0), 
        .b_in(b_col0), 
        .a_out(a_00_to_01), 
        .b_out(b_00_to_10), 
        .c(c00)
    );

    pe #(
        .WIDTH(WIDTH),
        .TRUNC_BITS(TRUNC_BITS),
        .CORRECTION(CORRECTION),
        .ACC_WIDTH(ACC_WIDTH)
    ) pe01 (
        .clk(clk), 
        .rst(rst), 
        .a_in(a_00_to_01), 
        .b_in(b_col1), 
        .a_out(a_01_out), 
        .b_out(b_01_to_11), 
        .c(c01)
    );

    pe #(
        .WIDTH(WIDTH),
        .TRUNC_BITS(TRUNC_BITS),
        .CORRECTION(CORRECTION),
        .ACC_WIDTH(ACC_WIDTH)
    ) pe10 (
        .clk(clk), 
        .rst(rst), 
        .a_in(a_row1), 
        .b_in(b_00_to_10), 
        .a_out(a_10_to_11), 
        .b_out(b_10_out), 
        .c(c10)
    );

    pe #(
        .WIDTH(WIDTH),
        .TRUNC_BITS(TRUNC_BITS),
        .CORRECTION(CORRECTION),
        .ACC_WIDTH(ACC_WIDTH)
    ) pe11 (
        .clk(clk), 
        .rst(rst), 
        .a_in(a_10_to_11), 
        .b_in(b_01_to_11), 
        .a_out(a_11_out), 
        .b_out(b_11_out), 
        .c(c11)
    );

    

endmodule