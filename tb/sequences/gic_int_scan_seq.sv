// Scan all SPI INTIDs (32..991).
class gic_int_scan_seq extends uvm_sequence #(gic_int_item);
    `uvm_object_utils(gic_int_scan_seq)
    int scan_start = 32;
    int scan_end = 991;
    virtual gic_int_if vif;

    function new(string name = "gic_int_scan_seq");
        super.new(name);
    endfunction

    task body();
        gic_int_item req;
        for (int id = scan_start; id <= scan_end; id++) begin
            req = gic_int_item::type_id::create("req");
            start_item(req);
            req.int_type = gic_int_item::SPI;
            req.intid = id;
            req.trig = gic_int_item::TRIG_LEVEL;
            req.hold_cycles = 100;
            if (!req.randomize()) `uvm_error("RAND", "randomize failed")
            finish_item(req);
            repeat(200) @(posedge vif.clk);
            `uvm_info("SCAN", `sformatf("SPI %0d injected", id), UVM_HIGH)
        end
    endtask
endclass
