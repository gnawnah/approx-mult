module tb_mem_systolic;
    parameter WIDTH = 8;
    parameter DEPTH = 5;
    parameter CORRECTION = 0;
    parameter ADDR = 3;
    parameter ACC_WIDTH = 32;

    reg clk = 0;
    reg rst;
    reg [WIDTH-1:0] a_row0, a_row1;
    wire [ADDR-1:0] addr0, addr1;
    wire [WIDTH-1:0] b_col0, b_col1;
    wire [31:0] c00, c01, c10, c11;

    addr_gen #(.WIDTH(WIDTH), .DEPTH(DEPTH), .ADDR(ADDR)) u_addr_gen (
        .clk(clk), .rst(rst), .addr0(addr0), .addr1(addr1)
    );

    weight_mem #(.WIDTH(WIDTH), .DEPTH(DEPTH), .ADDR(ADDR)) u_weight_mem(
        .clk(clk), .addr0(addr0), .addr1(addr1), .data_out0(b_col0), .data_out1(b_col1)
    );

    systolic_2x2 u_systolic_2x2(
        .clk(clk), .rst(rst), .a_row0(a_row0), .a_row1(a_row1),
        .b_col0(b_col0), .b_col1(b_col1), .c00(c00), .c01(c01), .c10(c10), .c11(c11)
    );

    always #5 clk = ~clk;

    initial begin
        rst = 1;
        a_row0 = 0;
        a_row1 = 0;

        @(posedge clk); @(posedge clk);

        @(negedge clk); rst = 0;

        @(posedge clk); // T=0 wait for b to be loaded

        @(negedge clk);
        a_row0 = 1; // T=1, load b_col0 and a_row0
        @(posedge clk);

        @(negedge clk);
        a_row0 = 2; a_row1 = 3;
        @(posedge clk);

        @(negedge clk);
        a_row0 = 0; a_row1 = 4;
        @(posedge clk);

        @(negedge clk);
        a_row0 = 0; a_row1 = 0;
        @(posedge clk); @(posedge clk); @(posedge clk);

        $display("c00: %0d, c01: %0d, c10: %0d, c11: %0d", c00, c01, c10, c11);
        $finish;
    end
endmodule






