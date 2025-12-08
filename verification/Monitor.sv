// --------------------------------------------------
// CLASS: Monitor
//
// Description:
// this is a Monitor Class that observe and send Transactions
// From The Driver to the Scoreboard Class.
//
// --------------------------------------------------
`include "coverage_collector_timer.sv"
import design_params_pkg::*;
import bus_trans_pkg::*;
class Monitor;
    // instance the virtual bus as SLAVE
    virtual bus_if.MASTER bus_vi;
    mailbox #(bus_trans) mbx;
    bus_trans tr_handle;

    coverage_collector_timer cg;

    // Constractor
    function new(virtual bus_if.MASTER bus_vi, mailbox #(bus_trans) mbx);
        this.bus_vi = bus_vi;
        this.mbx = mbx;
        cg = new();
    endfunction

    // monitoring the transactions when at positive edge of req 
    task run();
        forever begin
            // 1. Wait for the clock edge
            @(bus_vi.monitor_cb);
            
            // 2. Check if a Request started
            if (bus_vi.monitor_cb.req) begin // add gnt? && bus_vi.monitor_cb.gnt
                
                // $display("Monitor detected Req: write_en = %h | Address = %h | data = %h"
                // bus_vi.monitor_cb.write_en, bus_vi.monitor_cb.addr, bus_vi.monitor_cb.);
                tr_handle = new();
                
                // --- CAPTURE REQUEST PHASE INFO IMMEDIATELY ---
                // Don't wait for GNT to capture these, they are valid NOW.
                tr_handle.addr = bus_vi.monitor_cb.addr; 
                
                if (bus_vi.monitor_cb.write_en) begin    
                    tr_handle.kind = WRITE;
                    tr_handle.data = bus_vi.monitor_cb.wdata; // Capture wdata now
                end else begin
                    tr_handle.kind = READ;
                end

                // --- WAIT FOR GRANT PHASE ---
                // Now we wait specifically for GNT to go high to complete the handshake
                // Using a loop ensures we stay synced to the clock
                while (bus_vi.monitor_cb.gnt !== 1'b1) begin
                    @(bus_vi.monitor_cb);
                end

                // --- CAPTURE READ DATA ---
                // Only now, when GNT is high, is rdata valid
                if (tr_handle.kind == READ) begin
                    tr_handle.data = bus_vi.monitor_cb.rdata;
                end
                
                tr_handle.timestamp = $time();
                // Send to Scoreboard and coverage
                cg.sample(tr_handle);
                mbx.put(tr_handle);
                
                $write("MONITOR DETECTED: ");
                tr_handle.display();

                // Optional: Wait for Req to drop to avoid double-sampling the same transaction
                while (bus_vi.monitor_cb.req === 1'b1) begin
                     @(bus_vi.monitor_cb);
                end
            end
        end
    endtask

endclass : Monitor