`ifndef CPU_ECT_BASE_TEST_SV
`define CPU_ECT_BASE_TEST_SV

//----------------------------------------------------------------------
// Base test for the CPU subsystem ECT agent.  It assumes the external
// cpu_debug_base_test provides aw_seen and DBG_GETREG32/DBG_SETREG32.
//----------------------------------------------------------------------
class cpu_ect_base_test extends cpu_debug_base_test;
    `uvm_component_utils(cpu_ect_base_test)

    cpu_ect_agent agent;
    bit [31:0] rd_data;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        // All CPU ECT tests use source injection.  Fail fast if the TB
        // plusarg is omitted; otherwise the connect file silently leaves
        // every injection path unforced.
        if (!$test$plusargs("CPU_ECT_ENABLE_SOURCE_FORCE"))
            `uvm_fatal("cpu_ect_base",
                       "missing +CPU_ECT_ENABLE_SOURCE_FORCE")

        agent = cpu_ect_agent::type_id::create("agent", this);
    endfunction

    protected task ect_write32(bit [31:0] addr, bit [31:0] data);
        DBG_SETREG32(addr, data);
    endtask

    protected task ect_read32(bit [31:0] addr, output bit [31:0] data);
        DBG_GETREG32(addr, data);
    endtask

    protected task ect_expect32(string name,
                                bit [31:0] addr,
                                bit [31:0] mask,
                                bit [31:0] expected);
        bit [31:0] got;
        DBG_GETREG32(addr, got);
        `uvm_info("cpu_ect", $sformatf("%s = %08h (mask %08h, expected %08h)",
                                       name, got, mask, expected), UVM_LOW)
        if ((got & mask) != (expected & mask))
            `uvm_error("cpu_ect", $sformatf("%s = %08h, expected %08h (mask %08h)",
                                            name, got, expected, mask))
    endtask
endclass

`endif