// --------------------------------------------------
// MODULE: TOP LEVEL TESTBENCH
// AUTHOR: MEITAR SHIMONI
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

    //
    // int active_transaction = 0;
    //
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

        $display("\n------------------ TEST 1 :  The Smoke Gun ------------------\n");

        single_test(.numtimes(2)); // sending 2 times random load and start
        wait(scb.is_empty()); 

        $display("\n------------------ TEST 2 :  Load Zero ------------------\n");
        
        single_test(.numtimes(1), .load_value(0)); // load zero and start the timer
        wait(scb.is_empty()); 


        $display("\n------------------ TEST 3 :  Auto- Reload ------------------\n");

        auto_reload_test(.load_value(3), .cycles(4)); // load 3 and auto-reload 4 times
        wait(scb.is_empty()); 

        $display("\n------------------ TEST 4 : count up to max value 65,535 ------------------\n");
        
        
        single_test(.numtimes(1), .load_value(65535)); // load max value and start the timer
        wait(scb.is_empty());

        $display("\n------------------ TEST 5 :  CLR STATUS ------------------\n");
        #500;
        clear_status_test();
        wait(scb.is_empty());


        // $display("\n------------------ TEST 5 :  UNMAPPED ADDRESSES ------------------\n");

        // read_unmapped_addr();
        // wait(scb.is_empty());

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
        rt.addr = P_ADDR_STATUS;
        tr = rt;
        drv_mbx.put(tr);
        exp_mbx.put(tr);

    endtask

    task read_addr(input [P_ADDR_WIDTH-1:0] address = P_ADDR_STATUS);
        bus_trans tr;

        automatic read_trans rt = new();
        rt.addr = address;
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

    // ------------------ Task for a single modular test ---------------
    task single_test(input int numtimes = 1, input int load_value = -1);     
        logic [P_DATA_WIDTH-1:0] current_load;

        repeat(numtimes) begin
            wait(scb.is_empty());
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

    task read_unmapped_addr();
            
        read_addr(.address('h01)); // another unmapped address
        read_addr(.address('h02)); // another unmapped address
        read_addr(.address('h03)); // another unmapped address
        read_addr(.address('h05)); // another unmapped address
        read_addr(.address('h07)); // another unmapped address
        read_addr(.address('hFF)); // another unmapped address

    endtask : read_unmapped_addr

    // // ---------------- manual cleating test ----------------
    task manual_clear_test();

        load_timer('hCE);
        start_timer();
        repeat(('h20 + 10)/2) @(posedge clk);
        manual_clear();
        repeat(('h20 + 10)/2) @(posedge clk);
        read_timer();
        @(posedge clk); 
        read_timer();

    endtask


    task clear_status_test();

        load_timer('h16);
        start_timer();
        repeat('h16 + 20) @(posedge clk);
        
        manual_clear();
        @(posedge clk);

        repeat(('h16 + 10)/2) @(posedge clk);
        read_timer();
        @(posedge clk); 
        read_timer();
    endtask : clear_status_test

    // ---------------- Auto - Reloading test ----------------
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


    // task test_unmapped_addr;

endmodule
