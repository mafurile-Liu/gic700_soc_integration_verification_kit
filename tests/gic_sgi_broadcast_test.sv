// SGI broadcast verification test.
// PE0 sends SGI broadcast (IRM=1, all PEs except self).
// This test reads GICR_ISPENDR0 for every PE EXCEPT the sender (exec PE)
// via frontdoor AXI to verify all other PEs received the pending SGI.
//
// The exec PE is determined by reading tube 0x13000020 (affinity format:
// [15:8]=Aff1 cluster, [7:0]=Aff0 core). The testbench writes this value
// before simulation start; bootcode reads it during setup_exception.
//
// GICR_ISPENDR0 address per PE:
//   GICR_RD_BASE + pe * GICR_STRIDE + SGI_BASE_OFFSET + 0x200
//
// The frontdoor_read32 task is a stub -- connect it to your AXI VIP.

class gic_sgi_broadcast_test extends gic_int_base_test;
    `uvm_component_utils(gic_sgi_broadcast_test)

    // SoC parameters
    localparam int N_PE          = 24;       // 6 clusters x 4 cores
    localparam int CORES_PER_CLUSTER = 4;
    localparam int SGI_INTID     = 0;
    localparam int READY_TIMEOUT = 10000;    // cycles

    // GICR address constants (match gic_common.h)
    localparam bit [31:0] GICR_RD_BASE  = 32'h1080_0000;
    localparam bit [31:0] GICR_STRIDE   = 32'h0004_0000;  // 256KB per RD
    localparam bit [31:0] SGI_BASE_OFF  = 32'h0001_0000;
    localparam bit [31:0] ISPENDR0_OFF  = 32'h0000_0200;

    // Tube addresses (match gic_common.h)
    localparam bit [31:0] TB_EXEC_PE_ADDR = 32'h1300_0020;  // exec PE affinity
    localparam bit [31:0] TB_READY_ADDR   = 32'h1300_0040;  // PE -> TB ready

    // Resolved at runtime
    int sender_pe;  // PE index of the broadcast sender (exec PE)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual gic_int_if)::get(this, "", "vif", vif))
            `uvm_fatal("NO_VIF", "gic_sgi_broadcast_test: vif not set")
    endfunction

    task run_phase(uvm_phase phase);
        phase.raise_objection(this);
        resolve_sender_pe();
        wait_pe_ready();
        // Allow time for GICD to distribute SGI to all GICRs
        repeat(100) @(posedge vif.clk);
        check_sgi_broadcast();
        phase.drop_objection(this);
    endtask

    // Read tube 0x13000020 to find which PE is the exec PE (sender).
    // Tube value is in affinity format: [15:8]=Aff1 (cluster), [7:0]=Aff0 (core).
    // Convert to sequential PE index: cluster * CORES_PER_CLUSTER + core.
    // Override affinity_to_pe_index() if your SoC has a different mapping.
    task resolve_sender_pe();
        bit [31:0] affinity;
        frontdoor_read32(TB_EXEC_PE_ADDR, affinity);
        sender_pe = affinity_to_pe_index(affinity);
        `uvm_info("BCAST",
            $sformatf("Exec PE (sender) = PE%0d (affinity=0x%04x)",
            sender_pe, affinity[15:0]), UVM_LOW)
    endtask

    // Convert affinity (Aff1.Aff0) to sequential PE index.
    // Default: pe = Aff1 * CORES_PER_CLUSTER + Aff0
    // Override if your SoC maps PEs differently.
    virtual function int affinity_to_pe_index(input bit [31:0] affinity);
        int cluster = affinity[15:8];
        int core    = affinity[7:0];
        return cluster * CORES_PER_CLUSTER + core;
    endfunction

    // Wait for exec PE to signal it sent the broadcast.
    task wait_pe_ready();
        bit [31:0] val;
        int cyc = 0;
        forever begin
            @(posedge vif.clk);
            frontdoor_read32(TB_READY_ADDR, val);
            if (val != 0) break;
            cyc++;
            if (cyc > READY_TIMEOUT) begin
                `uvm_fatal("TIMEOUT",
                    $sformatf("PE%0d did not signal ready within %0d cycles",
                    sender_pe, READY_TIMEOUT))
                return;
            end
        end
        `uvm_info("BCAST",
            $sformatf("PE%0d signaled ready, checking GICR_ISPENDR0",
            sender_pe), UVM_LOW)
    endtask

    // Read GICR_ISPENDR0 for every PE except the sender, check SGI bit.
    task check_sgi_broadcast();
        bit [31:0] ispendr0;
        int missing = 0;
        int checked = 0;
        for (int pe = 0; pe < N_PE; pe++) begin
            if (pe == sender_pe) continue;  // skip sender (IRM=1 excludes self)
            checked++;
            frontdoor_read32(gicr_ispendr0_addr(pe), ispendr0);
            if (ispendr0 & (1 << SGI_INTID)) begin
                `uvm_info("BCAST_CHK",
                    $sformatf("PE%0d: SGI %0d pending OK (ISPENDR0=0x%08x)",
                    pe, SGI_INTID, ispendr0), UVM_HIGH)
            end else begin
                `uvm_error("BCAST_CHK",
                    $sformatf("PE%0d: SGI %0d NOT pending (ISPENDR0=0x%08x)",
                    pe, SGI_INTID, ispendr0))
                missing++;
            end
        end
        if (missing == 0)
            `uvm_info("RESULT",
                $sformatf("PASS: all %0d PEs received SGI %0d broadcast (sender=PE%0d)",
                checked, SGI_INTID, sender_pe), UVM_LOW)
        else
            `uvm_error("RESULT",
                $sformatf("FAIL: %0d/%0d PEs missing SGI %0d broadcast (sender=PE%0d)",
                missing, checked, SGI_INTID, sender_pe))
    endtask

    // Compute GICR_ISPENDR0 address for a given PE index.
    function bit [31:0] gicr_ispendr0_addr(input int pe);
        return GICR_RD_BASE + pe * GICR_STRIDE + SGI_BASE_OFF + ISPENDR0_OFF;
    endfunction

    //==============================================================
    // Frontdoor AXI read -- YOU FILL THIS IN
    //==============================================================
    // Connect to your AXI VIP's read task. Example patterns:
    //
    //   // Using ARM AMBA AXI VIP:
    //   axi_vip_if.m_axi.read(addr, data, ...);
    //
    //   // Using a custom AXI agent:
    //   m_axi_agent.read_reg(addr, data);
    //
    //   // Using RAL:
    //   regmodel.default_map.read_reg(addr, status, data, UVM_FRONTDOOR);
    //
    // Until implemented, this stub does a fatal to prevent false passes.
    //==============================================================
    virtual task frontdoor_read32(
        input  bit [31:0] addr,
        output bit [31:0] data
    );
        // TODO: replace with your AXI VIP frontdoor read.
        `uvm_fatal("UNIMPL",
            $sformatf("frontdoor_read32: connect to AXI VIP, addr=0x%08x", addr))
        data = 32'h0;
    endtask
endclass
