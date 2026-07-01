`timescale 1ns/1ps

module tb_mac;
    parameter WIDTH = 8;
    parameter TRUNC_BITS = 2;
    parameter CORRECTION = 0;

    reg clk=0;
    reg rst;
    reg valid;
    reg [7:0] a, b;
    wire [31:0] acc; // this is wire because it is driven by the dut MAC
    reg [31:0] expected;
    integer k;

    mac #(.WIDTH(WIDTH),
    .TRUNC_BITS(TRUNC_BITS),
    .CORRECTION(CORRECTION)
    ) dut (.clk(clk),.rst(rst),.a(a),.b(b),.valid(valid),.acc(acc));

    always #5 clk = ~clk;

    initial begin
        rst = 1;
        valid = 0;
        expected = 0;
        @(posedge clk);
        @(posedge clk);
        rst = 0;

        for (k = 0; k<10; k=k+1) begin
            a = k * 25;
            b = k * 25;
            valid = 1;
            expected = expected + a * b; // accumulate the true products
            @(posedge clk); // wait for posedge so MAC gets a and b and have its own result and then accumulated
        end

        valid = 0;

        @(posedge clk);
        $display("acc=%0d, expected=%0d", acc, expected);
        if(acc===expected)
            $display("MATCH");
        else
            $display("MISMATCH: diff=%0d", expected - acc);
        $finish;
    end

endmodule
