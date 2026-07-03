module tb_systolic_2x2;
    parameter WIDTH = 8;
    parameter TRUNC_BITS = 0;
    parameter CORRECTION = 0;
    parameter ACC_WIDTH = 32;

    reg clk = 0;
    reg rst;
    reg [WIDTH-1:0] a_row0, a_row1;
    reg [WIDTH-1:0] b_col0, b_col1;
    wire [ACC_WIDTH-1:0] c00, c01, c10, c11;

    systolic_2x2 #(.WIDTH(WIDTH),
        .TRUNC_BITS(TRUNC_BITS),
        .CORRECTION(CORRECTION),
        .ACC_WIDTH(ACC_WIDTH)
    ) dut (.clk(clk),
        .rst(rst),
        .a_row0(a_row0),
        .a_row1(a_row1),
        .b_col0(b_col0),
        .b_col1(b_col1),
        .c00(c00), .c01(c01), .c10(c10), .c11(c11)
    );

    always #5 clk = ~clk;

    initial begin

        $monitor("t=%0t, a_row0=%0d, a_row1=%0d, b_col0=%0d, b_col1=%0d, c00=%0d, c01=%0d, c10=%0d, c11=%0d",
            $time, a_row0, a_row1, b_col0, b_col1, c00, c01, c10, c11
        );

        rst = 1;

        @(posedge clk);
        @(posedge clk);
        rst = 0;
        @(negedge clk);
        a_row0 = 0;
        b_col0 = 0;
        a_row1 = 0;
        b_col1 = 0;

        @(posedge clk);
        @(posedge clk);
        @(posedge clk);

        @(negedge clk);
        a_row0 = 1;
        b_col0 = 5;
        a_row1 = 0;
        b_col1 = 0;

        @(posedge clk);

        @(negedge clk);
        a_row0 = 2;
        b_col0 = 7;
        a_row1 = 3;
        b_col1 = 6;
        @(posedge clk);

        @(negedge clk);
        a_row0 = 0;
        b_col0 = 0;
        a_row1 = 4;
        b_col1 = 8;
        @(posedge clk);

        @(posedge clk);

        @(posedge clk);

        $finish;
    end
endmodule
