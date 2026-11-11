class cpu_ect_pulse_sequence extends uvm_sequence #(cpu_ect_item);
  rand cpu_ect_loc_e loc          = CPU_ECT_CTI_EVT_IN;
  rand int unsigned  index        = 0;
  rand logic         value        = 1'b1;
  rand int unsigned  pulse_cycles = 2;

  constraint c_valid_index_c { index < cpu_ect_loc_width(loc); }
  constraint c_pulse_cycles_c { pulse_cycles inside {[1:16]}; }

  `uvm_object_utils(cpu_ect_pulse_sequence)

  function new(string name = "cpu_ect_pulse_sequence");
    super.new(name);
  endfunction

  virtual task body();
    cpu_ect_item item;
    item = cpu_ect_item::type_id::create("item");
    start_item(item);
    item.op           = cpu_ect_item::CPU_ECT_OP_PULSE;
    item.loc          = loc;
    item.index        = index;
    item.value        = value;
    item.pulse_cycles = pulse_cycles;
    finish_item(item);
  endtask
endclass

class cpu_ect_level_sequence extends uvm_sequence #(cpu_ect_item);
  rand cpu_ect_loc_e loc         = CPU_ECT_CTI_EVT_IN;
  rand int unsigned  index       = 9;
  rand logic         value       = 1'b1;
  rand int unsigned  hold_cycles = 20;

  constraint c_valid_index_c { index < cpu_ect_loc_width(loc); }
  constraint c_hold_cycles_c { hold_cycles inside {[1:100]}; }

  `uvm_object_utils(cpu_ect_level_sequence)

  function new(string name = "cpu_ect_level_sequence");
    super.new(name);
  endfunction

  virtual task body();
    cpu_ect_item item;
    item = cpu_ect_item::type_id::create("item");
    start_item(item);
    item.op          = cpu_ect_item::CPU_ECT_OP_LEVEL;
    item.loc         = loc;
    item.index       = index;
    item.value       = value;
    item.hold_cycles = hold_cycles;
    finish_item(item);
  endtask
endclass

class cpu_ect_handshake_sequence extends uvm_sequence #(cpu_ect_item);
  rand cpu_ect_loc_e loc            = CPU_ECT_CTI_EVT_IN;
  rand int unsigned  index          = 0;
  rand int unsigned  timeout_cycles = 100;

  constraint c_valid_index_c {
    index < cpu_ect_loc_width(loc);
    cpu_ect_ack_exists(loc, index);
  }

  `uvm_object_utils(cpu_ect_handshake_sequence)

  function new(string name = "cpu_ect_handshake_sequence");
    super.new(name);
  endfunction

  virtual task body();
    cpu_ect_item item;
    item = cpu_ect_item::type_id::create("item");
    start_item(item);
    item.op             = cpu_ect_item::CPU_ECT_OP_HANDSHAKE;
    item.loc            = loc;
    item.index          = index;
    item.value          = 1'b1;
    item.timeout_cycles = timeout_cycles;
    finish_item(item);
  endtask
endclass