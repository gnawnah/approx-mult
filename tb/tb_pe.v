module tb_pe;
    parameter WIDTH = 8;
    parameter TRUNC_BITS = 0;
    parameter CORRECTION = 0;
    parameter ACC_WIDTH = 32;

    reg clk = 0;
    reg rst;
    reg [WIDTH-1:0] a_in = 0, b_in = 0;
    wire [WIDTH-1:0] a_out, b_out;
    wire [ACC_WIDTH-1:0] c;

    pe #(.WIDTH(WIDTH),
        .TRUNC_BITS(TRUNC_BITS), 
        .CORRECTION(CORRECTION),
        .ACC_WIDTH(ACC_WIDTH)
    ) dut (.clk(clk), .rst(rst), .a_in(a_in), .b_in(b_in), .a_out(a_out), .b_out(b_out), .c(c));

    always #5 clk = ~clk;

    initial begin

        $monitor("t=%0t, a_in=%0d, b_in=%0d, acc=%0d, a_out=%0d, b_out=%0d",
            $time, a_in, b_in, c, a_out, b_out
        );

        rst = 1;
        @(posedge clk);
        @(posedge clk);
        rst = 0;

        @(negedge clk);
        a_in = 2;
        b_in = 3;
        @(posedge clk);

        @(negedge clk);
        a_in = 4;
        b_in = 5;
        @(posedge clk);

        @(negedge clk);
        a_in = 1;
        b_in = 6;
        @(posedge clk);
        a_in = 0;
        b_in = 0;

        @(posedge clk);

        $finish;
    end
endmodule

