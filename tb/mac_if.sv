interface mac_if;

    parameter WIDTH = 8;
    
    logic clk = 0;
    logic rst;
    logic valid;
    logic [WIDTH-1] a, b;
    logic [4*WIDTH-1:0] acc;
    logic [4*WIDTH-1:0] expected;







endinterface