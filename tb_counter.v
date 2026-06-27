`timescale 1ns/1ps
module tb_counter;
    reg clk;
    reg rst;
    wire [7:0] count;

    counter dut (.clk(clk), .rst(rst), .count(count));

    always #5 clk = ~clk;

    initial begin
        $dumpfile("counter.vcd");
        $dumpvars(0, tb_counter);

        clk = 0;
        rst = 1;

        #12 rst = 0;

        #200 $finish;

    end

    initial $monitor("t=%0t rst=%b count=%d", $time, rst, count);
endmodule