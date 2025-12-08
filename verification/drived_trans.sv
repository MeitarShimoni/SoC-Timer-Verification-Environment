import design_params_pkg::*;
import bus_trans_pkg::*;
// ------------------- WRITE TRANSACTIONS -----------------
class write_trans extends bus_trans;

    // constractor
    function new();
        super.new();
    endfunction

    virtual function void display();
        super.display();
        $write(" - WRITE Mode ");
    endfunction

endclass : write_trans


// ------------------- READ TRANSACTIONS -----------------
class read_trans extends bus_trans;

    // Constractor
    function new();
        super.new();
        data.rand_mode(0); // disable data randomization since data is not been generated!
        kind = READ;
    endfunction

    virtual function void display();
        super.display();
        $write(" - READ Mode :");
    endfunction

endclass : read_trans