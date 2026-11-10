// CPU subsystem ECT verification components.
// The interface must be compiled before cpu_ect_agent_pkg.
tb/interfaces/cpu_ect_if.sv

+incdir+tb/agents/cpu_dbg_ect_agent
tb/agents/cpu_dbg_ect_agent/cpu_ect_agent_pkg.sv

+incdir+tb/sequences
tb/sequences/cpu_ect_seq_pkg.sv

// CPU ECT tests are included from the external CPU test package.
+incdir+sv_test/ECT
