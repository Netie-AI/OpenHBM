// Copyright 2026 The Netie Open HBM Authors
// SPDX-License-Identifier: Apache-2.0
`default_nettype none
`timescale 1ns/1ps

// hbm4_ctrl -- top-level HBM4 controller (PHASE-1 SKELETON).
//
// 32 channels x 2 pseudo-channels per channel x 16 banks per pseudo-channel.
// Front-end: per-channel AXI4 + per-controller APB CSR. Back-end: per-channel
// DFI 5.x to hbm4_phy_shim.
//
// This Phase-1 skeleton instantiates a single bank machine per (channel,
// pseudo-channel, bank) for elaboration purposes; the inner FSM stub
// emits NOPs except for the smoke pattern. Full implementation (the
// real scheduler / refresh weave / data path) lands in Phase 2 once
// DRAMsim4 is co-running and addr_map / ecc / refresh_mgr are formally
// proved.
//
// Cycle-by-cycle behaviour, scheduler happy path:
//   c0: AXI request lands; addr_map_inst maps SA -> PA in 1 cycle.
//   c1: Scheduler chooses a bank machine (round-robin within channel).
//   c2: Bank machine emits ACT (or RD/WR if row already open).
//   c2+tRCD..tRCD+CL: Read data appears on the DFI read bus.
//   c2+CL+1..end of burst: Data flows back to the AXI port.

import hbm4_ctrl_pkg::*;
import addr_map_pkg::*;

