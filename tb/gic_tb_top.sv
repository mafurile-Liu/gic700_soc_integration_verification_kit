// gic_tb_top: testbench top. Instantiates the interrupt interface, mailbox slave,
// injector, scoreboard, and placeholders for the GIC-700 DUT and the A720 PE.
//
// The A720 runs the .S test. Its AXI port drives the mailbox slave (writes to
// TB_READY_ADDR before WFI, TB_RESULT_ADDR at test_pass/test_fail). The injector
// drives the GIC SPI inputs. The scoreboard judges pass/fail.
//
// Below, the A720 is STUBBED with a small sequence to demonstrate the flow and
// to make the testbench self-checking/syntax-clean. Replace the stub with the
// real A720 + GIC RTL.
module gic_tb_top;
    import gic_tb_pkg::*;
    logic clk = 1'b0, rstn = 1'b0;
    always #5 clk = ~clk;
    initial begin repeat(10) @(posedge clk); rstn = 1'b1; end

    // interrupt interface
    gic_intv_if #(.N_SPI(N_SPI)) intv(.clk(clk), .rstn(rstn));

    // AXI4-Lite write channel (driven by A720 / stub)
    logic [31:0] awaddr, wdata; logic awvalid, wvalid, bready;
    logic awready, wready, bvalid; logic [1:0] bresp;

    // mailbox slave
    tb_mailbox_slave mb(
    .clk(clk), .rstn(rstn),
    .awaddr(awaddr), .awvalid(awvalid), .awready(awready),
    .wdata(wdata), .wvalid(wvalid), .wready(wready),
    .bresp(bresp), .bvalid(bvalid), .bready(bready),
    .pe_ready(intv.pe_ready), .test_done(intv.test_done), .test_result(intv.test_result));

    // injector
    logic [15:0] inj_id; logic [31:0] inj_hold;
    gic_injector #(.N_SPI(N_SPI)) inj(
    .clk(clk), .rstn(rstn), .trigger(intv.pe_ready),
    .spi_id(inj_id), .hold_cycles(inj_hold), .spi_int(intv.spi_int));

    // scoreboard
    gic_scoreboard #(.TIMEOUT(TIMEOUT_CYC)) sb(
    .clk(clk), .rstn(rstn), .test_done(intv.test_done), .test_result(intv.test_result));

    // ---- GIC-700 DUT placeholder ----
    // Real env: connect intv.spi_int to the GIC SPI Collator inputs, and the GIC
    // AXI slave to the A720 AXI master (so the .S test can program GICD/GICR).
    // gic_700 dut(.spi_int_i(intv.spi_int), .axi_awaddr(awaddr), ...);

    // ---- A720 stub: mimics the .S test writing the mailbox ----
    // Replace with the real A720 core model executing the .S test.
    task axi_write(input logic [31:0] addr, input logic [31:0] data);
        begin
            @(posedge clk);
            awaddr = addr; wdata = data; awvalid = 1'b1; wvalid = 1'b1; bready = 1'b1;
            @(posedge clk);
            awvalid = 1'b0; wvalid = 1'b0;
            @(posedge bvalid);
            @(posedge clk);
        end
    endtask
    initial begin
        awaddr = 0; wdata = 0; awvalid = 0; wvalid = 0; bready = 0;
        inj_id = 16'd32;// SPI INTID 32
        inj_hold = 32'd100;// hold long enough for the handler to IAR (level)
        @(posedge rstn);
        // (the real A720 would: program GIC via AXI, write TB_READY_ADDR, WFI)
        axi_write(TB_READY_ADDR, 32'h1);// PE ready -> injector fires spi_int[32]
        repeat(200) @(posedge clk);// (handler acks/eois in the real core)
        axi_write(TB_RESULT_ADDR, 32'h0);// test_pass -> result=0
    end
endmodule
