// --------------------------------------------------
// CLASS: Coverage_Collector
//
// Description:
// This class purpose is to check that we covered all the cases we defined in the Verification Plan
//
// --------------------------------------------------
import design_params_pkg::*;
import bus_trans_pkg::*;

class coverage_collector_timer;

    bus_trans tr_sampled;


    covergroup cg_timer;

        // checks we have been in all the registers.
        cp_addr : coverpoint tr_sampled.addr {
            bins LOAD    = {P_ADDR_LOAD};
            bins CONTROL = {P_ADDR_CONTROL};
            bins STATUS  = {P_ADDR_STATUS};
        }
        // different ranges of data. 
        cp_data : coverpoint tr_sampled.data {
            bins zero = {0}; 
            bins one = {1};
            bins low  = {[2:63]};
            ignore_bins mid  = {[64:191]};
            ignore_bins high = {[192:255]};
            ignore_bins ultra_high = {[256:65535]};
        }
        
        cp_kind : coverpoint tr_sampled.kind;
        
        cp_start : coverpoint tr_sampled.data[P_BIT_START] 
        iff (tr_sampled.addr == P_ADDR_CONTROL && tr_sampled.kind == WRITE ) {
            bins start_active = {1};
        }

        cp_reload : coverpoint tr_sampled.data[P_BIT_RELOAD_EN]
            iff (tr_sampled.addr == P_ADDR_CONTROL && tr_sampled.kind == WRITE){
                bins one_shot = {0};
                bins auto_reload = {0};
            }

        // cross LOAD, zero;
        cross_load_zero : cross cp_addr, cp_data {
            bins load_zero_val = binsof(cp_addr.LOAD) && binsof(cp_data.zero);
            ignore_bins others = !binsof(cp_addr.LOAD) || !binsof(cp_data.zero);
        }

        // that we actually started the mode
        cross_modes : cross cp_start, cp_reload;
        
        // to check we wrote to all the registers.
        cross_all_ops : cross cp_addr, cp_kind;
        
    endgroup

    // Constractor
    function new();
        cg_timer = new();
    endfunction

    
    function void sample(bus_trans tr);
        this.tr_sampled = tr;
        cg_timer.sample();
    endfunction

endclass : coverage_collector_timer
