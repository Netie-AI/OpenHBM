// Copyright 2026 The Netie Open HBM Authors
// SPDX-License-Identifier: Apache-2.0
`default_nettype none
`timescale 1ns/1ps

// refresh_mgr — DRFM request path with Misra-Gries PRAC (top-K per bank),
// decay on tREFW ticks, per-bank credit pool, sticky drfm_pending / targets.
//
// Cycle narrative (rising-edge update):
//   1) If drfm_ack while pending_q: decrement credit for latched bank, remove
//      lat_row slots in that bank, clear sticky pending.
//   2) If tREFW tick: decay every PRAC slot; replenish every bank credit.
//      Else if credit_release: return one credit to (pending bank ?? first hit ?? 0).
//   3) If !tick && activation valid: Misra-Gries bucket update at act bank/row.
//   4) If !pending && hit>=PracThresh && credits(hit_bank)>0: arm pending + latch.
//   5) prac_overflow when hit>=thresh, pending stays disarmed after (4),
//      and credits at hit_bank are exhausted.
module refresh_mgr #(
    parameter int unsigned PracThresh = 1024,
    parameter int unsigned PracTopK   = refresh_mgr_pkg::PracTopK,
    parameter int unsigned NumBanks    = refresh_mgr_pkg::NumBanks,
    parameter int unsigned CreditMax   = refresh_mgr_pkg::CreditMax,
    parameter int unsigned RowW        = refresh_mgr_pkg::RowW,
    parameter int unsigned BgW         = refresh_mgr_pkg::BgW,
    parameter int unsigned BaW         = refresh_mgr_pkg::BaW,
    parameter int unsigned CountW      = refresh_mgr_pkg::CountW
) (
    input  logic            clk_i,
    input  logic            rst_ni,
    input  logic            act_valid_i,
    input  logic [BgW-1:0]   act_bg_i,
    input  logic [BaW-1:0]   act_ba_i,
    input  logic [RowW-1:0]  act_row_i,
    input  logic            trefw_tick_i,
    input  logic            credit_release_i,
    output logic            drfm_pending_o,
    output logic [BgW-1:0]  drfm_target_bg_o,
    output logic [BaW-1:0]  drfm_target_ba_o,
    output logic [RowW-1:0] drfm_target_row_o,
    input  logic            drfm_ack_i,
    output logic            prac_overflow_alert_o
);
  import refresh_mgr_pkg::*;

  typedef logic [BaW - 1:0] ba_t;
  typedef logic [BgW - 1:0] bg_t;

  localparam logic [CountW - 1:0] ThreshW = CountW'(PracThresh);

  prac_slot_t mem_q[NumBanks][PracTopK];
  logic [CountW - 1:0] credits_q[NumBanks];

  logic pending_q;
  bg_t lat_bg_q;
  ba_t lat_ba_q;
  logic [RowW - 1:0] lat_row_q;

  function automatic int unsigned idx_bank(input bg_t bg, input ba_t ba);
    return int'({bg, ba});
  endfunction : idx_bank

  function automatic void scan_hit_mem(
      input prac_slot_t mem[NumBanks][PracTopK],
      output logic hit,
      output logic [BgW - 1:0] hbg,
      output ba_t hba,
      output int unsigned hbi,
      output logic [RowW - 1:0] hrow);
    hit  = 1'b0;
    hbg  = '0;
    hba  = '0;
    hbi  = 0;
    hrow = '0;
    for (int unsigned bk = 0; bk < NumBanks; bk++) begin : h_outer
      for (int unsigned sj = 0; sj < PracTopK; sj++) begin : h_inner
        if (!hit && mem[bk][sj].valid && ($unsigned(mem[bk][sj].count) >= $unsigned(ThreshW))) begin
          hit  = 1'b1;
          hbi  = bk;
          hrow = mem[bk][sj].row;
          hba  = ba_t'(bk);
          hbg  = bg_t'(bk >> BaW);
        end
      end
    end
  endfunction : scan_hit_mem

  task automatic tbl_decay_inplace(inout prac_slot_t slots[PracTopK]);
    for (int unsigned uu = 0; uu < PracTopK; uu++) begin : g_tw
      if (slots[uu].valid && slots[uu].count != '0) begin
        slots[uu].count--;
        if (slots[uu].count == '0) slots[uu].valid = 1'b0;
      end
    end
  endtask

  task automatic remove_row_inplace(inout prac_slot_t slots[PracTopK],
                                     input logic [RowW - 1:0] rr);
    for (int unsigned uu = 0; uu < PracTopK; uu++) begin : g_rm
      if (slots[uu].valid && slots[uu].row == rr) begin
        slots[uu].valid = 1'b0;
        slots[uu].count = '0;
      end
    end
  endtask

  task automatic mg_activate_inplace(inout prac_slot_t slots[PracTopK],
                                      input logic [RowW - 1:0] r);
    int unsigned matched_idx;
    int unsigned free_ix;
    logic matched;
    begin
      matched = 1'b0;
      for (int unsigned uu = 0; uu < PracTopK; uu++) begin : g_ma
        if (!matched && slots[uu].valid && slots[uu].row == r) begin
          matched     = 1'b1;
          matched_idx = uu;
        end
      end
      if (matched) begin
        if ($unsigned(slots[matched_idx].count) < {CountW{1'b1}}) begin
          slots[matched_idx].count++;
        end
      end else begin
        free_ix = PracTopK;
        for (int unsigned uu = 0; uu < PracTopK; uu++) begin : g_fr
          if (free_ix == PracTopK && (!slots[uu].valid || slots[uu].count == '0)) begin
            free_ix = uu;
          end
        end
        if (free_ix != PracTopK) begin
          slots[free_ix].valid = 1'b1;
          slots[free_ix].row = r;
          slots[free_ix].count = CountW'(1);
        end else begin
          for (int unsigned kk = 0; kk < PracTopK; kk++) begin : g_sg
            if (slots[kk].valid && slots[kk].count != '0) begin
              slots[kk].count--;
            end
            if (slots[kk].count == '0) slots[kk].valid = 1'b0;
          end
          free_ix = PracTopK;
          for (int unsigned kk2 = 0; kk2 < PracTopK; kk2++) begin : g_fr2
            if (free_ix == PracTopK && (!slots[kk2].valid || slots[kk2].count == '0)) begin
              free_ix = kk2;
            end
          end
          if (free_ix != PracTopK) begin
            slots[free_ix].valid = 1'b1;
            slots[free_ix].row = r;
            slots[free_ix].count = CountW'(1);
          end
        end
      end
    end
  endtask : mg_activate_inplace

  always_ff @(posedge clk_i or negedge rst_ni) begin : g_seq
    if (!rst_ni) begin
      for (int unsigned bi = 0; bi < NumBanks; bi++) begin
        for (int unsigned sj = 0; sj < PracTopK; sj++) mem_q[bi][sj] <= '0;
        credits_q[bi] <= CountW'(CreditMax);
      end

      pending_q <= 1'b0;
      lat_bg_q <= '0;
      lat_ba_q <= '0;
      lat_row_q <= '0;

      drfm_pending_o <= 1'b0;
      drfm_target_bg_o <= '0;
      drfm_target_ba_o <= '0;
      drfm_target_row_o <= '0;

      prac_overflow_alert_o <= 1'b0;
    end else begin : clk_step_gen
      logic hit_pre_v;
      bg_t hit_pre_bg;
      ba_t hit_pre_ba;
      logic [RowW - 1:0] hit_pre_row;
      int unsigned hit_pre_bi;

      logic start_pend;
      int unsigned bk_ix;

      int unsigned rb_ix;
      logic hit_post_v;

      bg_t hp_bg;
      ba_t hp_ba;
      logic [RowW - 1:0] hp_row;
      int unsigned hp_bi;

      logic hit_ov_v;
      logic [BgW - 1:0] ov_bg;
      ba_t ov_ba;
      logic [RowW - 1:0] ov_row;
      int unsigned ov_bi;

      prac_slot_t wq[NumBanks][PracTopK];
      logic [CountW - 1:0] nc[NumBanks];

      logic pend_nxt;
      bg_t nlat_bg;
      ba_t nlat_ba;
      logic [RowW - 1:0] nlat_rw;

      // --- working copy ---
      scan_hit_mem(mem_q, hit_pre_v, hit_pre_bg, hit_pre_ba, hit_pre_bi, hit_pre_row);
      start_pend = pending_q;

      for (int unsigned bx = 0; bx < NumBanks; bx++) begin : g_cp
        for (int unsigned sy = 0; sy < PracTopK; sy++) begin
          wq[bx][sy] = mem_q[bx][sy];
        end
        nc[bx] = credits_q[bx];
      end

      pend_nxt = pending_q;
      nlat_bg = lat_bg_q;
      nlat_ba = lat_ba_q;
      nlat_rw = lat_row_q;

      // (1) ACK
      if (drfm_ack_i && pending_q) begin
        bk_ix = idx_bank(lat_bg_q, lat_ba_q);
        if ($unsigned(nc[bk_ix]) > 0) begin
          nc[bk_ix]--;
        end
        remove_row_inplace(wq[bk_ix], lat_row_q);
        pend_nxt = 1'b0;
      end

      // (2)/(3)
      if (trefw_tick_i) begin
        for (int unsigned bx = 0; bx < NumBanks; bx++) begin
          tbl_decay_inplace(wq[bx]);
          nc[bx] = CountW'(CreditMax);
        end
      end else if (credit_release_i) begin
        if (start_pend) begin
          rb_ix = idx_bank(lat_bg_q, lat_ba_q);
        end else if (hit_pre_v) begin
          rb_ix = hit_pre_bi;
        end else begin
          rb_ix = '0;
        end
        if ($unsigned(nc[rb_ix]) < $unsigned(CountW'(CreditMax))) begin
          nc[rb_ix]++;
        end

      end

      // (4) activation
      if (!trefw_tick_i && act_valid_i) begin
        bk_ix = idx_bank(bg_t'(act_bg_i), ba_t'(act_ba_i));
        mg_activate_inplace(wq[bk_ix], act_row_i);
      end

      // (5) arm pending again
      scan_hit_mem(wq, hit_post_v, hp_bg, hp_ba, hp_bi, hp_row);
      if (!pend_nxt && hit_post_v && ($unsigned(nc[hp_bi]) > 0)) begin
        pend_nxt = 1'b1;
        nlat_bg = hp_bg;
        nlat_ba = hp_ba;
        nlat_rw = hp_row;
      end

      // commit flops
      for (int unsigned bi = 0; bi < NumBanks; bi++) begin
        for (int unsigned sj = 0; sj < PracTopK; sj++) mem_q[bi][sj] <= wq[bi][sj];
        credits_q[bi] <= nc[bi];
      end

      pending_q <= pend_nxt;
      lat_bg_q <= nlat_bg;
      lat_ba_q <= nlat_ba;
      lat_row_q <= nlat_rw;

      drfm_pending_o <= pend_nxt;

      drfm_target_bg_o <= nlat_bg;
      drfm_target_ba_o <= nlat_ba;
      drfm_target_row_o <= nlat_rw;

      scan_hit_mem(wq, hit_ov_v, ov_bg, ov_ba, ov_bi, ov_row);
      prac_overflow_alert_o <= hit_ov_v && !pend_nxt && (nc[ov_bi] == '0);
    end : clk_step_gen
  end : g_seq

`ifndef SYNTHESIS
  genvar gbi;

  generate
    for (gbi = 0; gbi < int'(NumBanks); gbi++) begin : g_as_credits

      a_credit_ub : assert property (
          @(posedge clk_i) disable iff (!rst_ni)
            credits_q[gbi] <= CountW'(CreditMax));
    end : g_as_credits
  endgenerate

  c_bank0_pending_cover : cover property (
      @(posedge clk_i) disable iff (!rst_ni)
      drfm_pending_o && pending_q);


  c_overflow_seen : cover property (
      @(posedge clk_i) disable iff (!rst_ni)
      prac_overflow_alert_o);

`endif // SYNTHESIS

endmodule : refresh_mgr
