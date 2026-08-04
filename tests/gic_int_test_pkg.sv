// GIC interrupt test package. Includes all test cases.
package gic_int_test_pkg;
    import uvm_pkg::*;
    import gic_int_agent_pkg::*;
    import gic_int_seq_pkg::*;

    `include "gic_int_base_test.sv"
    `include "gic_spi_basic_test.sv"
    `include "gic_spi_scan_test.sv"
    `include "gic_ppi_basic_test.sv"
    `include "gic_sgi_basic_test.sv"
    `include "gic_sgi_broadcast_test.sv"
    `include "gic_lpi_basic_test.sv"
endpackage
