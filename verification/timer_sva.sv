// --------------------------------------------------
// Module: Checker SVA
//
// Description:
// This checker module purpose is to check that the design's behaivor is as we expects as 
// defined in the spesification module document 
//
// --------------------------------------------------
import design_params_pkg::*;
// reference from week 7 LAB 2
module timer_sva(
    input clk,
    input reset_n,
    input req, 
    input gnt,
    input [P_ADDR_WIDTH-1:0] addr,
    input [P_DATA_WIDTH-1:0] wdata,
    input [P_DATA_WIDTH-1:0] rdata,
    input write_en
);

    // ------- gnt goes HIGH after 3 cycles -----------------
    property R1_GNT_ASSERT_3_CYCLES;
        @(posedge clk) disable iff (!reset_n)
        $rose(req) |-> ##[1:4] gnt; 
    endproperty

    property R2_REQ_WAIT_2_GNT;
        @(posedge clk) disable iff (!reset_n)
        (req && !gnt) |-> ##1 req; // if req 1 and gnt 0. req has to stay high. 
    endproperty
    
    property reset_clears_gnt_p;
        @(posedge clk) 
        !reset_n |=> !gnt;
    endproperty


    R1: assert property(R1_GNT_ASSERT_3_CYCLES)
        else begin
            $error("SVA R1 FAILED! GNT did not go high within 3 cycles after REQ!");
        end

    R2: assert property(R2_REQ_WAIT_2_GNT)
        else begin
            $error("SVA R2 FAILED! REQ did not stay high until GNT was high!");
        end

    R4: assert property (reset_clears_gnt_p)
        else $error("SVA R4 FAILED! GNT is not 0 immediately after reset!");

endmodule : timer_sva