`ifndef CPU_ECT_CLUSTERS_CHOUT_BASE_TEST_SV
`define CPU_ECT_CLUSTERS_CHOUT_BASE_TEST_SV

//----------------------------------------------------------------------
// Common base for the four cp2cp -> cluster CTICHIN channel cases.
//
// One concrete case is run per channel (0..3).  The cp2cp channel n is
// assumed to drive channel n at the system CTI and channel n of all six
// cluster CTICHIN ports.  The flattened cluster index is cluster*4+n.
//----------------------------------------------------------------------
virtual class cpu_ect_clusters_chout_base_test extends cpu_ect_base_test;

    localparam int unsigned N_CLST     = 6;
    localparam int unsigned N_CH       = 4;
    localparam int unsigned N_CLST_IDX = N_CLST * N_CH;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    pure virtual function int unsigned channel_id();

    protected task wait_chout_ack(int unsigned ch,
                                  output bit ack_seen);
        int unsigned cycles;
        virtual cpu_ect_if vif;

        vif      = agent.cfg.vif;
        ack_seen = 0;

        // Keep this window short: the normal RTL ack is expected after a
        // clk_ctm beat.  A missing ack is fatal, so the channel case stops
        // instead of running unrelated traffic into a stuck handshake.
        for (cycles = 0; cycles < 20 && !ack_seen; cycles++) begin
            @(posedge vif.clk);
            ack_seen = (vif.clst_ctichinack == {N_CLST{4'hF}});
        end

        if (!ack_seen)
            `uvm_fatal("cpu_ect_clusters_chout", $sformatf(
                "no CTICHINACK after channel%0d injection: clst_chin=%h, clst_chinack=%h",
                ch, vif.clst_ctichin, vif.clst_ctichinack))
        else
            `uvm_info("cpu_ect_clusters_chout",
                      $sformatf("channel%0d CTICHINACK seen", ch), UVM_MEDIUM)
    endtask

    protected virtual task run_channel(int unsigned ch);
        cpu_ect_pulse_sequence pulse_seq;
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
        wait(cpu_vif.debug_pwr_qacceptn[5:0] == 6'b111111);
        #0.5us;

        `uvm_info("cpu_ect_clusters_chout",
                  $sformatf("begin channel%0d", ch), UVM_LOW)

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

        wait_chout_ack(ch, ack_seen);
        `uvm_info("cpu_ect_clusters_chout",
                  $sformatf("channel%0d injection and ack check complete", ch),
                  UVM_LOW)
    endtask

    virtual task test_body();
        run_channel(channel_id());
    endtask
endclass

`endif
