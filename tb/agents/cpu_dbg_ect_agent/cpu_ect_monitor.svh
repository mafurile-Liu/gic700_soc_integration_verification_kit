class cpu_ect_monitor extends uvm_monitor;
  virtual cpu_ect_if vif;
  cpu_ect_cfg cfg;
  uvm_analysis_port #(cpu_ect_item) ap;

  local bit   m_valid[string];
  local logic m_value[string];

  `uvm_component_utils(cpu_ect_monitor)

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
      `uvm_fatal("CPU_ECT_MON", "cpu_ect_if virtual interface not found")
    end
    vif = cfg.vif;
  endfunction

  virtual task run_phase(uvm_phase phase);
    cpu_ect_loc_e monitored_locs[14] = '{
      CPU_ECT_CTI_EVT_IN,
      CPU_ECT_CTI_EVT_IN_ACK,
      CPU_ECT_CTI_EVT_OUT,
      CPU_ECT_CTI_EVT_OUT_ACK,
      CPU_ECT_CTI_CH_IN,
      CPU_ECT_CTI_CH_IN_DRV,
      CPU_ECT_CTI_CH_OUT,
      CPU_ECT_CLST_CHOUT,
      CPU_ECT_CLST_CHOUT_ACK,
      CPU_ECT_CLST_CHINACK,
      CPU_ECT_CLST_CHOUT_DRV,
      CPU_ECT_ASYNC_CHOUT,
      CPU_ECT_ASYNC_CHIN,
      CPU_ECT_ASYNC_CHIN_DRV
    };

    forever begin
      @(posedge vif.clk);
      foreach (monitored_locs[i]) begin
        sample_loc(monitored_locs[i]);
      end
    end
  endtask

  local function void sample_loc(cpu_ect_loc_e loc);
    for (int unsigned index = 0; index < cpu_ect_loc_width(loc); index++) begin
      string key;
      logic value;
      key = $sformatf("%s_%0d", loc.name(), index);
      value = cpu_ect_sample_bit(vif, loc, index);
      if (!m_valid.exists(key) || m_value[key] !== value) begin
        if (cfg.enable_transition_check && m_valid.exists(key)) begin
          cpu_ect_item item = cpu_ect_item::type_id::create("event");
          item.op        = cpu_ect_item::CPU_ECT_OP_LEVEL;
          item.loc       = loc;
          item.index     = index;
          item.value     = value;
          item.timestamp = $time;
          ap.write(item);
        end
        m_valid[key] = 1'b1;
        m_value[key] = value;
      end
    end
  endfunction
endclass