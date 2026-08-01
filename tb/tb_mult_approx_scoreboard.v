`timescale 1ns/1ps

module tb_mult_approx_scoreboard;

    parameter WIDTH = 8;
    parameter TRUNC_BITS = 2;
    parameter CORRECTION = 0;

    reg [WIDTH-1:0] a, b;
    wire [2*WIDTH-1:0] product;

    // flags and counter
    integer pass_count = 0;
    integer fail_count = 0;
    integer i;

    mult_approx #(
        .WIDTH(WIDTH),
        .TRUNC_BITS(TRUNC_BITS),
        .CORRECTION(CORRECTION)
    ) dut (.a(a), .b(b), .product(product));

    function [2*WIDTH-1:0] ref_product;
        reg [WIDTH-1:0] a_t, b_t;
        input [WIDTH-1:0] ain, bin;
        begin
            a_t = (ain >> TRUNC_BITS) << TRUNC_BITS;
            b_t = (bin >> TRUNC_BITS) << TRUNC_BITS;
            ref_product = a_t * b_t + CORRECTION;
        end
    endfunction

    task check;
        input [WIDTH-1:0] ain, bin;
        reg [2*WIDTH-1:0] expected, got;
        begin
            a = ain;
            b = bin;
            #1;
            expected = ref_product(ain,bin);
            got = product;

            if (got !== expected) begin
                fail_count = fail_count + 1;
                $display("FAIL: a=%0d b=%0d got=%0d expected=%0d",
                    ain, bin, got, expected);
            end else pass_count = pass_count + 1;

        end
    endtask

    initial begin
        // directed cases
        check(0,0);
        check(255,255);
        check(1,0);

        // random cases
        for (i = 0; i<1000; i = i+1) begin
            check($random & 8'hFF, $random & 8'hFF);
        end

        //summary
        $display("__________________________");
        $display("PASS=%0d, FAIL=%0d", pass_count, fail_count);
        if (fail_count==0) $display("ALL TEST PASSED");
        else $display("%0d FAILURES", fail_count);
        $finish;
    end
endmodule
