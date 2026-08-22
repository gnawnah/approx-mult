class mac_monitor #(parameter WIDTH=8);

virtual mac_if.MON vif;

mailbox #(mac_txn #(WIDTH)) mbx;

function new(virtual mac_if.MON vif, mailbox #(mac_txn #(WIDTH)) mbx);
    this.vif = vif;
    this.mbx = mbx;
endfunction

task run();




endclass