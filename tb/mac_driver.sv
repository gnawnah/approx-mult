class mac_driver #(parameter WIDTH=8);

virtual mac_if.DRV vif;

mailbox #(mac_txn #(WIDTH)) mbx;

function new(virtual mac_if.DRV vif, mailbox #(mac_txn #(WIDTH)) mbx);
    this.vif = vif;
    this.mbx = mbx;
endfunction

task run();
    forever begin
        mac_txn #(WIDTH) t;
        mbx.get(t);
        @(vif.drv_cb);
        vif.drv_cb.a <= t.a;
        vif.drv_cb.b <= t.b;
        vif.drv_cb.valid <= 1'b1;
    end
endtask

endclass