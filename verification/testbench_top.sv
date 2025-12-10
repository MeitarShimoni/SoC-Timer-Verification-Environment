// --------------------------------------------------
// MODULE: TOP LEVEL TESTBENCH
//
// Description:
// This is the top level testbench that instantiates the DUT and the verification components
// like Driver, Monitor, Scoreboard and Sequencer.
// --------------------------------------------------

`include "Driver.sv"
`include "Monitor.sv"
`include "Scoreboard.sv"
`include "Sequencer.sv"

import design_params_pkg::*;
import bus_trans_pkg::*;

module testbench_top;

    logic clk = 0;
    always #5 clk = ~clk;

    // instanciating the bus interface
    bus_if bus_if(.clk(clk));

    // mailbox 
    mailbox #(bus_trans) drv_mbx;
    mailbox #(bus_trans) exp_mbx;
    mailbox #(bus_trans) act_mbx;

    // instanciating classes
    Driver drv;
    Monitor mon;
    Scoreboard scb;
    bus_trans trans;
    Sequencer seq;

    // instanciating the dut // _update
    timer_periph_update DUT( 
        .clk      (bus_if.clk),      
        .reset_n  (bus_if.reset_n),
        .req      (bus_if.req),
        .gnt      (bus_if.gnt),
        .addr     (bus_if.addr),
        .wdata    (bus_if.wdata),
        .rdata    (bus_if.rdata),
        .write_en (bus_if.write_en) );

    // instanciating SVA checker
    timer_sva chk(
        .clk      (bus_if.clk),       
        .reset_n  (bus_if.reset_n),
        .req      (bus_if.req),
        .gnt      (bus_if.gnt),
        .addr     (bus_if.addr),
        .wdata    (bus_if.wdata),
        .rdata    (bus_if.rdata),
        .write_en (bus_if.write_en) );

    // instnaciating the class related

    initial begin

        drv_mbx = new();
        exp_mbx = new();
        act_mbx = new();

        drv = new(bus_if,drv_mbx);
        mon = new(bus_if,act_mbx);
        scb = new(exp_mbx, act_mbx);
        seq = new(drv_mbx,exp_mbx);
        // -------------- parallelizing the driver, monitor and scoreboard ---
        
        $display("Staring Test...");
        bus_if.reset_n = 1;
        drv.reset();
        
        @(negedge clk) bus_if.reset_n = 0; // reset
        @(posedge clk) bus_if.reset_n = 1; // de assert reset.
        $display("reset released!");

        repeat(5) @(posedge clk);
        
        fork
            drv.run(); // add a semaphore to the driver.
            mon.run();
            scb.run();
        join_none
        
        
        // ------------------------------- TESTS ----------------------------------
        $display("");
        $display("------------------ TEST 1 :  The Smoke Gun -----------------");

        // single_test(10);

        // sending 2 times random load and start
        single_test(.numtimes(2));

        $display("");
        $display("------------------ TEST 2 :  Load Zero -----------------");
        // load zero and start the timer
        single_test(.numtimes(1), .load_value(0));

        $display("");
        $display("------------------ TEST 3 :  Auto- Reload -----------------");

        auto_reload_test(.load_value(3), .cycles(4));

        // TEST 4: Random Traffic
        

        // TEST 5: Edge Cases
        // load max value and start the timer
        single_test(.numtimes(1), .load_value(65535));

        
        $display("");
        // ------------------------------------ ----------------------------------

        fork
            // Thread A: Wait until scoreboard matches everything
            begin
                wait(scb.is_empty()); 
                $display("Scoreboard Empty - All transactions passed!");
            end
            
            // Thread B: Safety Timeout (in case DUT hangs)
            begin
                #10000; 
                $error("TIMEOUT: Scoreboard never emptied!");
            end
        join_any // Finishes when the FIRST of the two threads finishes



        #400;
        
        $display("Test Finished! at %t ", $time);
        $finish;
    end

    task single_transaction();
        bus_trans tr;

        tr = new();
        if(!tr.randomize()) begin
            $error("Randomization FAILD");
            $finish; //
        end else begin
            drv_mbx.put(tr);
            exp_mbx.put(tr);
        end

    endtask : single_transaction

    // ----------- task to load the timer --------------  
    task load_timer(input logic [P_DATA_WIDTH-1:0] data);
        
        bus_trans tr;
        tr = new();
        tr.kind = WRITE;
        tr.addr = P_ADDR_LOAD;
        tr.data = data;
        drv_mbx.put(tr);
        exp_mbx.put(tr);
    endtask

    // ----------- task to start the timer --------------
    task start_timer();
        
        bus_trans tr;
        tr = new();
        tr.kind = WRITE;
        tr.addr = P_ADDR_CONTROL;
        tr.data = '0;
        tr.data[P_BIT_START] = 1;
        tr.data[P_BIT_RELOAD_EN] = 0;
        tr.data[P_BIT_CLR_STATUS] = 0; // doesnt clear it loops!!!!!!!!!!!!

        drv_mbx.put(tr);
        exp_mbx.put(tr);

    endtask

    // ----------- task to read the timer --------------
    task read_timer();
        bus_trans tr;

        automatic read_trans rt = new();
        // rt.kind = READ;
        rt.addr = P_ADDR_STATUS;
        tr = rt;
        drv_mbx.put(tr);
        exp_mbx.put(tr);

    endtask

    task read_addr(input [P_ADDR_WIDTH-1:0] address);
        bus_trans tr;

        automatic read_trans rt = new();
        // rt.kind = READ;
        rt.addr = P_ADDR_STATUS;
        tr = rt;
        drv_mbx.put(tr);
        exp_mbx.put(tr);

    endtask

    // ----------- task to clear the timer --------------
    task manual_clear();
        bus_trans tr;
        tr = new();
        tr.kind = WRITE;
        tr.addr = P_ADDR_CONTROL;
        tr.data = '0;
        tr.data[P_BIT_START] = 0;
        tr.data[P_BIT_RELOAD_EN] = 0;
        tr.data[P_BIT_CLR_STATUS] = 1; 

        drv_mbx.put(tr);
        exp_mbx.put(tr);

    endtask
    // ----------- task to generate random traffic --------------
    task random_traffic(int num_trans);
        bus_trans tr;
        repeat(num_trans) begin
            // wt = new();
            automatic write_trans wt = new();
            if(!wt.randomize()) $error("FAILD TO RANDOMIZE!");
            tr = wt;
            drv_mbx.put(tr);
            exp_mbx.put(tr);
        end

    endtask





    // modify later
    task reset_all;
        bus_if.reset_n = 1;
        drv.reset();
        @(negedge clk) bus_if.reset_n = 0; // reset
        @(posedge clk) bus_if.reset_n = 1; // de assert reset.
        $display("reset released!");
    endtask

    



    task single_test(input int numtimes = 1, input int load_value = -1);     
        logic [P_DATA_WIDTH-1:0] current_load;

        repeat(numtimes) begin
            
            
        
            if (load_value == -1) begin
                current_load = $urandom_range(0, 25);
                $display("Running test with RANDOM value: %0d", current_load);
            end else begin
                current_load = load_value;
                $display("Running test with FIXED value: %0d", current_load);
            end

            repeat(10) @(posedge clk);
            load_timer(current_load); // שים לב: משתמשים ב-current_load
            start_timer();
            
            repeat(current_load + 10) @(posedge clk); 
            
            read_timer(); 
            @(posedge clk);
            read_timer(); 
            @(posedge clk);
            read_timer(); 
        end

    endtask


    task auto_reload_test(input int load_value = 5, input int cycles = 3);

        bus_trans tr;
        // automatic write_trans wt = new(); 

        $display("time : %t Running Auto-Reload test with Load Value: %0d for %0d cycles",$time(), load_value, cycles);
        load_timer(load_value);

        repeat(5) @(posedge clk);
        
        tr = new();
        tr.kind = WRITE; 
        tr.addr = P_ADDR_CONTROL;
        tr.data = '0;

        tr.data[P_BIT_START] = 1;
        tr.data[P_BIT_RELOAD_EN] = 1; // enable auto-reload
        drv_mbx.put(tr);
        exp_mbx.put(tr);

        repeat(cycles) begin
            repeat(load_value + 10) @(posedge clk); 
            read_timer(); 
            @(posedge clk);
            read_timer(); 
            @(posedge clk);
            read_timer(); 
            $display("Completed cycle with auto-reload.");
        end

        manual_clear(); 
    endtask

endmodule