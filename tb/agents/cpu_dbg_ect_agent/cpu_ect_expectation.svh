class cpu_ect_expectation extends uvm_object;
  cpu_ect_loc_e loc;
  int unsigned  index;
  logic         expected_value;
  int unsigned  timeout_cycles;
  bit           no_event;

  `uvm_object_utils(cpu_ect_expectation)

  function new(string name = "cpu_ect_expectation");
    super.new(name);
  endfunction

  function string key();
    return $sformatf("%s_%0d", loc.name(), index);
  endfunction
endclass