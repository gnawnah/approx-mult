interface mac_if #(parameter WIDTH = 8) (input logic clk); // declares the interface

    // signals
    logic rst;
    logic valid;
    logic [WIDTH-1:0] a, b;
    logic [4*WIDTH-1:0] acc;

    // opens the driver's timed view
    clocking drv_cb @(posedge clk);
        default input #1step output #0; // read is immediately before edge, write is after
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