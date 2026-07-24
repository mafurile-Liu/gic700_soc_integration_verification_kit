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
