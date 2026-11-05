// CPU ECT transaction item.
class cpu_ect_item extends uvm_sequence_item;
  typedef enum int unsigned {
    CPU_ECT_OP_PULSE     = 0,
    CPU_ECT_OP_LEVEL     = 1,
    CPU_ECT_OP_HANDSHAKE = 2
  } op_e;

  rand cpu_ect_loc_e loc;
  rand int unsigned  index;
  rand logic         value;
  rand op_e          op;
  rand int unsigned  pulse_cycles;
  rand int unsigned  hold_cycles;
  rand int unsigned  timeout_cycles;
  time timestamp;

  `uvm_object_utils_begin(cpu_ect_item)
    `uvm_field_enum(cpu_ect_loc_e, loc, UVM_ALL_ON)
    `uvm_field_enum(op_e, op, UVM_ALL_ON)
    `uvm_field_int(index, UVM_ALL_ON)
    `uvm_field_int(value, UVM_ALL_ON)
    `uvm_field_int(pulse_cycles, UVM_ALL_ON)
    `uvm_field_int(hold_cycles, UVM_ALL_ON)
    `uvm_field_int(timeout_cycles, UVM_ALL_ON)
  `uvm_object_utils_end

  function new(string name = "cpu_ect_item");
    super.new(name);
  endfunction

  function string convert2string();
    return $sformatf("%s[%0d] op=%s value=%0b pulse=%0d hold=%0d timeout=%0d",
                     loc.name(), index, op.name(), value,
                     pulse_cycles, hold_cycles, timeout_cycles);
  endfunction
endclass
