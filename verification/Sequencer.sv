


import design_params_pkg::*;
import bus_trans_pkg::*;
class Sequencer;

    mailbox #(bus_trans) drv_mbx;
    mailbox #(bus_trans) exp_mbx;

    // Constractor
    function new(mailbox #(bus_trans) drv_mbx, mailbox #(bus_trans) exp_mbx);
        this.drv_mbx = drv_mbx;
        this.exp_mbx = exp_mbx;
    endfunction


    // Loading a value into the timer
    task seq_load_timer(input logic [P_DATA_WIDTH-1:0] data);
        bus_trans tr = new();
        tr.kind = WRITE;
        tr.addr = P_ADDR_LOAD;
        tr.data = data;

        drv_mbx.put(tr);
        exp_mbx.put(tr);
    endtask

    task seq_start_timer(input bit mode);
        bus_trans tr = new();
        tr.kind = WRITE;
        tr.addr = P_ADDR_CONTROL;
        tr.data = '0; // set all the data bits to 0.
        tr.data[P_BIT_RELOAD_EN] = mode; // mode enable
        tr.data[P_BIT_START] = 1'b1; // start

        drv_mbx.put(tr);
        exp_mbx.put(tr);
    endtask

    task seq_read_timer(input logic expected_expired);
        bus_trans tr = new();
        tr.kind = READ;
        tr.addr = P_ADDR_STATUS;
        tr.data = {31'd0, expected_expired};

        drv_mbx.put(tr);
        exp_mbx.put(tr);
    endtask

    task seq_random_traffic(int num_transactions);
        repeat(num_transactions) begin
            bus_trans tr = new();
            if(!tr.randomize()) $error("Randomization FAILED!");
            drv_mbx.put(tr);
        end
    endtask


endclass : Sequencer