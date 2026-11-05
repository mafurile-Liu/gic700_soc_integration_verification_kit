class cpu_ect_agent extends uvm_agent;
  cpu_ect_cfg cfg;
  cpu_ect_monitor monitor;
  cpu_ect_driver driver;
  cpu_ect_sequencer sequencer;
  cpu_ect_scoreboard scoreboard;

  `uvm_component_utils(cpu_ect_agent)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(cpu_ect_cfg)::get(this, "", "cfg", cfg)) begin
      cfg = cpu_ect_cfg::type_id::create("cfg");
    end
    if (cfg.vif == null &&
        !uvm_config_db#(virtual cpu_ect_if)::get(this, "", "vif", cfg.vif)) begin
      `uvm_fatal("CPU_ECT_AGENT", "cpu_ect_if virtual interface not found")
    end
    uvm_config_db#(cpu_ect_cfg)::set(this, "*", "cfg", cfg);

    monitor = cpu_ect_monitor::type_id::create("monitor", this);
    if (cfg.is_active == UVM_ACTIVE) begin
      sequencer = cpu_ect_sequencer::type_id::create("sequencer", this);
      driver = cpu_ect_driver::type_id::create("driver", this);
    end
    scoreboard = cpu_ect_scoreboard::type_id::create("scoreboard", this);
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    monitor.ap.connect(scoreboard.analysis_export);
    if (cfg.is_active == UVM_ACTIVE && driver != null) begin
      driver.seq_item_port.connect(sequencer.seq_item_export);
      driver.ap.connect(scoreboard.analysis_export);
    end
  endfunction
endclass