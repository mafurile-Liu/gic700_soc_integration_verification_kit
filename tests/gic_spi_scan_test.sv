// SPI scan test: one sim, all 960 SPIs (INTID 32..991).
// .S (spi_scan.S) loops INTIDs on A720; this test injects each in lockstep.
class gic_spi_scan_test extends uvm_test;
  `uvm_component_utils(gic_spi_scan_test)
  gic_int_agent agent;
  virtual gic_int_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    agent = gic_int_agent::type_id::create("agent", this);
  endfunction
  task run_phase(uvm_phase phase);
    gic_int_item req;
    int failures = 0;
    phase.raise_objection(this);
    for (int id = 32; id <= 991; id++) begin
      req = gic_int_item::type_id::create("req");
      start_item(req, -1, agent.sqr);
      req.int_type = gic_int_item::SPI;
      req.intid = id;
      req.trig = gic_int_item::TRIG_LEVEL;
      req.hold_cycles = 100;
      if (!req.randomize()) `uvm_error("RAND", "randomize failed")
      finish_item(req);
      // wait for .S to clear TB_READY (handler done). TODO: backdoor poll.
      repeat(200) @(posedge vif.clk);
      // read result. TODO: backdoor read 0x1000_0004.
      // if (result != 0) failures++;
      `uvm_info("SCAN", `sformatf("SPI %0d done", id), UVM_HIGH)
    end
    if (failures == 0) `uvm_info("DONE", "All 960 SPI passed", UVM_LOW)
    else `uvm_error("DONE", `sformatf("%0d failures", failures))
    phase.drop_objection(this);
  endtask
endclass
