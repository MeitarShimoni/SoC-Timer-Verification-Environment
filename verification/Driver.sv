// --------------------------------------------------
// CLASS: Driver
//
// Description:
// this Driver Class, Performing The Connection between the dynamic
// enviorment to drive the actual signals.
// --------------------------------------------------
import design_params_pkg::*;
import bus_trans_pkg::*;
class Driver;
    // instance the virtual bus interface
    virtual bus_if.MASTER bus_vi;

    // insanciating the mailbox
    mailbox #(bus_trans) mbx;

    // Constractor
    function new(virtual bus_if.MASTER bus_vi, mailbox #(bus_trans) mbx);
        this.bus_vi = bus_vi; // creating a new interface
        this.mbx = mbx;
    endfunction

    task run();
        
        forever begin
            bus_trans tr_handle;
            mbx.get(tr_handle); // mailbox waiting to get a transaction
            drive_transaction(tr_handle);
            // $display(""); $write("DRIVER CREATED: ");
            // tr_handle.display();

        end
    endtask


    task drive_transaction(bus_trans tr_handle);
        
        // --------------- set the values for transaction -----------
        @(bus_vi.driver_cb); // wait for the clock

        // to wait for gnt not to be captured twice as 1,
        // while (bus_vi.driver_cb.gnt === 1) @(bus_vi.driver_cb);
 
        bus_vi.driver_cb.addr <= tr_handle.addr;
        bus_vi.driver_cb.write_en <= (tr_handle.kind == WRITE) ? 1'b1 : 1'b0;

        if (tr_handle.kind == WRITE) begin
            bus_vi.driver_cb.wdata <=  tr_handle.data; // changed from <= to =
        end

        bus_vi.driver_cb.req <= 1'b1;

        // waiting on a positive clock edge and when gnt == 1:
        @(bus_vi.driver_cb iff bus_vi.driver_cb.gnt == 1'b1 );
        
        // at READ we need to get sample the data. into our OOP Transaction.
        if(tr_handle.kind == READ) begin
            tr_handle.data = bus_vi.driver_cb.rdata;  // changed from <= to =
            // $display("READDDDDDDDDDD %h", bus_vi.driver_cb.rdata);
        end

        $display(""); $write("DRIVER CREATED: ");
        tr_handle.display();
        
        // request goes low after gnt has been observed! 
        bus_vi.driver_cb.req <= 1'b0;      

        // MATBE TO ADD FOR THE DRIVER TO WAIT UNTIL GNT is 0>?
        @(bus_vi.driver_cb iff bus_vi.driver_cb.gnt == 1'b0);
        // @(negedge bus_vi.driver_cb.gnt); //  CHECK CHECK CHECK CHECK CHECK CHECK CHECK CHECK CHECK
        // CHECK CHECK CHECK CHECK CHECK CHECK CHECK CHECK CHECK CHECK CHECK CHECK CHECK CHECK CHECK
    endtask : drive_transaction


    // reset
    task reset();
        bus_vi.driver_cb.req <= 1'b0;
        bus_vi.driver_cb.addr <= 8'h00;
        bus_vi.driver_cb.write_en <= 1'b0;
        bus_vi.driver_cb.wdata <= 32'h0000_0000;
    endtask : reset




endclass : Driver