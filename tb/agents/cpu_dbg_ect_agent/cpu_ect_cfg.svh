class cpu_ect_cfg extends uvm_object;
  virtual cpu_ect_if vif;

  uvm_active_passive_enum is_active = UVM_ACTIVE;
  int unsigned default_pulse_cycles       = 2;
  int unsigned default_timeout_cycles     = 100;
  bit          enable_transition_check    = 1'b1;

  `uvm_object_utils_begin(cpu_ect_cfg)
    `uvm_field_enum(uvm_active_passive_enum, is_active, UVM_DEFAULT)
    `uvm_field_int(default_pulse_cycles,    UVM_DEFAULT)
    `uvm_field_int(default_timeout_cycles,  UVM_DEFAULT)
    `uvm_field_int(enable_transition_check, UVM_DEFAULT)
  `uvm_object_utils_end

  function new(string name = "cpu_ect_cfg");
    super.new(name);
  endfunction
endclass
