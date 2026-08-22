class mac_driver #(parameter WIDTH=8); // mailbox and transaction depend on WIDTH

virtual mac_if.DRV vif; // handle to an interface instance

mailbox #(mac_txn #(WIDTH)) mbx; // a thread-safe queue carrying transactions in

function new(virtual mac_if.DRV vif, mailbox #(mac_txn #(WIDTH)) mbx);
    this.vif = vif;
    this.mbx = mbx;
endfunction

task run();
    forever begin
        // driver idles with no polling loop
        mac_txn #(WIDTH) t;
        mbx.get(t); // blocks until something is availble, points t at it

        @(vif.drv_cb); // waits for clocking block's event, the rising edge
        vif.drv_cb.a <= t.a;
        vif.drv_cb.b <= t.b;
        vif.drv_cb.valid <= 1'b1;
    end
endtask

endclass