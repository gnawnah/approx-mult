interface mac_if #(parameter WIDTH = 8) (input logic clk);

    logic rst;
    logic valid;
    logic [WIDTH-1:0] a, b;
    logic [4*WIDTH-1:0] acc;

    clocking drv_cb @(posedge clk);
        default input #1step output #0;
        output rst, a, b, valid;
        input acc;
    endclocking

    clocking mon_cb @(posedge clk);
        default input #1step output #0;
        input a, b, valid, rst, acc;
    endclocking

    modport DRV (clocking drv_cb);

    modport MON (clocking mon_cb);








endinterface