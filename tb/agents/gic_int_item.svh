// GIC interrupt transaction item.
class gic_int_item extends uvm_sequence_item;
    typedef enum bit { SPI = 1'b0, PPI = 1'b1 } int_type_e;
    typedef enum bit { DIR_INJECT = 1'b0, DIR_OUTPUT = 1'b1 } dir_e;
    typedef enum bit { TRIG_LEVEL = 1'b0, TRIG_EDGE = 1'b1 } trig_e;

    rand int_type_e int_type;
    rand dir_e      direction;
    rand int        pe_id;
    rand int        intid;
    rand trig_e     trig;
    rand int        hold_cycles;

    `uvm_object_utils_begin(gic_int_item)
        `uvm_field_enum(int_type_e, int_type, UVM_ALL_ON)
        `uvm_field_enum(dir_e, direction, UVM_ALL_ON)
        `uvm_field_enum(trig_e, trig, UVM_ALL_ON)
        `uvm_field_int(pe_id, UVM_ALL_ON)
        `uvm_field_int(intid, UVM_ALL_ON)
        `uvm_field_int(hold_cycles, UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "gic_int_item");
        super.new(name);
    endfunction

    constraint c_def {
        direction == DIR_INJECT;
        hold_cycles == (trig == TRIG_LEVEL) ? 100 : 1;
    }
endclass
