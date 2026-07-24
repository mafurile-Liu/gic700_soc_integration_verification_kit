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
        repeat(10000) @(posedge vif.clk);
        `uvm_info("RESULT", "PASS (stub - replace with backdoor poll)", UVM_LOW)
    endtask
endclass
