`timescale 1ns/1ps
module tb_mult_exact;
    reg[7:0] a, b; // from dut
    wire [15:0] p; // from dut
    integer i,j; // integers, we are using 256
    integer errors = 0; // counter for number of errors)

    // this testbench is for the mult_exact dut
    mult_exact dut (.a(a), .b(b), .product(p));

    initial begin
        $dumpfile("mult_exact.vcd"); // this tells the simulator to write waveform data to the vcd file
        $dumpvars(0, tb_mult_exact); // this tells the simulator to record everything in tb and its stuff into the dumpfile

    // 65536 cases, i = 256, j = 256
     for(i=0; i<256; i=i+1) begin
        for(j=0; j<256; j=j+1) begin
            a = i; // the current i becomes a in tb, using the code from dut
            b = j; // the current j becomes b in tb, using the code from dut
            #1; // 1 unit delay
            if(p !== a*b) begin // if the p calculated using the dut is not a*b
                $display("MISMATCH: %0d * %0d = %0d (expected %0d)", a, b, p, a*b); // bad!
                errors = errors + 1; // increment error counter
            end
        end
        end
    

    if (errors == 0)
        $display("PASS: all 65536 cases are correct"); // if no errors, pre good
    else
        $display("FAIL: %0d mismatches", errors); // if error(s), no good

    $finish;
    
    end
endmodule