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

    protected task wait_chout_ack(output bit ack_seen);
        int unsigned cycles;
        virtual cpu_ect_if vif;

        vif      = agent.cfg.vif;
        ack_seen = 0;

        // Keep this window short: the normal RTL ack is expected after a
        // clk_ctm beat.  A missing ack is fatal, so later channels are not
        // injected into a stuck handshake.
        for (cycles = 0; cycles < 20 && !ack_seen; cycles++) begin
            @(posedge vif.clk);
            ack_seen = (vif.clst_ctichinack == {N_CLST{4'hF}});
        end

        if (!ack_seen)
            `uvm_fatal("cpu_ect_clusters_chout", $sformatf(
                "no CTICHINACK after channel0 injection: clst_chin=%h, clst_chinack=%h",
                vif.clst_ctichin, vif.clst_ctichinack))
        else
            `uvm_info("cpu_ect_clusters_chout", "channel0 CTICHINACK seen", UVM_MEDIUM)
    endtask
    virtual task test_body();
        cpu_ect_pulse_sequence pulse_seq;
        int unsigned ch;
        int unsigned clst;
        int unsigned flat_idx;
        int unsigned idx;
        bit          ack_seen;

        aw_seen = 1;
        open_clusters_pwr();

        bakdoor_set_svt_mem(); // Pre-load Trickbox + svt mem data
        cluster_crg_init(6'b111111);
        rvbar_init(6'b111111);
        cluster_crg_rst_init(6'b111111);
        wait( cpu_vif.debug_pwr_qacceptn[5:0]==6'b111111);
        #0.5us;

        `uvm_info("cpu_ect_clusters_chout", "begin", UVM_LOW)

        ch = 0; // Fatal-and-stop bring-up case: inject channel0 only.
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

            wait_chout_ack(ack_seen);
            `uvm_info("cpu_ect_clusters_chout",
                      "stop after channel0 injection as requested", UVM_LOW)
            return;

        `uvm_info("cpu_ect_clusters_chout", "channel0 check done", UVM_LOW)
    endtask
endclass

`endif
