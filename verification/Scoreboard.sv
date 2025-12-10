// --------------------------------------------------
// CLASS: Scoreboard
//
// Description:
// this class is a scoreboard for the timer_pripheral DUT

// --------------------------------------------------
import bus_trans_pkg::*;
import design_params_pkg::*;
class Scoreboard;

    mailbox #(bus_trans) driver_mbx,monitor_mbx;
    // Constractor
    function new(mailbox #(bus_trans) driver_mbx, mailbox #(bus_trans)monitor_mbx);
        this.driver_mbx = driver_mbx;
        this.monitor_mbx = monitor_mbx;    
    endfunction
    
    bus_trans tran1, tran2;
    bus_trans tran1_q[$];
    bus_trans tran2_q[$];


    // ------- reference model --------    
    logic [31:0] counter_reg;

    logic [31:0] control_reg;
    logic [31:0] load_reg;
    logic [31:0] status_reg;
    real start_count;
    bit status_cleared, reload_active;

    // ------- reference model --------


    task run();
        fork
            
            forever begin
                driver_mbx.get(tran1);
                tran1_q.push_back(tran1);

                // $write("At Time %t driver mbx - ", $time); // debug
                // tran1.display();
            end 

            forever begin
                monitor_mbx.get(tran2);
                tran2_q.push_back(tran2);
                // $write("At Time %t monitor mbx - ", $time); // debug
                // tran2.display();

            end

            forever begin
                
                bus_trans t1,t2;
                wait(tran2_q.size() !=0 && tran1_q.size() != 0);
                t1 = tran1_q.pop_front();
                t2 = tran2_q.pop_front();
                // --------------------- WRITE TRANSACTION CHECK ---------------------
                if((t1.addr == t2.addr) && (t1.data == t2.data) &&
                (t1.kind == WRITE && t2.kind == WRITE))  begin
                    $display("Scoreboard PASSED Transaction ID: %h", t1.ID);


                    // ------------ reference model ------------ 
                    case(t1.addr)
                        P_ADDR_CONTROL: begin 
                            control_reg = t1.data;
                            if (control_reg[P_BIT_CLR_STATUS]) status_reg = 'd0;

                            reload_active = t1.data[P_BIT_RELOAD_EN]; 
                            
                            if (t1.data[P_BIT_START]) begin 
                                start_count = $realtime;
                                $display("Timer STARTED at time: %t RE: %b", start_count, reload_active);
                                status_cleared = 0;
                            end
                            control_reg[P_BIT_START] = 1'b0;
                            control_reg[P_BIT_CLR_STATUS] = 1'b0;
                        end
                        P_ADDR_LOAD: load_reg = (t1.data != 0) ? t1.data : 1; // if zero as input count it as 1 (zero hendling)
                        P_ADDR_STATUS: status_reg = t1.data;
                    endcase

                    // -----------------------------------------

                // --------------------- READ TRANSACTION CHECK ---------------------
                end else if((t1.kind == READ && t2.kind == READ)) begin // skipping for now reading

                    // ------------ reference model ------------ 
                    case(t1.addr)
                        P_ADDR_CONTROL: 
                        if(t2.data != control_reg) $error("CONTROL REG FAILED! Expected: %h, Actual: %h", control_reg, t2.data);
                        
                        P_ADDR_LOAD:
                            if(t2.data != load_reg) 
                            $error("LOAD REG FAILED! Expected: %h, Actual: %h", load_reg, t2.data);
                        P_ADDR_STATUS: begin
                            logic expected_ex;
                            real elapsed_time;

                            elapsed_time = $realtime - start_count;
                            if (elapsed_time >= ((load_reg * 10) )) begin 
                                if (!status_cleared) expected_ex = 1'b1;
                                else expected_ex = 1'b0;
                            end else expected_ex = 1'b0;

                            if (t2.data[0] != expected_ex) $error("time : %t STATUS EXPIRED FAILED! eplapsed: %t",$time() ,elapsed_time);
                            else begin
                            
                            if (t2.data[0] == expected_ex) begin 
                                $display("time : %t STATUS EXPIRED PASSED! eplapsed: %t",$time(), elapsed_time);
                                status_cleared = 1;
                                if (reload_active) begin
                                    start_count = start_count + (load_reg * 10);
                                    status_cleared = 0;
                                end
                            end
                            
                            end
                        end
                    endcase

                    // -----------------------------------------

                    
                end else begin
                    $display("Scoreboard FAILD! Transaction ID: %d",t1.ID);
                    $display("Expected:");
                    t1.display();
                    $display("Actual:");
                    t2.display();

                end              
            end

        join_none
    endtask : run


    function bit is_empty();
        if(driver_mbx.num() == 0 && tran2_q.size()== 0 ) return 1;
        else return 0;
    endfunction

endclass : Scoreboard
