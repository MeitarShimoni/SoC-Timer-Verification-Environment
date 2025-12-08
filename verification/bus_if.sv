import design_params_pkg::*;
interface bus_if(input logic clk);

    // parameter ADDR_WIDTH = 8;
    // parameter DATA_WIDTH = 32;

    logic reset_n;
    logic req;
    logic gnt;
    logic [P_ADDR_WIDTH-1:0] addr;
    logic [P_DATA_WIDTH-1:0] wdata;
    logic [P_DATA_WIDTH-1:0] rdata;
    logic write_en;

    clocking driver_cb @(posedge clk);
        default input #1step output #1ns;
        output req, addr, wdata, write_en;
        input gnt, rdata;
    endclocking

    clocking monitor_cb @(posedge clk);
        default input #1step;
        input req, gnt, addr, wdata, rdata, write_en, reset_n;
    endclocking


    modport MASTER(
        clocking driver_cb,
        clocking monitor_cb,
        input clk,
        input reset_n
        );

    modport SLAVE(
        input clk,
        input reset_n,
        input req,
        output gnt,
        input addr,
        input wdata,
        output rdata,
        input write_en
    ); 


endinterface : bus_if