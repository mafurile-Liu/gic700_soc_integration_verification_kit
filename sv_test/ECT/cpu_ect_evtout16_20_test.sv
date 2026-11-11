`ifndef CPU_ECT_EVTOUT16_20_TEST_SV
`define CPU_ECT_EVTOUT16_20_TEST_SV

//----------------------------------------------------------------------
// cp2cp async-bridge pulse -> CPU CTI channel -> event_out group 16..20.
//
// Routes:
//   channel[0] -> event_out[16] / pmu_m17.cti_trig_in[2]
//   channel[1] -> event_out[17] / pmu_m17.cti_trig_in[3]
//   channel[2] -> event_out[18] / u_dbm_cfgbus.cti_trig_i
//   channel[3] -> event_out[19] / soc TCU pmusnapshot async pulse
//   channel[4] -> event_out[20] / NPU TCU pmusnapshot async pulse
//----------------------------------------------------------------------
class cpu_ect_evtout16_20_test extends cpu_ect_base_test;
    `uvm_component_utils(cpu_ect_evtout16_20_test)

    localparam bit [31:0] CTI_BASE  = 32'h4BF0_2000;
    localparam bit [31:0] CTI_CONTROL = 32'h000;
    localparam bit [31:0] CTI_GATE   = 32'h140;
    localparam bit [31:0] CTI_OUTEN16 = 32'h0E0;
    localparam int unsigned N_CH     = 5;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual task test_body();
        cpu_ect_pulse_sequence pulse_seq;
        int unsigned ch;
        int unsigned out_idx;

        aw_seen = 1;
        `uvm_info("cpu_ect_evtout16_20", "begin", UVM_LOW)

        ect_write32(CTI_BASE + CTI_CONTROL, 32'h0);
        for (int unsigned i = 0; i < N_CH; i++) begin
            ect_write32(CTI_BASE + 32'h0E0 + (i * 4), (32'h1 << i));
        end
        ect_write32(CTI_BASE + CTI_GATE, 32'h0000_001F);
        ect_write32(CTI_BASE + CTI_CONTROL, 32'h0000_0001);

        ect_expect32("CONTROL", CTI_BASE + CTI_CONTROL,
                     32'h0000_0001, 32'h0000_0001);
        ect_expect32("GATE", CTI_BASE + CTI_GATE,
                     32'h0000_001F, 32'h0000_001F);
        for (int unsigned i = 0; i < N_CH; i++) begin
            ect_expect32($sformatf("OUTEN%0d", i + 16),
                         CTI_BASE + 32'h0E0 + (i * 4),
                         32'h0000_001F, (32'h1 << i));
        end

        for (ch = 0; ch < N_CH; ch++) begin
            out_idx = ch + 16;

            agent.scoreboard.expect_event(
                .loc(CPU_ECT_ASYNC_CHIN_DRV), .index(ch),
                .expected_value(1'b1), .timeout_cycles(100));
            agent.scoreboard.expect_event(
                .loc(CPU_ECT_ASYNC_CHIN_DRV), .index(ch),
                .expected_value(1'b0), .timeout_cycles(100));

            agent.scoreboard.expect_event(
                .loc(CPU_ECT_CTI_EVT_OUT), .index(out_idx),
                .expected_value(1'b1), .timeout_cycles(100));
            agent.scoreboard.expect_event(
                .loc(CPU_ECT_CTI_EVT_OUT), .index(out_idx),
                .expected_value(1'b0), .timeout_cycles(200));

            for (out_idx = 0; out_idx < 21; out_idx++) begin
                if (out_idx != (ch + 16)) begin
                    agent.scoreboard.expect_no_event(
                        .loc(CPU_ECT_CTI_EVT_OUT), .index(out_idx),
                        .forbidden_value(1'b1), .timeout_cycles(200));
                end
            end

            pulse_seq = cpu_ect_pulse_sequence::type_id::create("pulse_seq");
            if (!pulse_seq.randomize() with {
                    loc          == CPU_ECT_ASYNC_CHIN_DRV;
                    index        == ch;
                    value        == 1'b1;
                    pulse_cycles == 2;
                })
                `uvm_error("cpu_ect_evtout16_20", "pulse randomize failed")
            pulse_seq.start(agent.sequencer);

            repeat (220) @(posedge agent.cfg.vif.clk);
            `uvm_info("cpu_ect_evtout16_20",
                      $sformatf("channel%0d -> event_out%0d completed", ch, ch + 16),
                      UVM_MEDIUM)
        end

        `uvm_info("cpu_ect_evtout16_20", "done", UVM_LOW)
    endtask
endclass

`endif