module hbm4_ctrl #(
  parameter int unsigned NumCh         = NUM_CHANNELS,
  parameter int unsigned NumPCh        = NUM_PSEUDO_CHANNELS,
  parameter int unsigned NumBanks      = NUM_BANK_GROUPS * NUM_BANKS_PER_GROUP,
  parameter speed_e      DefaultSpeed  = SPEED_8000
)(
  input  logic         clk_i,
  input  logic         rst_ni,

  // System-side AXI4 (one per channel) -- bundled struct, defined later.
  // For Phase 1 we expose just request valid/ready + sa to keep the
  // interface compilable until the real AXI types arrive from
  // hw/vendor/pulp_common_cells/.
  input  logic [NumCh-1:0]                 axi_aw_valid_i,
  output logic [NumCh-1:0]                 axi_aw_ready_o,
  input  logic [NumCh-1:0][addr_map_pkg::SaW-1:0] axi_aw_addr_i,
  input  logic [NumCh-1:0]                 axi_ar_valid_i,
  output logic [NumCh-1:0]                 axi_ar_ready_o,
  input  logic [NumCh-1:0][addr_map_pkg::SaW-1:0] axi_ar_addr_i,

  // PHY-side DFI (one per channel, packed into a struct in Phase 2).
  output cmd_e        [NumCh-1:0][NumPCh-1:0] dfi_cmd_o,
  output logic        [NumCh-1:0][NumPCh-1:0] dfi_cmd_valid_o,
  output logic [16:0] [NumCh-1:0][NumPCh-1:0] dfi_row_o,
  output logic [5:0]  [NumCh-1:0][NumPCh-1:0] dfi_col_o,

  // APB CSR
  input  logic         apb_psel_i,
  input  logic         apb_penable_i,
  input  logic         apb_pwrite_i,
  input  logic [11:0]  apb_paddr_i,
  input  logic [31:0]  apb_pwdata_i,
  output logic [31:0]  apb_prdata_o,
  output logic         apb_pready_o,
  output logic         apb_pslverr_o
);

  // ---------------------------------------------------------------------------
  // Address mapper (one instance, time-multiplexed across channels in Phase 1)
  // ---------------------------------------------------------------------------
  logic    [addr_map_pkg::SaW-1:0] map_sa;
  pa_t                              map_pa;
  logic                             map_req_v;
  logic                             map_req_r;
  logic                             map_rsp_v;
  op_e                              map_rsp_op;
  logic                             map_rsp_hit;

  // Trivial round-robin pull from per-channel AXI AR queues. (Phase-1 stub.)
  logic [$clog2(NumCh)-1:0] rr_q;
  always_ff @(posedge clk_i or negedge rst_ni) begin : p_rr
    if (!rst_ni) rr_q <= '0;
    else         rr_q <= rr_q + ($clog2(NumCh))'(1);
  end

  always_comb begin : c_pull
    map_req_v = axi_ar_valid_i[rr_q];
    map_sa    = axi_ar_addr_i[rr_q];
    for (int unsigned c = 0; c < NumCh; c++) begin
      axi_ar_ready_o[c] = (c == int'(rr_q)) && map_req_r;
      axi_aw_ready_o[c] = '0;
    end
  end

  addr_map u_addr_map (
    .clk_i,
    .rst_ni,
    .req_valid_i      (map_req_v),
    .req_ready_o      (map_req_r),
    .req_sa_i         (map_sa),
    .req_op_i         (OP_READ),
    .rsp_valid_o      (map_rsp_v),
    .rsp_ready_i      (1'b1),
    .rsp_pa_o         (map_pa),
    .rsp_op_o         (map_rsp_op),
    .rsp_region_hit_o (map_rsp_hit),
    .cfg_we_i         (1'b0),
    .cfg_idx_i        ('0),
    .cfg_wdata_i      ('0),
    .cfg_commit_i     (1'b0),
    .cfg_default_mode_i (MODE_CH_STRIPED)
  );

  // ---------------------------------------------------------------------------
  // Bank machine grid (NumCh x NumPCh x NumBanks). Phase-1 skeleton only
  // wires the (0,0,*) slot through; the rest are tied off.
  // ---------------------------------------------------------------------------
  cmd_e        bm_cmd        [NumBanks];
  logic        bm_cmd_valid  [NumBanks];
  logic [16:0] bm_cmd_row    [NumBanks];
  logic [5:0]  bm_cmd_col    [NumBanks];

  // Phase-1: a static timing struct populated by the CSR block.
  timing_t timing_q;
  always_ff @(posedge clk_i or negedge rst_ni) begin : p_timing
    if (!rst_ni) begin
      timing_q.tRCD     <= 8'd14;
      timing_q.tRP      <= 8'd14;
      timing_q.tRAS     <= 8'd28;
      timing_q.tRC      <= 8'd42;
      timing_q.tRFC_ab  <= 12'd200;
      timing_q.tRFC_pb  <= 12'd80;
      timing_q.tRFC_sb  <= 12'd120;
      timing_q.tREFI    <= 16'd1950;
      timing_q.tFAW     <= 8'd25;
      timing_q.tRRD_S   <= 5'd4;
      timing_q.tRRD_L   <= 5'd6;
      timing_q.tCCD_S   <= 5'd8;
      timing_q.tCCD_L   <= 5'd16;
      timing_q.tWR      <= 8'd16;
      timing_q.tWTR_S   <= 5'd4;
      timing_q.tWTR_L   <= 5'd6;
      timing_q.CL       <= 6'd24;
      timing_q.CWL      <= 6'd20;
    end
  end

  for (genvar b = 0; b < NumBanks; b++) begin : g_bank
    hbm4_bank_machine u_bm (
      .clk_i,
      .rst_ni,
      .timing_i        (timing_q),
      .req_valid_i     (b == 0 ? map_rsp_v : 1'b0),
      .req_ready_o     (),
      .req_row_i       (map_pa.row),
      .req_col_i       (map_pa.col),
      .req_is_write_i  (1'b0),
      .refresh_req_i   (1'b0),
      .refresh_mode_i  (REF_AB),
      .refresh_ack_o   (),
      .cmd_o           (bm_cmd[b]),
      .cmd_valid_o     (bm_cmd_valid[b]),
      .cmd_row_o       (bm_cmd_row[b]),
      .cmd_col_o       (bm_cmd_col[b]),
      .state_o         ()
    );
  end

  // ---------------------------------------------------------------------------
  // DFI fan-out -- Phase-1 stub: drive (0,0,*) onto channel 0 / pCh 0,
  // tie all others to NOP.
  // ---------------------------------------------------------------------------
  always_comb begin : c_dfi_fanout
    for (int unsigned c = 0; c < NumCh; c++) begin
      for (int unsigned p = 0; p < NumPCh; p++) begin
        dfi_cmd_o      [c][p] = CMD_NOP;
        dfi_cmd_valid_o[c][p] = 1'b0;
        dfi_row_o      [c][p] = '0;
        dfi_col_o      [c][p] = '0;
      end
    end
    // Single live slot (Phase-1 wiring placeholder).
    dfi_cmd_o      [0][0] = bm_cmd[0];
    dfi_cmd_valid_o[0][0] = bm_cmd_valid[0];
    dfi_row_o      [0][0] = bm_cmd_row[0];
    dfi_col_o      [0][0] = bm_cmd_col[0];
  end

  // APB CSR placeholder. Reggen-generated decoder lands in Phase 2.
  assign apb_pready_o   = 1'b1;
  assign apb_pslverr_o  = 1'b0;
  assign apb_prdata_o   = '0;

  // ---------------------------------------------------------------------------
  // SVA (Phase-1 placeholders -- the real timing-parameter assertions land
  // with the real timer logic).
  // ---------------------------------------------------------------------------
`ifndef SYNTHESIS
  // No two ACT commands on the same pseudo-channel in the same cycle.
  a_dfi_cmd_one_per_pch : assert property (
    @(posedge clk_i) disable iff (!rst_ni)
    $countones({ dfi_cmd_valid_o[0][0] }) <= 1
  );
`endif

endmodule : hbm4_ctrl
