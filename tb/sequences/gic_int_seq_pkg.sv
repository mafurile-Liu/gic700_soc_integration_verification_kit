// GIC interrupt sequence package.
package gic_int_seq_pkg;
    import uvm_pkg::*;
    import gic_int_agent_pkg::*;

    `include "gic_int_inject_seq.sv"
    `include "gic_int_scan_seq.sv"
endpackage
