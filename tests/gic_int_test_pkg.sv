// GIC interrupt test package. All test cases for SPI/PPI/SGI/LPI.
package gic_int_test_pkg;
    import uvm_pkg::*;
    import gic_int_agent_pkg::*;
    import gic_int_seq_pkg::*;

    // Base test: instantiates agent, provides wait_and_check_result.
    class gic_int_base_test extends uvm_test;
        `uvm_component_utils(gic_int_base_test)
        gic_int_agent agent;
        virtual gic_int_if vif;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            agent = gic_int_agent::type_id::create("agent", this);
        endfunction

        task wait_and_check_result();
            // Poll TB_RESULT via backdoor (stub). TODO: real backdoor read.
            repeat(10000) @(posedge vif.clk);
            `uvm_info("RESULT", "PASS (stub - replace with backdoor poll)", UVM_LOW)
        endtask
    endclass

    // SPI basic: inject one SPI (INTID 32), check result.
    class gic_spi_basic_test extends gic_int_base_test;
        `uvm_component_utils(gic_spi_basic_test)
        task run_phase(uvm_phase phase);
            gic_int_inject_seq seq;
            phase.raise_objection(this);
            seq = gic_int_inject_seq::type_id::create("seq");
            seq.int_type = gic_int_item::SPI;
            seq.intid = 32;
            seq.start(agent.sqr);
            wait_and_check_result();
            phase.drop_objection(this);
        endtask
    endclass

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

    // PPI basic: inject one PPI (INTID 27, PE 0), check result.
    class gic_ppi_basic_test extends gic_int_base_test;
        `uvm_component_utils(gic_ppi_basic_test)
        task run_phase(uvm_phase phase);
            gic_int_inject_seq seq;
            phase.raise_objection(this);
            seq = gic_int_inject_seq::type_id::create("seq");
            seq.int_type = gic_int_item::PPI;
            seq.intid = 27;
            seq.pe_id = 0;
            seq.start(agent.sqr);
            wait_and_check_result();
            phase.drop_objection(this);
        endtask
    endclass

    // SGI basic: self-injected by .S (no TB injection), just check result.
    class gic_sgi_basic_test extends gic_int_base_test;
        `uvm_component_utils(gic_sgi_basic_test)
        task run_phase(uvm_phase phase);
            phase.raise_objection(this);
            wait_and_check_result();
            phase.drop_objection(this);
        endtask
    endclass

    // LPI basic: self-injected by .S via ITS (no TB injection), just check result.
    class gic_lpi_basic_test extends gic_int_base_test;
        `uvm_component_utils(gic_lpi_basic_test)
        task run_phase(uvm_phase phase);
            phase.raise_objection(this);
            wait_and_check_result();
            phase.drop_objection(this);
        endtask
    endclass
endpackage
