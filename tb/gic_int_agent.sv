// GIC interrupt injection agent (consolidated). Simple: wait pe_ready,
// drive spi_int_in or ppi_int, that is it.
// Includes: item, sequencer, driver, agent. No monitor (scan seq checks result).

// ---- transaction item ----
class gic_int_item extends uvm_sequence_item;
  typedef enum bit { SPI = 1'b0, PPI = 1'b1 } int_type_e;
  typedef enum bit { DIR_INJECT = 1'b0, DIR_OUTPUT = 1'b1 } dir_e;
  typedef enum bit { TRIG_LEVEL = 1'b0, TRIG_EDGE = 1'b1 } trig_e;

  rand int_type_e int_type;
  rand dir_e      direction;
  rand int        pe_id;
  rand int        intid;
  rand trig_e     trig;
  rand int        hold_cycles;

  `uvm_object_utils_begin(gic_int_item)
    `uvm_field_enum(int_type_e, int_type, UVM_ALL_ON)
    `uvm_field_enum(dir_e, direction, UVM_ALL_ON)
    `uvm_field_enum(trig_e, trig, UVM_ALL_ON)
    `uvm_field_int(pe_id, UVM_ALL_ON)
    `uvm_field_int(intid, UVM_ALL_ON)
    `uvm_field_int(hold_cycles, UVM_ALL_ON)
  `uvm_object_utils_end

  function new(string name = "gic_int_item");
    super.new(name);
  endfunction
  constraint c_def { direction == DIR_INJECT; hold_cycles == (trig == TRIG_LEVEL) ? 100 : 1; }
endclass

// ---- sequencer (one-liner) ----
typedef uvm_sequencer #(gic_int_item) gic_int_sequencer;

// ---- driver: wait pe_ready (backdoor poll), then drive ----
class gic_int_driver extends uvm_driver #(gic_int_item);
  `uvm_component_utils(gic_int_driver)
  virtual gic_int_if vif;
  logic [31:0] tb_ready_addr  = 32'h1000_0000;
  logic [31:0] tb_result_addr = 32'h1000_0004;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual gic_int_if)::get(this, "", "vif", vif))
      `uvm_fatal("NO_VIF", "gic_int_driver: vif not set")
  endfunction
  task run_phase(uvm_phase phase);
    gic_int_item req;
    forever begin
      seq_item_port.get_next_item(req);
      if (req.direction == gic_int_item::DIR_OUTPUT) begin
        // output direction: monitor only (future), skip driving
      end else begin
        wait_pe_ready();
        if (req.int_type == gic_int_item::SPI)
          vif.spi_int_in[req.intid] = 1'b1;
        else
          vif.ppi_int[req.pe_id][req.intid] = 1'b1;
        repeat (req.hold_cycles) @(posedge vif.clk);
        if (req.int_type == gic_int_item::SPI)
          vif.spi_int_in[req.intid] = 1'b0;
        else
          vif.ppi_int[req.pe_id][req.intid] = 1'b0;
      end
      seq_item_port.item_done();
    end
  endtask
  task wait_pe_ready();
    // Backdoor poll tb_ready_addr until non-zero. TODO: use slave VIP backdoor peek.
    // Stub: wait fixed cycles (replace with actual backdoor poll of 0x1000_0000).
    repeat(50) @(posedge vif.clk);
  endtask
endclass

// ---- agent: driver + sequencer (no monitor) ----
class gic_int_agent extends uvm_agent;
  `uvm_component_utils(gic_int_agent)
  gic_int_driver    drv;
  gic_int_sequencer sqr;
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (get_is_active() == UVM_ACTIVE) begin
      sqr = gic_int_sequencer::type_id::create("sqr", this);
      drv = gic_int_driver::type_id::create("drv", this);
    end
  endfunction
  function void connect_phase(uvm_phase phase);
    if (get_is_active() == UVM_ACTIVE)
      drv.seq_item_port.connect(sqr.seq_item_export);
  endfunction
endclass
