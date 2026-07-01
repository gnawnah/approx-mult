module tb_mult_approx;
    parameter WIDTH = 8;
    parameter TRUNC_BITS = 2;
    parameter CORRECTION = 380;

    reg  [WIDTH-1:0]   a, b;
    wire [2*WIDTH-1:0] p;
    reg  [2*WIDTH-1:0] expected;
    integer i, j;
    integer total_abs_error = 0;
    integer max_error = 0;
    integer this_error;

    mult_approx #(.WIDTH(WIDTH), .TRUNC_BITS(TRUNC_BITS), .CORRECTION(CORRECTION)) dut (.a(a), .b(b), .product(p));

    initial begin
        for (i = 0; i < (1<<WIDTH); i = i + 1) begin 
            for (j = 0; j < (1<<WIDTH); j = j + 1) begin
                a = i; b = j;
                #1;
                expected = i * j;
                this_error = (expected > p) ? expected - p : p - expected;
                total_abs_error = total_abs_error + this_error;
                if (this_error > max_error) max_error = this_error;
            end
        end
        $display("WIDTH=%0d TRUNC=%0d: total abs error = %0d, max error = %0d",
                 WIDTH, TRUNC_BITS, total_abs_error, max_error);
        $finish;
    end
endmodule