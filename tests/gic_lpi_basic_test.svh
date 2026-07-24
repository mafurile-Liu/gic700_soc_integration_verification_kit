// LPI basic: self-injected by .S via ITS (no TB injection), just check result.
class gic_lpi_basic_test extends gic_int_base_test;
    `uvm_component_utils(gic_lpi_basic_test)
    task run_phase(uvm_phase phase);
        phase.raise_objection(this);
        wait_and_check_result();
        phase.drop_objection(this);
    endtask
endclass
