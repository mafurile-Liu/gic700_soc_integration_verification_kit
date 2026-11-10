`ifndef CPU_ECT_EVTOUT18_DBM_TEST_SV
`define CPU_ECT_EVTOUT18_DBM_TEST_SV

//----------------------------------------------------------------------
// CPU CTI channel0 -> event_out18 / DBM route.
//----------------------------------------------------------------------
class cpu_ect_evtout18_dbm_test extends cpu_ect_base_test;
    `uvm_component_utils(cpu_ect_evtout18_dbm_test)

    localparam bit [31:0] CTI_BASE  = 32'h4BF0_2000;
    localparam bit [31:0] CTI_CONTROL = 32'h000;
    localparam bit [31:0] CTI_GATE   = 32'h140;
    localparam bit [31:0] CTI_OUTEN18 = 32'h0E8;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual task test_body();
        cpu_ect_pulse_sequence pulse_seq;

        aw_seen = 1;
        `uvm_info("cpu_ect_evtout18_dbm", "begin", UVM_LOW)

        ect_write32(CTI_BASE + CTI_CONTROL, 32'h0);
        ect_write32(CTI_BASE + CTI_OUTEN18, 32'h0000_0001);
        ect_write32(CTI_BASE + CTI_GATE, 32'h0000_0001);
        ect_write32(CTI_BASE + CTI_CONTROL, 32'h0000_0001);

        ect_expect32("CONTROL", CTI_BASE + CTI_CONTROL,
                     32'h0000_0001, 32'h0000_0001);
        ect_expect32("OUTEN18", CTI_BASE + CTI_OUTEN18,
                     32'h0000_0001, 32'h0000_0001);
        ect_expect32("GATE", CTI_BASE + CTI_GATE,
                     32'h0000_0001, 32'h0000_0001);

        agent.scoreboard.expect_event(
            .loc(CPU_ECT_CTI_CH_IN_DRV), .index(0),
            .expected_value(1'b1), .timeout_cycles(1000));
        agent.scoreboard.expect_event(
            .loc(CPU_ECT_CTI_CH_IN_DRV), .index(0),
            .expected_value(1'b0), .timeout_cycles(1000));

        agent.scoreboard.expect_event(
            .loc(CPU_ECT_CTI_EVT_OUT), .index(18),
            .expected_value(1'b1), .timeout_cycles(1000));
        agent.scoreboard.expect_event(
            .loc(CPU_ECT_CTI_EVT_OUT), .index(18),
            .expected_value(1'b0), .timeout_cycles(1000));

        for (int unsigned out_idx = 0; out_idx < 18; out_idx++) begin
            agent.scoreboard.expect_no_event(
                .loc(CPU_ECT_CTI_EVT_OUT), .index(out_idx),
                .forbidden_value(1'b1), .timeout_cycles(2000));
        end

        pulse_seq = cpu_ect_pulse_sequence::type_id::create("pulse_seq");
        if (!pulse_seq.randomize() with {
                loc          == CPU_ECT_CTI_CH_IN_DRV;
                index        == 0;
                value        == 1'b1;
                pulse_cycles == 2;
            })
            `uvm_error("cpu_ect_evtout18_dbm", "pulse randomize failed")
        pulse_seq.start(agent.sequencer);

        repeat (2200) @(posedge agent.cfg.vif.clk);
        `uvm_info("cpu_ect_evtout18_dbm", "done", UVM_LOW)
    endtask
endclass

`endif
