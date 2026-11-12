`ifndef CPU_ECT_CLUSTERS_CHOUT_TEST_SV
`define CPU_ECT_CLUSTERS_CHOUT_TEST_SV

//----------------------------------------------------------------------
// cp2cp pulse-out -> CTM -> {all cluster CTICHIN, system CTI channel-in,
// cp2cp pulse-in}.  This case does not force the system CTI channel-out.
//
// The cp2cp channel n is assumed to drive channel n at the system CTI and
// channel n of all six cluster CTICHIN ports.  The flattened cluster index
// is cluster*4 + channel.
//----------------------------------------------------------------------
class cpu_ect_clusters_chout_test extends cpu_ect_base_test;
    `uvm_component_utils(cpu_ect_clusters_chout_test)

    localparam int unsigned N_CLST = 6;
    localparam int unsigned N_CH   = 4;
    localparam int unsigned N_CLST_IDX = N_CLST * N_CH;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    protected task wait_chout_idle(output bit ok);
        int unsigned cycles;
        virtual cpu_ect_if vif;

        vif = agent.cfg.vif;
        ok  = 0;

        // The legacy channel interface is a four-phase handshake.  Do not
        // inject the next cp2cp channel until the previous CTICHIN has been
        // deasserted and all cluster CTICHINACKs have returned low.  This
        // also stops later channels from OR-ing onto a stuck CTICHIN.
        for (cycles = 0; cycles < 2000 && !ok; cycles++) begin
            @(posedge vif.clk);
            ok = (vif.cp2cp_async_pulse_in == '0 &&
                  vif.cti_channel_in        == '0 &&
                  vif.clst_ctichin          == '0 &&
                  vif.clst_ctichinack       == '0);
        end

        if (!ok)
            `uvm_error("cpu_ect_clusters_chout", $sformatf(
                "chout handshake did not return idle: cp2cp_in=%04h, cti_chin=%04h, clst_chin=%h, clst_chinack=%h",
                vif.cp2cp_async_pulse_in, vif.cti_channel_in,
                vif.clst_ctichin, vif.clst_ctichinack))
        else
            `uvm_info("cpu_ect_clusters_chout", "chout handshake idle", UVM_MEDIUM)
    endtask
    virtual task test_body();
        cpu_ect_pulse_sequence pulse_seq;
        int unsigned ch;
        int unsigned clst;
        int unsigned flat_idx;
        int unsigned idx;
        bit          chout_idle;

        aw_seen = 1;
        open_clusters_pwr();

        bakdoor_set_svt_mem(); // Pre-load Trickbox + svt mem data
        cluster_crg_init(6'b111111);
        rvbar_init(6'b111111);
        cluster_crg_rst_init(6'b111111);
        wait( cpu_vif.debug_pwr_qacceptn[5:0]==6'b111111);
        #0.5us;

        `uvm_info("cpu_ect_clusters_chout", "begin", UVM_LOW)

        for (ch = 0; ch < N_CH; ch++) begin
            agent.scoreboard.expect_event(
                .loc(CPU_ECT_ASYNC_CHIN_DRV), .index(ch),
                .expected_value(1'b1), .timeout_cycles(100));
            agent.scoreboard.expect_event(
                .loc(CPU_ECT_ASYNC_CHIN_DRV), .index(ch),
                .expected_value(1'b0), .timeout_cycles(200));

            agent.scoreboard.expect_event(
                .loc(CPU_ECT_ASYNC_CHIN), .index(ch),
                .expected_value(1'b1), .timeout_cycles(200));
            agent.scoreboard.expect_event(
                .loc(CPU_ECT_ASYNC_CHIN), .index(ch),
                .expected_value(1'b0), .timeout_cycles(200));

            agent.scoreboard.expect_event(
                .loc(CPU_ECT_CTI_CH_IN), .index(ch),
                .expected_value(1'b1), .timeout_cycles(200));
            agent.scoreboard.expect_event(
                .loc(CPU_ECT_CTI_CH_IN), .index(ch),
                .expected_value(1'b0), .timeout_cycles(200));

            for (clst = 0; clst < N_CLST; clst++) begin
                flat_idx = clst * N_CH + ch;

                agent.scoreboard.expect_event(
                    .loc(CPU_ECT_CLST_CHIN), .index(flat_idx),
                    .expected_value(1'b1), .timeout_cycles(200));
                agent.scoreboard.expect_event(
                    .loc(CPU_ECT_CLST_CHIN), .index(flat_idx),
                    .expected_value(1'b0), .timeout_cycles(200));

                agent.scoreboard.expect_event(
                    .loc(CPU_ECT_CLST_CHINACK), .index(flat_idx),
                    .expected_value(1'b1), .timeout_cycles(200));
                agent.scoreboard.expect_event(
                    .loc(CPU_ECT_CLST_CHINACK), .index(flat_idx),
                    .expected_value(1'b0), .timeout_cycles(200));
            end

            for (idx = 0; idx < 16; idx++) begin
                if (idx != ch) begin
                    agent.scoreboard.expect_no_event(
                        .loc(CPU_ECT_ASYNC_CHIN_DRV), .index(idx),
                        .forbidden_value(1'b1), .timeout_cycles(200));
                    agent.scoreboard.expect_no_event(
                        .loc(CPU_ECT_ASYNC_CHIN), .index(idx),
                        .forbidden_value(1'b1), .timeout_cycles(200));
                    agent.scoreboard.expect_no_event(
                        .loc(CPU_ECT_CTI_CH_IN), .index(idx),
                        .forbidden_value(1'b1), .timeout_cycles(200));
                end
            end

            for (idx = 0; idx < N_CLST_IDX; idx++) begin
                if ((idx % N_CH) != ch) begin
                    agent.scoreboard.expect_no_event(
                        .loc(CPU_ECT_CLST_CHIN), .index(idx),
                        .forbidden_value(1'b1), .timeout_cycles(200));
                    agent.scoreboard.expect_no_event(
                        .loc(CPU_ECT_CLST_CHINACK), .index(idx),
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
                `uvm_error("cpu_ect_clusters_chout", "pulse randomize failed")
            pulse_seq.start(agent.sequencer);

            wait_chout_idle(chout_idle);
            if (!chout_idle)
                break;

            repeat (100) @(posedge agent.cfg.vif.clk);
            `uvm_info("cpu_ect_clusters_chout",
                      $sformatf("cp2cp channel%0d -> all cluster CTICHIN completed", ch),
                      UVM_MEDIUM)
        end

        `uvm_info("cpu_ect_clusters_chout", "done", UVM_LOW)
    endtask
endclass

`endif
