import design_params_pkg::*;

module timer_periph
(
  input  logic                      clk,
  input  logic                      reset_n,

  // Simple handshake bus
  input  logic                      req,        // from master
  output logic                      gnt,        // to master (BUG: timing can violate spec)
  input  logic [P_ADDR_WIDTH-1:0]   addr,
  input  logic [P_DATA_WIDTH-1:0]   wdata,
  output logic [P_DATA_WIDTH-1:0]   rdata,
  input  logic                      write_en
);

  // -----------------------------
  // Register file & timer state
  // -----------------------------
  logic [15:0] m_load;         // LOAD[15:0]; upper bits read as 0
  logic        m_reload_en;    // CONTROL[1]
  logic        m_expired;      // STATUS[0], sticky

  logic [15:0] m_counter;
  logic        m_running;

  // -----------------------------
  // Handshake control
  // -----------------------------
  logic [2:0]  grant_delay_reg;     // 0..7
  logic [2:0]  grant_cnt;           // counter for grant delay
  logic        grant_counting;      // in the middle of counting to gnt

  logic [1:0]  fall_cnt;            // counts cycles after req falls while gnt is high

  // -----------------------------
  // Read datapath (buggy)
  // -----------------------------
  logic [P_DATA_WIDTH-1:0] rdata_next;  // computed value

  // -----------------------------
  // Combinational helper: decode intended delay from address when counting starts
  // -----------------------------
  logic [2:0] grant_delay_dec;
  assign grant_delay_dec = (addr[2:0] == 3'b000) ? 3'd4 : 3'd2; // BUG: 4 cycles for addr%8==0

  // -----------------------------
  // Sequential logic
  // -----------------------------
  always_ff @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
      // Handshake defaults
      gnt              <= 1'b0;
      grant_delay_reg  <= 3'd0;
      grant_cnt        <= 3'd0;
      grant_counting   <= 1'b0;
      fall_cnt         <= 2'd0;

      // Read datapath
      rdata            <= '0;
      rdata_next       <= '0;

      // Registers / timer
      m_load           <= 16'd0;
      m_reload_en      <= 1'b0;
      m_expired        <= 1'b0;
      m_counter        <= 16'd0;
      m_running        <= 1'b0;
    end
    else begin
      rdata <= rdata_next;
      // Start counting when req is high and gnt is low and we’re not already counting
      if (req && !gnt && !grant_counting) begin
        grant_counting  <= 1'b1;
        grant_cnt       <= 3'd0;
        grant_delay_reg <= grant_delay_dec;  // capture delay for this request
      end
      // Increment while counting (and req remains asserted)
      else if (grant_counting && !gnt) begin
        grant_cnt <= grant_cnt + 3'd1;
        if (grant_cnt >= grant_delay_reg) begin
          gnt            <= 1'b1;   // may be 4 cycles for certain addresses (violates ≤3)
          grant_counting <= 1'b0;
        end
      end

      // If req aborts before gnt, cancel counting
      if (!req && !gnt) begin
        grant_counting <= 1'b0;
        grant_cnt      <= 3'd0;
      end

      if (gnt && !req) begin
        fall_cnt <= fall_cnt + 2'd1;
        if (fall_cnt == 2'd1) begin
          // deassert one cycle later than spec (i.e., total 2 cycles after req fell)
          gnt     <= 1'b0;
          fall_cnt<= 2'd0;
        end
      end else if (req) begin
        fall_cnt <= 2'd0;
      end

      if (req && gnt && !write_en) begin
        unique case (addr)
          P_ADDR_CONTROL: rdata_next <= { {(P_DATA_WIDTH-3){1'b0}}, m_reload_en, 1'b0 /*START*/, 1'b0 /*CLR_STATUS*/ };
          P_ADDR_LOAD   : rdata_next <= { {(P_DATA_WIDTH-16){1'b0}}, m_load };
          P_ADDR_STATUS : rdata_next <= { {(P_DATA_WIDTH-1){1'b0}}, m_expired };
          default       : rdata_next <= '0; // unmapped reads return 0
        endcase
      end else begin
        // hold or clear; keeping last is fine — the bug is the 1-cycle late registration
      end

      if (req && gnt && write_en) begin
        unique case (addr)
          P_ADDR_CONTROL: begin
            // BUG#4: Mis-decoded RELOAD_EN — using CLR_STATUS bit instead of bit[1]
            m_reload_en <= wdata[P_BIT_CLR_STATUS];

            // START behavior — BUG#5: LOAD=0 NOT coerced to 1 (spec wants min 1)
            if (wdata[P_BIT_START]) begin
              m_counter <= (m_load == 16'd0) ? 16'd0 : m_load; // BUG
              m_running <= 1'b1;
              m_expired <= 1'b0; // clear on start (reasonable)
            end
          end

          P_ADDR_LOAD: begin
            // LOAD lower 16 bits; upper ignored (OK)
            m_load <= wdata[15:0];
          end

          default: begin
            // unmapped writes ignored (OK); latency quirk still observable via addr pattern
          end
        endcase
      end

      // -------------------------
      // Countdown Logic
      // -------------------------
      if (m_running) begin
        if (m_counter == 16'd0) begin
          m_expired <= 1'b1;
          if (m_reload_en) begin
            m_counter <= m_load;     // auto-reload
          end else begin
            m_running <= 1'b0;       // one-shot stop
          end
        end else begin
          m_counter <= m_counter - 16'd1;
        end
      end
    end
  end

endmodule
