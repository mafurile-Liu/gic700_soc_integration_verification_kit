// GIC interrupt agent package. Includes item, driver, agent.
// Sequencer is a typedef (one-liner).
package gic_int_agent_pkg;
    import uvm_pkg::*;

    typedef uvm_sequencer #(gic_int_item) gic_int_sequencer;

    `include "gic_int_item.svh"
    `include "gic_int_driver.svh"
    `include "gic_int_agent.svh"
endpackage
