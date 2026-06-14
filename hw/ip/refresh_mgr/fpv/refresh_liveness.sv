// Copyright 2026 The Netie Open HBM Authors
// SPDX-License-Identifier: Apache-2.0
//
// Formal wrapper for refresh_mgr: periodic tREFW ticks + bounded pending streak.
//
// T_REFI_CYCLES selects the coarse abstract DRAM clock count between refreshes.
// PendBound = 2 * T_REFI_CYCLES aligns the bounded-streak assertion with twice
// the abstract REFI spacing at this granularity.
//
// Bounded-deferral lemma: under fair drfm_ack (|=> ##[1:14]),
// pend_streak < PendBound. This models "no pseudo-channel misses servicing
// before twice the abstract REFI horizon" relative to sticky DRFM requests.
`default_nettype none
`timescale 1ns/1ps

module refresh_mgr_liveness_wrapper;
  import refresh_mgr_pkg::*;

  localparam int unsigned FormalK = 8;
  localparam int unsigned FormalThresh = 8;
  localparam int unsigned FormalCredMax = 2;
  localparam int unsigned T_REFI_CYCLES = 48;
  localparam int unsigned PendBound = T_REFI_CYCLES * 2;

  logic rst_ni;


  logic                clk_i;
  logic                act_valid_i;
  logic [BgW-1:0]      act_bg_i;
  logic [BaW-1:0]      act_ba_i;
  logic [RowW-1:0]      act_row_i;
  logic                trefw_tick_i;
  logic                credit_release_i;


  logic                drfm_pending_o;
  logic [BgW-1:0]      drfm_target_bg_o;
  logic [BaW-1:0]      drfm_target_ba_o;
  logic [RowW-1:0]     drfm_target_row_o;
  logic                drfm_ack_i;


  logic                prac_overflow_alert_o;

  logic [7:0]          ph;



  logic [15:0]         pend_streak;

`ifndef OPENHBM_FPV
  initial begin : g_clk_gen
    clk_i = 1'b0;
    forever #5 clk_i = ~clk_i;
  end
`endif

  always_ff @(posedge clk_i or negedge rst_ni) begin : g_ph
    if (!rst_ni) begin
      ph <= '0;
    end else if (ph == 8'(T_REFI_CYCLES - 1)) begin
      ph <= '0;
    end else begin
      ph <= ph + 8'h1;
    end
  end

  assign trefw_tick_i = rst_ni && (ph == 8'h0);

  refresh_mgr #(
      .PracThresh(FormalThresh),
      .PracTopK  (FormalK),
      .NumBanks  (4),

      .CreditMax (FormalCredMax),
      .RowW      (RowW),
      .BgW       (BgW),
      .BaW       (BaW),
      .CountW    (CountW)

  ) dut (
      .clk_i                 (clk_i),
      .rst_ni                (rst_ni),
      .act_valid_i           (act_valid_i),

      .act_bg_i              (act_bg_i),
      .act_ba_i              (act_ba_i),
      .act_row_i             (act_row_i),
      .trefw_tick_i          (trefw_tick_i),
      .credit_release_i      (credit_release_i),

      .drfm_pending_o        (drfm_pending_o),
      .drfm_target_bg_o      (drfm_target_bg_o),
      .drfm_target_ba_o      (drfm_target_ba_o),
      .drfm_target_row_o     (drfm_target_row_o),
      .drfm_ack_i            (drfm_ack_i),
      .prac_overflow_alert_o(prac_overflow_alert_o)
  );

`ifndef OPENHBM_FPV
  initial begin : g_boot
    rst_ni = 1'b0;
    @(posedge clk_i);
    @(posedge clk_i);
    rst_ni = 1'b1;
  end
`else
  initial rst_ni = 1'b1;
`endif

  always_ff @(posedge clk_i or negedge rst_ni) begin : g_penstr
    if (!rst_ni) begin
      pend_streak <= '0;
    end else if (drfm_pending_o && !drfm_ack_i) begin
      pend_streak <= pend_streak + 16'h1;
    end else pend_streak <= '0;
  end




`ifndef SYNTHESIS




  asm_fair_ack : assume property (
      @(posedge clk_i)

          disable iff (!rst_ni)
        dut.drfm_pending_o |=> ##[1:14] drfm_ack_i);



  a_no_unbounded_pending : assert property (
      @(posedge clk_i)



          disable iff (!rst_ni)
        pend_streak < PendBound);


`endif

endmodule : refresh_mgr_liveness_wrapper
