class cpu_ect_scoreboard extends uvm_scoreboard;
  virtual cpu_ect_if vif;
  cpu_ect_cfg cfg;
  uvm_analysis_imp #(cpu_ect_item, cpu_ect_scoreboard) analysis_export;

  local cpu_ect_expectation expectations[$];
  local int unsigned observed_count[string];
  local logic observed_value[string];
  local bit observed_valid[string];

  `uvm_component_utils(cpu_ect_scoreboard)

  function new(string name, uvm_component parent);
    super.new(name, parent);
    analysis_export = new("analysis_export", this);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(cpu_ect_cfg)::get(this, "", "cfg", cfg)) begin
      cfg = cpu_ect_cfg::type_id::create("cfg");
    end
    if (cfg.vif == null &&
        !uvm_config_db#(virtual cpu_ect_if)::get(this, "", "ect_vif", cfg.vif)) begin
      `uvm_fatal("CPU_ECT_SB", "cpu_ect_if virtual interface not found")
    end
    vif = cfg.vif;
  endfunction

  function void expect_event(cpu_ect_loc_e loc,
                             int unsigned index,
                             logic expected_value,
                             int unsigned timeout_cycles = 0);
    cpu_ect_expectation exp;
    if (index >= cpu_ect_loc_width(loc)) begin
      `uvm_error("CPU_ECT_SB", $sformatf(
        "Invalid expected index: loc=%s index=%0d", loc.name(), index))
      return;
    end
    exp = cpu_ect_expectation::type_id::create("expectation");
    exp.loc = loc;
    exp.index = index;
    exp.expected_value = expected_value;
    exp.timeout_cycles = (timeout_cycles != 0) ?
                         timeout_cycles : cfg.default_timeout_cycles;
    expectations.push_back(exp);
    `uvm_info("CPU_ECT_SB", $sformatf("Added expectation: %s",
              exp.convert2string()), UVM_MEDIUM)
  endfunction

  function void expect_no_event(cpu_ect_loc_e loc,
                                int unsigned index,
                                logic forbidden_value = 1'b1,
                                int unsigned timeout_cycles = 0);
    cpu_ect_expectation exp;
    if (index >= cpu_ect_loc_width(loc)) begin
      `uvm_error("CPU_ECT_SB", $sformatf(
        "Invalid no-event index: loc=%s index=%0d", loc.name(), index))
      return;
    end
    exp = cpu_ect_expectation::type_id::create("no_event");
    exp.loc = loc;
    exp.index = index;
    exp.expected_value = forbidden_value;
    exp.no_event = 1'b1;
    exp.timeout_cycles = (timeout_cycles != 0) ?
                         timeout_cycles : cfg.default_timeout_cycles;
    expectations.push_back(exp);
    `uvm_info("CPU_ECT_SB", $sformatf("Added no-event: %s",
              exp.convert2string()), UVM_MEDIUM)
  endfunction

  local function string item_key(cpu_ect_item item);
    return $sformatf("%s_%0d", item.loc.name(), item.index);
  endfunction

  local function void process_event(cpu_ect_item item);
    string key = item_key(item);
    observed_count[key]++;
    observed_value[key] = item.value;
    observed_valid[key] = 1'b1;

    for (int unsigned i = 0; i < expectations.size(); i++) begin
      if (expectations[i].loc == item.loc &&
          expectations[i].index == item.index) begin
        if (expectations[i].no_event &&
            expectations[i].expected_value === item.value) begin
          `uvm_error("CPU_ECT_SB", $sformatf(
            "Unexpected ECT transition: %s", item.convert2string()))
          expectations.delete(i);
          return;
        end
        if (!expectations[i].no_event &&
            expectations[i].expected_value === item.value) begin
          `uvm_info("CPU_ECT_SB", $sformatf(
            "Matched expectation: %s", item.convert2string()), UVM_MEDIUM)
          expectations.delete(i);
          return;
        end
      end
    end
  endfunction

  virtual function void write(cpu_ect_item item);
    if (item != null) process_event(item);
  endfunction

  virtual task run_phase(uvm_phase phase);
    forever begin
      @(posedge vif.clk);
      for (int unsigned i = expectations.size(); i > 0; i--) begin
        int unsigned idx = i - 1;
        if (expectations[idx].timeout_cycles == 0) begin
          if (expectations[idx].no_event) begin
            `uvm_info("CPU_ECT_SB", $sformatf(
              "ECT no-event window passed: %s",
              expectations[idx].convert2string()), UVM_MEDIUM)
          end else begin
            `uvm_error("CPU_ECT_SB", $sformatf(
              "ECT expectation timeout: loc=%s index=%0d expected=%0b",
              expectations[idx].loc.name(), expectations[idx].index,
              expectations[idx].expected_value))
          end
          expectations.delete(idx);
        end else begin
          expectations[idx].timeout_cycles--;
        end
      end
    end
  endtask

  function int unsigned get_observed_count(cpu_ect_loc_e loc,
                                           int unsigned index);
    string key = $sformatf("%s_%0d", loc.name(), index);
    return observed_count.exists(key) ? observed_count[key] : 0;
  endfunction
endclass
