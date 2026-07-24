// SPI scan: all 960 SPIs (32..991).
class gic_spi_scan_test extends gic_int_base_test;
    `uvm_component_utils(gic_spi_scan_test)
    task run_phase(uvm_phase phase);
        gic_int_scan_seq seq;
        phase.raise_objection(this);
        seq = gic_int_scan_seq::type_id::create("seq");
        seq.vif = vif;
        seq.start(agent.sqr);
        phase.drop_objection(this);
    endtask
endclass
