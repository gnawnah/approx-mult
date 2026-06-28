`timescale 1ns/1ps
// instead of finding mismatches, we gonna find how wrong the approx mult is
module tb_mult_approx;
    reg[7:0] a, b;
    wire [15:0] p;
    reg [15:0] expected;
    integer i, j;
    integer total_abs_error = 0;
    integer max_error  = 0;
    integer this_error;

    mult_approx dut (.a(a), .b(b), .product(p));

    initial begin
        $dumpfile("mult_approx.vcd");
        $dumpvars(0, tb_mult_approx);

        for(i=0; i<256; i=i+1) begin
            for(j=0; j<256; j=j+1) begin
                a = i;
                b = j;
                #1;
                expected = i * j; // this is the correct value, a * b
                this_error = (expected > p) ? expected - p : p - expected; //find absolute error of the current value
                total_abs_error = total_abs_error + this_error; // sum
                if(this_error>max_error)
                    max_error = this_error;
            end
        end

        // the max error should be (a*b - a_t * b_t)
        $display("T test: total abs error = %0d, max error = %0d", total_abs_error, max_error);

        $finish;
    end
endmodule
