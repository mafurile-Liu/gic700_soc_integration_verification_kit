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
        !uvm_config_db#(virtual cpu_ect_if)::get(this, "", "ect_vif", cfg.vif)) begin
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
    int unsigned timeout;
    bit ack_seen;

    if (item == null) return;
    cycles = (item.pulse_cycles != 0) ?
             item.pulse_cycles : cfg.default_pulse_cycles;
    timeout = (item.timeout_cycles != 0) ?
              item.timeout_cycles : cfg.default_timeout_cycles;

    case (item.op)
      cpu_ect_item::CPU_ECT_OP_PULSE: begin
        cpu_ect_drive_bit(vif, item.loc, item.index, 1'b1);
        repeat (cycles) @(posedge vif.clk);
        cpu_ect_drive_bit(vif, item.loc, item.index, 1'b0);
        @(posedge vif.clk);
      end

      cpu_ect_item::CPU_ECT_OP_LEVEL: begin
        int unsigned hold = (item.hold_cycles != 0) ?
                            item.hold_cycles : 1;
        cpu_ect_drive_bit(vif, item.loc, item.index, item.value);
        repeat (hold) @(posedge vif.clk);
      end

      cpu_ect_item::CPU_ECT_OP_HANDSHAKE: begin
        if (!cpu_ect_ack_exists(item.loc, item.index)) begin
          `uvm_error("CPU_ECT_DRV", $sformatf(
            "No handshake ack mapped: loc=%s index=%0d",
            item.loc.name(), item.index))
        end else begin
          cpu_ect_drive_bit(vif, item.loc, item.index, 1'b1);
          ack_seen = 1'b0;
          for (int unsigned cycle = 0;
               cycle < timeout && !ack_seen; cycle++) begin
            @(posedge vif.clk);
            ack_seen = cpu_ect_sample_ack(vif, item.loc, item.index);
          end
          cpu_ect_drive_bit(vif, item.loc, item.index, 1'b0);
          if (!ack_seen) begin
            `uvm_error("CPU_ECT_DRV", $sformatf(
              "Handshake ack timeout: loc=%s index=%0d timeout=%0d",
              item.loc.name(), item.index, timeout))
          end
        end
        @(posedge vif.clk);
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