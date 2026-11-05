class cpu_ect_driver extends uvm_driver #(cpu_ect_item);
  virtual cpu_ect_if vif;
  cpu_ect_cfg        cfg;
  uvm_analysis_port #(cpu_ect_item) ap;

  `uvm_component_utils(cpu_ect_driver)

  function new(string name, uvm_component parent);
    super.new(name, parent);
    ap = new("ap", this);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(cpu_ect_cfg)::get(this, "", "cfg", cfg)) begin
      cfg = cpu_ect_cfg::type_id::create("cfg");
    end
    if (cfg.vif == null &&
        !uvm_config_db#(virtual cpu_ect_if)::get(this, "", "vif", cfg.vif)) begin
      `uvm_fatal("CPU_ECT_DRV", "cpu_ect_if virtual interface not found")
    end
    vif = cfg.vif;
  endfunction

  virtual task run_phase(uvm_phase phase);
    cpu_ect_item item;
    forever begin
      seq_item_port.get_next_item(item);
      drive_item(item);
      seq_item_port.item_done();
    end
  endtask

  local task drive_item(cpu_ect_item item);
    int unsigned cycles;

    if (item == null) return;
    cycles = (item.pulse_cycles != 0) ?
             item.pulse_cycles : cfg.default_pulse_cycles;

    case (item.op)
      CPU_ECT_OP_PULSE: begin
        cpu_ect_drive_bit(vif, item.loc, item.index, 1'b1);
        repeat (cycles) @(posedge vif.clk);
        cpu_ect_drive_bit(vif, item.loc, item.index, 1'b0);
        @(posedge vif.clk);
      end

      CPU_ECT_OP_LEVEL: begin
        int unsigned hold = (item.hold_cycles != 0) ?
                            item.hold_cycles : 1;
        cpu_ect_drive_bit(vif, item.loc, item.index, item.value);
        repeat (hold) @(posedge vif.clk);
      end

      default: begin
        `uvm_error("CPU_ECT_DRV",
          $sformatf("Unsupported op: %s", item.op.name()))
      end
    endcase

    item.timestamp = $time;
    ap.write(item);
  endtask
endclass