// GIC interrupt agent. Active: drives injection. Passive: not used (future monitor).
class gic_int_agent extends uvm_agent;
    `uvm_component_utils(gic_int_agent)

    gic_int_driver    drv;
    gic_int_sequencer sqr;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (get_is_active() == UVM_ACTIVE) begin
            sqr = gic_int_sequencer::type_id::create("sqr", this);
            drv = gic_int_driver::type_id::create("drv", this);
        end
    endfunction

    function void connect_phase(uvm_phase phase);
        if (get_is_active() == UVM_ACTIVE)
            drv.seq_item_port.connect(sqr.seq_item_export);
    endfunction
endclass
