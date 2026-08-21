class mac_txn #(parameter WIDTH = 8);
    rand bit [WIDTH-1:0] a;
    rand bit [WIDTH-1:0] b;
    bit [4*WIDTH-1:0] acc; // this will be filled by the monitor

    function string convert2string();
        return $sformatf("a=%0d b=%0d acc=%0d",a,b,acc);
    endfunction

endclass