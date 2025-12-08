// `timescale 1ns/1ps
import design_params_pkg::*;

module timer_periph_update (
    input  logic clk,
    input  logic reset_n,

    input  logic req,
    output logic gnt,
    input  logic [P_ADDR_WIDTH-1:0]  addr,
    input  logic [P_DATA_WIDTH-1:0]  wdata,
    output logic [P_DATA_WIDTH-1:0]  rdata,
    input  logic write_en
);

  // ============================================================
  // Internal registers
  // ============================================================
  logic [15:0] m_load;
  logic        m_reload_en;
  logic        m_expired;
  logic [15:0] m_counter;
  logic        m_running;

  // ============================================================
  // Handshake FSM (3-state version)
  // ============================================================

  typedef enum logic [1:0] {
    HS_IDLE,
    HS_WAIT,
    HS_GRANT
  } hs_state_e;

  hs_state_e hs_cs, hs_ns;

  logic [1:0] grant_delay_cnt;
  logic [1:0] grant_delay_sel;

  // ============================================================
  // Timer FSM
  // ============================================================

  typedef enum logic [1:0] {
    TMR_IDLE,
    TMR_RUNNING,
    TMR_EXPIRED
  } tmr_state_e;

  tmr_state_e tmr_cs, tmr_ns;

  // ============================================================
  // Handshake FSM next state
  // ============================================================

  always_comb begin
    hs_ns = hs_cs;

    unique case (hs_cs)

      HS_IDLE: begin
          hs_ns = HS_WAIT;
      end

      HS_WAIT: begin
        if (!req)
          hs_ns = HS_IDLE;                  // abort
        else if (grant_delay_cnt == grant_delay_sel)
          hs_ns = HS_GRANT;
      end

      HS_GRANT: begin
        hs_ns = HS_IDLE;                    // one cycle only
      end

    endcase
  end

  // ============================================================
  // Timer FSM next state
  // ============================================================

  always_comb begin
    tmr_ns = tmr_cs;

    unique case (tmr_cs)

      TMR_IDLE: begin
        if (hs_cs == HS_GRANT && write_en && addr == P_ADDR_CONTROL &&
            wdata[P_BIT_START])
          tmr_ns = TMR_RUNNING;
      end

      TMR_RUNNING: begin
        if (m_counter == 0) begin
          if (m_reload_en)
            tmr_ns = TMR_RUNNING;
          else
            tmr_ns = TMR_EXPIRED;
        end
      end

      TMR_EXPIRED: begin
        if (hs_cs == HS_GRANT && !write_en && addr == P_ADDR_STATUS)
          tmr_ns = TMR_IDLE;

        if (hs_cs == HS_GRANT && write_en && addr == P_ADDR_CONTROL &&
            wdata[P_BIT_START])
          tmr_ns = TMR_RUNNING;
      end

    endcase
  end

  // ============================================================
  // Sequential Logic
  // ============================================================

  always_ff @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin

      hs_cs <= HS_IDLE;
      tmr_cs <= TMR_IDLE;

      grant_delay_cnt <= 0;
      grant_delay_sel <= 0;

      gnt <= 0;
      rdata <= 0;

      m_load <= 0;
      m_reload_en <= 0;
      m_expired <= 0;
      m_counter <= 0;
      m_running <= 0;

    end else begin

      hs_cs <= hs_ns;
      tmr_cs <= tmr_ns;

      // ----------------------------
      // Handshake FSM sequential
      // ----------------------------
      case (hs_cs)

        HS_IDLE: begin
          gnt <= 0;
          grant_delay_cnt <= 0;
          grant_delay_sel <= $urandom_range(1,2); // 1–3 cycles
        end

        HS_WAIT: begin
          gnt <= 0;
          if (req)
            grant_delay_cnt <= grant_delay_cnt + 1;
          else
            grant_delay_cnt <= 0;
        end

        HS_GRANT: begin
          gnt <= 1;              // exactly 1-cycle pulse
          grant_delay_cnt <= 0;
        end

      endcase

      // ----------------------------
      // Register READ (no latches)
      // Only valid during GRANT
      // ----------------------------
      if (hs_cs == HS_GRANT && !write_en) begin
        unique case (addr)
          P_ADDR_CONTROL:
            rdata <= {{(P_DATA_WIDTH-3){1'b0}},
                      m_reload_en,
                      1'b0, 1'b0};

          P_ADDR_LOAD:
            rdata <= {{(P_DATA_WIDTH-16){1'b0}}, m_load};

          P_ADDR_STATUS:
            rdata <= {{(P_DATA_WIDTH-1){1'b0}}, m_expired};

          default:
            rdata <= '0;
        endcase
      end
      else if (hs_cs == HS_IDLE)
        rdata <= '0;

      // STATUS read-clear
      if (hs_cs == HS_GRANT && !write_en && addr == P_ADDR_STATUS)
        m_expired <= 0;

      // ----------------------------
      // Register WRITE (no latches)
      // Only valid in GRANT
      // ----------------------------
      if (hs_cs == HS_GRANT && write_en) begin
        case (addr)

          P_ADDR_CONTROL: begin
            m_reload_en <= wdata[P_BIT_RELOAD_EN];

            if (wdata[P_BIT_START]) begin
              m_counter <= (m_load == 0) ? 16'd1 : m_load;
              m_running <= 1;
              m_expired <= 0;
            end

            if (wdata[P_BIT_CLR_STATUS])
              m_expired <= 0;
          end

          P_ADDR_LOAD: begin
            m_load <= wdata[15:0];
          end

        endcase
      end

      // ----------------------------
      // Timer FSM sequential logic
      // ----------------------------
      case (tmr_cs)

        TMR_IDLE: begin
          m_running <= 0;
        end

        TMR_RUNNING: begin
          if (m_counter == 0) begin
            m_expired <= 1;
            if (m_reload_en)
              m_counter <= (m_load == 0) ? 16'd1 : m_load;
            else
              m_running <= 0;
          end else begin
            m_counter <= m_counter - 1;
          end
        end

        TMR_EXPIRED: begin
          m_running <= 0;
        end

      endcase

    end
  end

endmodule