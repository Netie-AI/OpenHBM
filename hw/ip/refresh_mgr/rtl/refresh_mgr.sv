// Copyright 2026 The Netie Open HBM Authors
// SPDX-License-Identifier: Apache-2.0
`default_nettype none
`timescale 1ns/1ps

// refresh_mgr -- DRFM + PRAC + per-bank credit deferral.
//
// PHASE-1 SKELETON. A full Misra-Gries top-K table per bank is roomy
// (16 banks * 64 entries * (1 + 17 + 12) = ~30 kb of state), so the
// skeleton implements a single-bank version + the credit pool. Multi-bank
// fan-out is mechanical and ships in Phase 2.
//
// State machine:
//   IDLE -> count_act -> push_topk -> emit_drfm -> IDLE
// Cycle-by-cycle:
//   c0: ACT lands; bank table is read at the activated row.
//   c1: count is incremented; if it crosses the PRAC threshold AND
//       there is no pending credit defer, a DRFM-pending event is queued.
//   c2: scheduler emits DRFM in the next bank-IDLE window; ack lands here.

import refresh_mgr_pkg::*;

module refresh_mgr #(
  parameter int unsigned PracThresh = 12'd1024
) (
  input  logic                 clk_i,
  input  logic                 rst_ni,

  // Activation events from bank machine
  input  logic                 act_valid_i,
  input  logic [BgW-1:0]       act_bg_i,
  input  logic [BaW-1:0]       act_ba_i,
  input  logic [RowW-1:0]      act_row_i,

  // Refresh-window tick (1 per tREFW)
  input  logic                 trefw_tick_i,

  // Credit handshake: scheduler may withhold a credit to defer DRFM.
  input  logic                 credit_release_i,    // scheduler returns a deferred credit

  // DRFM output to controller
  output logic                 drfm_pending_o,
  output logic [BgW-1:0]       drfm_target_bg_o,
  output logic [BaW-1:0]       drfm_target_ba_o,
  output logic [RowW-1:0]      drfm_target_row_o,
  input  logic                 drfm_ack_i,

  // Alert -- a row crossed the PRAC threshold beyond the credit pool
  output logic                 prac_overflow_alert_o
);

  // Single-bank skeleton: track only one row per (bg, ba). Multi-bank in P2.
  prac_entry_t entry_q [NumBanks];

  function automatic int unsigned bank_idx(input logic [BgW-1:0] bg,
                                           input logic [BaW-1:0] ba);
    return int'({bg, ba});
  endfunction

  // Credit pool (16 banks * CreditMax). Skeleton: shared pool.
  logic [3:0] credits_q;
  always_ff @(posedge clk_i or negedge rst_ni) begin : p_credits
    if (!rst_ni) begin
      credits_q <= CreditMax;
    end else if (trefw_tick_i) begin
      credits_q <= CreditMax;
    end else if (credit_release_i && credits_q < CreditMax) begin
      credits_q <= credits_q + 1'b1;
    end else if (drfm_ack_i && credits_q != 0) begin
      credits_q <= credits_q - 1'b1;
    end
  end

  // Track the freshest activated row per bank with a single-slot Misra-Gries.
  always_ff @(posedge clk_i or negedge rst_ni) begin : p_entry
    if (!rst_ni) begin
      for (int unsigned i = 0; i < NumBanks; i++) entry_q[i] <= '0;
    end else begin
      if (trefw_tick_i) begin
        // Decay all counters by 1 (saturating at 0).
        for (int unsigned i = 0; i < NumBanks; i++) begin
          if (entry_q[i].count != '0) entry_q[i].count <= entry_q[i].count - 1'b1;
        end
      end
      if (act_valid_i) begin
        int unsigned bi = bank_idx(act_bg_i, act_ba_i);
        if (entry_q[bi].valid && entry_q[bi].row == act_row_i) begin
          entry_q[bi].count <= entry_q[bi].count + 1'b1;
        end else if (!entry_q[bi].valid || entry_q[bi].count == '0) begin
          entry_q[bi].valid <= 1'b1;
          entry_q[bi].row   <= act_row_i;
          entry_q[bi].count <= 12'h1;
        end else begin
          // demote
          entry_q[bi].count <= entry_q[bi].count - 1'b1;
        end
      end
    end
  end

  // DRFM emission: pick the first bank whose count exceeds the threshold,
  // gated by available credits. Skeleton uses a static priority encoder.
  logic                 hit;
  logic [BgW-1:0]       hit_bg;
  logic [BaW-1:0]       hit_ba;
  logic [RowW-1:0]      hit_row;
  always_comb begin : c_priority
    hit     = 1'b0;
    hit_bg  = '0;
    hit_ba  = '0;
    hit_row = '0;
    for (int unsigned i = 0; i < NumBanks; i++) begin
      if (!hit && entry_q[i].valid && entry_q[i].count >= PracThresh) begin
        hit     = 1'b1;
        hit_bg  = i[BgW+BaW-1:BaW];
        hit_ba  = i[BaW-1:0];
        hit_row = entry_q[i].row;
      end
    end
  end

  assign drfm_pending_o      = hit && (credits_q != '0);
  assign drfm_target_bg_o    = hit_bg;
  assign drfm_target_ba_o    = hit_ba;
  assign drfm_target_row_o   = hit_row;
  assign prac_overflow_alert_o = hit && (credits_q == '0);

`ifndef SYNTHESIS
  // Credits never exceed the configured maximum.
  a_credit_bound : assert property (
    @(posedge clk_i) disable iff (!rst_ni)
    credits_q <= CreditMax
  );
`endif

endmodule : refresh_mgr
