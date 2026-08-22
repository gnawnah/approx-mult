class mac_monitor #(parameter WIDTH=8);

virtual mac_if.MON vif; // reaches mon_cb where everything is an input

mailbox #(mac_txn #(WIDTH)) mbx;

function new(virtual mac_if.MON vif, mailbox #(mac_txn #(WIDTH)) mbx);
    this.vif = vif;
    this.mbx = mbx;
endfunction

task run();
    forever begin
        @(vif.mon_cb); // wait for the edge
        if (vif.mon_cb.valid) begin // only cycles where the MAC actually accumulates are transactions
            mac_txn #(WIDTH) t; // a fresh object every observation
            t = new();
            t.a = vif.mon_cb.a; // sample the pins
            t.b = vif.mon_cb.b;
            t.acc = vif.mon_cb.acc;
            mbx.put(t); // monitor produces, driver consumes
        end
    end


endtask

endclass