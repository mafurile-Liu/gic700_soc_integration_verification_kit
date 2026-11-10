`ifndef CPU_ECT_EVTOUT0_15_TEST_SV
`define CPU_ECT_EVTOUT0_15_TEST_SV

//----------------------------------------------------------------------
// CPU CTI channel_in -> event_out direct-map traversal, outputs 0..15.
//
// channel[i] -> event_out[i] is programmed with CTIOUTEN[i]=1<<i.
// This is an output-only route case; no input mapping is enabled.
//----------------------------------------------------------------------
class cpu_ect_evtout0_15_test extends cpu_ect_base_test;
    `uvm_component_utils(cpu_ect_evtout0_15_test)

    localparam bit [31:0] CTI_BASE  = 32'h4BF0_2000;
    localparam bit [31:0] CTI_CONTROL = 32'h000;
    localparam bit [31:0] CTI_GATE   = 32'h140;
    localparam int unsigned N_CH     = 16;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual task test_body();
        cpu_ect_pulse_sequence pulse_seq;
        int unsigned ch;
        int unsigned out_idx;

        aw_seen = 1;
        `uvm_info("cpu_ect_evtout0_15", "begin", UVM_LOW)

        ect_write32(CTI_BASE + CTI_CONTROL, 32'h0);
        for (int unsigned i = 0; i < N_CH; i++) begin
            ect_write32(CTI_BASE + 32'h0A0 + (i * 4), (32'h1 << i));
        end
        ect_write32(CTI_BASE + CTI_GATE, 32'h0000_FFFF);
        ect_write32(CTI_BASE + CTI_CONTROL, 32'h0000_0001);

        ect_expect32("CONTROL", CTI_BASE + CTI_CONTROL,
                     32'h0000_0001, 32'h0000_0001);
        ect_expect32("GATE", CTI_BASE + CTI_GATE,
                     32'h0000_FFFF, 32'h0000_FFFF);

        for (ch = 0; ch < N_CH; ch++) begin
            agent.scoreboard.expect_event(
                .loc(CPU_ECT_CTI_CH_IN_DRV), .index(ch),
                .expected_value(1'b1), .timeout_cycles(1000));
            agent.scoreboard.expect_event(
                .loc(CPU_ECT_CTI_CH_IN_DRV), .index(ch),
                .expected_value(1'b0), .timeout_cycles(1000));

            agent.scoreboard.expect_event(
                .loc(CPU_ECT_CTI_EVT_OUT), .index(ch),
                .expected_value(1'b1), .timeout_cycles(1000));
            agent.scoreboard.expect_event(
                .loc(CPU_ECT_CTI_EVT_OUT), .index(ch),
                .expected_value(1'b0), .timeout_cycles(1000));

            for (out_idx = 0; out_idx < 19; out_idx++) begin
                if (out_idx != ch) begin
                    agent.scoreboard.expect_no_event(
                        .loc(CPU_ECT_CTI_EVT_OUT), .index(out_idx),
                        .forbidden_value(1'b1), .timeout_cycles(2000));
                end
            end

            pulse_seq = cpu_ect_pulse_sequence::type_id::create("pulse_seq");
            if (!pulse_seq.randomize() with {
                    loc          == CPU_ECT_CTI_CH_IN_DRV;
                    index        == ch;
                    value        == 1'b1;
                    pulse_cycles == 2;
                })
                `uvm_error("cpu_ect_evtout0_15", "pulse randomize failed")
            pulse_seq.start(agent.sequencer);

            repeat (2200) @(posedge agent.cfg.vif.clk);
            `uvm_info("cpu_ect_evtout0_15",
                      $sformatf("channel%0d -> event_out%0d completed", ch, ch),
                      UVM_MEDIUM)
        end

        `uvm_info("cpu_ect_evtout0_15", "done", UVM_LOW)
    endtask
endclass

`endif
