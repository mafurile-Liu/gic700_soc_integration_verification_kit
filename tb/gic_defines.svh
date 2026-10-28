// GIC address and register constants for SystemVerilog side.
// Values MUST match common/gic_common.h and common/gic_reg.h.
// If you change an address in the .h files, update this file too.

`ifndef GIC_DEFINES_SVH
`define GIC_DEFINES_SVH

// ---- SoC base addresses (source: common/gic_common.h) ----
`define GICD_BASE       32'h100F_F000
`define GICR_RD_BASE    32'h1080_0000
`define GITS_BASE       32'h1013_F000    // GICD_BASE + 0x40000

// ---- GICR frame offsets (source: common/gic_common.h + gic_reg.h) ----
`define GICR_SGI_BASE_OFF  32'h0001_0000   // SGI_base = RD_base + 0x10000
`define GICR_VLPI_BASE_OFF 32'h0002_0000   // vLPI_base = RD_base + 0x20000
`define GICR_STRIDE        32'h0004_0000   // 256KB per RD (GICv4.1)

// ---- GICR register offsets within SGI_base frame (source: gic_reg.h) ----
`define GICR_ISPENDR0_OFF  32'h0000_0200

// ---- Tube / testbench addresses (source: common/gic_common.h) ----
`define TB_BASE           32'h274F_0500
`define TB_EXEC_PE_ADDR   32'h274F_0520    // tube + 0x20: exec PE affinity
`define TB_READY_ADDR     32'h274F_0540    // tube + 0x40: PE -> TB ready
`define TB_RESULT_ADDR    32'h274F_0544    // tube + 0x44: per-INTID result
`define TB_EXPECTED_INTID 32'h274F_0548    // tube + 0x48: expected INTID
`define TB_INT_ASSERT_ADDR 32'h274F_054C    // tube + 0x4C: int acknowledged flag

// ---- SoC topology ----
`define N_PE              24              // 6 clusters x 4 cores
`define CORES_PER_CLUSTER 4

// Force-connect one DSUL timestamp checker. INDEX must be a compile-time
// cluster index because it is pasted into the hierarchical cluster name.
`define CPU_TS_DSUL_CHECKER_CONNECT(index) \
    begin \
        force tb_top.ts_dsul_checker.source_valid            = ts_source.source_valid; \
        force tb_top.ts_dsul_checker.source_gray             = ts_source.timestamp_gray; \
        force tb_top.ts_dsul_checker.dest_clk                = tb_top.u.dut.u.cluster``index``.u.cpu_cluster_cpu_pwr_domain.u_HUNTER4_wrapper.u_HUNTER4.PERIPHCLK; \
        force tb_top.ts_dsul_checker.dest_rst_n              = tb_top.u.dut.u.cluster``index``.u.cpu_cluster_cpu_pwr_domain.u_HUNTER4_wrapper.u_HUNTER4.nPERIPHRESET; \
        force tb_top.ts_dsul_checker.rtl_shifted_timestamp   = tb_top.u.dut.u.cluster``index``.u.cpu_cluster_cpu_pwr_domain.u_HUNTER4_wrapper.u_HUNTER4.CNTVALUEB[63:0]; \
        force tb_top.ts_dsul_checker.rtl_binary_timestamp    = tb_top.u.dut.u.cluster``index``.u.cpu_cluster_cpu_pwr_domain.u_HUNTER4_wrapper.u_HUNTER4.ts_cnt_bin_sync[63:0]; \
        force tb_top.ts_dsul_checker.check_enable            = cpu_vif.ts_check_en[index]; \
    end

`endif
