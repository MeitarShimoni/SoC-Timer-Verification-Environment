// --------------------------------------------------
// CLASS: bus_trans  
//
// Description:
// This class defines a bus transaction with properties such as address, data, and operation kind.
// It includes constraints to limit the address and data ranges, as well as a method to display transaction details.
// --------------------------------------------------
import design_params_pkg::*;
import bus_trans_pkg::*;
class bus_trans;
    
    // --------------------- PROPERTIES -----------------------------
    rand logic [P_ADDR_WIDTH-1:0] addr;
    rand logic [P_DATA_WIDTH-1:0] data;
    rand op_kind_e kind;
    
    time timestamp; // Field to store the simulation time
    // randc int ID;
    static int ID = 0;
     
    constraint addr_c {addr inside {P_ADDR_LOAD, P_ADDR_CONTROL, P_ADDR_STATUS};}
    constraint data_range {data inside {[0:65535]};}

    // constractor
    function new();
    ID++;
    endfunction

    virtual function void display();
        $display("Transaction ID = %h | kind: %s| data: %h | addr: %h",ID,kind,data,addr);
    endfunction

endclass : bus_trans