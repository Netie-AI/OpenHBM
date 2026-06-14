// Copyright 2026 The Netie Open HBM Authors
// SPDX-License-Identifier: Apache-2.0
//
// Happy path (one read, same row): IDLE/ACT wait -> RCD (tRCD) -> ACTIVE -> RD -> PRE -> RP -> IDLE.
// Row change: ACTIVE sees different row -> PRE (after tRAS) -> RP -> ACT new row -> ...
`default_nettype none
`timescale 1ns/1ps

module hbm4_ctrl_bank_fsm #(
    parameter int unsigned P_T_RCD = hbm4_ctrl_pkg::T_RCD,
    parameter int unsigned P_T_RAS = hbm4_ctrl_pkg::T_RAS,
    parameter int unsigned P_T_RP  = hbm4_ctrl_pkg::T_RP,
    parameter int unsigned P_T_RC  = hbm4_ctrl_pkg::T_RC,
    parameter int unsigned P_ROW_W = hbm4_ctrl_pkg::ROW_W,
    parameter int unsigned P_COL_W = hbm4_ctrl_pkg::COL_W
) (
    input  logic                  clk_i,
    input  logic                  rst_ni,
    input  logic                  req_valid_i,
    input  logic [P_ROW_W-1:0]   req_row_i,
    input  logic [P_COL_W-1:0]   req_col_i,
    input  logic                  req_we_i,
    output logic                  req_ready_o,
    output logic                  cmd_valid_o,
    output hbm4_ctrl_pkg::cmd_e  cmd_o,
    output logic [P_ROW_W-1:0]   cmd_row_o,
    output logic [P_COL_W-1:0]   cmd_col_o,
    input  logic                  cmd_accepted_i,
    input  logic                  refresh_req_i,
    output logic                  refresh_ack_o,
    output hbm4_ctrl_pkg::bank_state_e bank_state_o,
    output logic [15:0]                dbg_ras_cnt_o
);

  import hbm4_ctrl_pkg::*;

  typedef enum logic [3:0] {
    S_IDLE,
    S_ACT,
    S_RCD,
    S_ACTIVE,
    S_WAIT_RAS,
    S_PRE,
    S_RP
  } st_e;

  st_e                 st_q;
  row_t                open_row_q;
  row_t                lat_row_q;
  col_t                lat_col_q;
  logic                lat_we_q;
  logic                refr_pending_q;
  logic [15:0]         rcd_cnt_q;
  logic [15:0]         ras_cnt_q;
  logic [15:0]         rp_cnt_q;
  logic [15:0]         rc_cnt_q;

  logic                pend_rd_q;
  logic                pend_wr_q;

  logic                refr_pending_d;
  logic                refr_ack_pulse;
  st_e                 st_d;
  row_t                open_row_d;
  row_t                lat_row_d;
  col_t                lat_col_d;
  logic                lat_we_d;
  logic [15:0]         rcd_cnt_d;
  logic [15:0]         ras_cnt_d;
  logic [15:0]         rp_cnt_d;
  logic [15:0]         rc_cnt_d;

  logic                refr_clr;

  always_comb begin : g_ns
    st_d             = st_q;
    open_row_d       = open_row_q;
    lat_row_d        = lat_row_q;
    lat_col_d        = lat_col_q;
    lat_we_d         = lat_we_q;
    refr_pending_d   = refr_pending_q;
    rcd_cnt_d        = rcd_cnt_q;
    ras_cnt_d        = ras_cnt_q;
    rp_cnt_d         = rp_cnt_q;
    rc_cnt_d         = rc_cnt_q + 16'd1;
    refr_ack_pulse   = 1'b0;

    cmd_valid_o      = 1'b0;
    cmd_o            = IDLE_CMD;
    cmd_row_o        = open_row_q;
    cmd_col_o        = lat_col_q;
    req_ready_o      = 1'b0;

    unique case (st_q)
      S_IDLE: begin
        ras_cnt_d = '0;
        rcd_cnt_d = '0;
        if (refr_pending_d) begin
          cmd_valid_o = 1'b1;
          cmd_o       = REF;
          cmd_row_o   = '0;
          cmd_col_o   = '0;
          if (cmd_accepted_i) begin
            refr_ack_pulse = 1'b1;
            rc_cnt_d       = '0;
          end
        end else if (req_valid_i && (rc_cnt_q >= P_T_RC)) begin
          req_ready_o = 1'b1;
          lat_row_d   = req_row_i;
          lat_col_d   = req_col_i;
          lat_we_d    = req_we_i;
          st_d        = S_ACT;
        end
      end

      S_ACT: begin
        cmd_valid_o = 1'b1;
        cmd_o       = ACT;
        cmd_row_o   = lat_row_q;
        cmd_col_o   = lat_col_q;
        if (cmd_accepted_i) begin
          st_d       = S_RCD;
          open_row_d = lat_row_q;
          rcd_cnt_d  = '0;
          ras_cnt_d  = '0;
          rc_cnt_d   = '0;
        end
      end

      S_RCD: begin
        ras_cnt_d = ras_cnt_q + 16'd1;
        rcd_cnt_d = rcd_cnt_q + 16'd1;
        if (refr_pending_d && (ras_cnt_q >= P_T_RAS)) begin
          st_d     = S_PRE;
          rp_cnt_d = '0;
        end else if (rcd_cnt_q == P_T_RCD - 1) begin
          st_d = S_ACTIVE;
        end
      end

      S_ACTIVE: begin
        ras_cnt_d = ras_cnt_q + 16'd1;
        cmd_row_o = open_row_q;
        cmd_col_o = lat_col_q;
        if (refr_pending_d && (ras_cnt_q >= P_T_RAS)) begin
          st_d     = S_PRE;
          rp_cnt_d = '0;
        end else if (lat_we_q && pend_wr_q) begin
          cmd_valid_o = 1'b1;
          cmd_o       = WR;
          cmd_row_o   = open_row_q;
          cmd_col_o   = lat_col_q;
          if (cmd_accepted_i) begin
            st_d = S_WAIT_RAS;
          end
        end else if (!lat_we_q && pend_rd_q) begin
          cmd_valid_o = 1'b1;
          cmd_o       = RD;
          cmd_row_o   = open_row_q;
          cmd_col_o   = lat_col_q;
          if (cmd_accepted_i) begin
            st_d = S_WAIT_RAS;
          end
        end else if (req_valid_i && (req_row_i == open_row_q)) begin
          req_ready_o = 1'b1;
          lat_row_d   = req_row_i;
          lat_col_d   = req_col_i;
          lat_we_d    = req_we_i;
          cmd_valid_o = 1'b1;
          cmd_o       = lat_we_d ? WR : RD;
          if (cmd_accepted_i) begin
            st_d = S_WAIT_RAS;
          end
        end else if (req_valid_i && (req_row_i != open_row_q)) begin
          req_ready_o = 1'b1;
          lat_row_d   = req_row_i;
          lat_col_d   = req_col_i;
          lat_we_d    = req_we_i;
          if (ras_cnt_q >= P_T_RAS) begin
            st_d     = S_PRE;
            rp_cnt_d = '0;
          end
        end
      end

      S_PRE: begin
        cmd_valid_o = 1'b1;
        cmd_o       = PRE;
        cmd_row_o   = open_row_q;
        cmd_col_o   = lat_col_q;
        if (cmd_accepted_i) begin
          st_d     = S_RP;
          rp_cnt_d = '0;
        end
      end

      S_WAIT_RAS: begin
        ras_cnt_d = ras_cnt_q + 16'd1;
        if (ras_cnt_q >= P_T_RAS) begin
          st_d     = S_PRE;
          rp_cnt_d = '0;
        end
      end

      S_RP: begin
        rp_cnt_d = rp_cnt_q + 16'd1;
        if (rp_cnt_q == P_T_RP - 1) begin
          if (refr_pending_d) begin
            st_d = S_IDLE;
          end else if (pend_rd_q || pend_wr_q) begin
            st_d = S_ACT;
          end else begin
            st_d = S_IDLE;
          end
        end
      end

      default: begin
        st_d = S_IDLE;
      end
    endcase

    refr_clr =
        (st_q == S_IDLE) && refr_pending_q && cmd_valid_o && (cmd_o == REF) && cmd_accepted_i;
    if (refr_clr) begin
      refr_pending_d = 1'b0;
    end else if (refresh_req_i) begin
      refr_pending_d = 1'b1;
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin : g_seq
    if (!rst_ni) begin
      st_q           <= S_IDLE;
      open_row_q     <= '0;
      lat_row_q      <= '0;
      lat_col_q      <= '0;
      lat_we_q       <= 1'b0;
      pend_rd_q      <= 1'b0;
      pend_wr_q      <= 1'b0;
      refr_pending_q <= 1'b0;
      rcd_cnt_q      <= '0;
      ras_cnt_q      <= '0;
      rp_cnt_q       <= '0;
      rc_cnt_q       <= P_T_RC[15:0];
    end else begin
      st_q           <= st_d;
      open_row_q     <= open_row_d;
      lat_row_q      <= lat_row_d;
      lat_col_q      <= lat_col_d;
      lat_we_q       <= lat_we_d;
      refr_pending_q <= refr_pending_d;
      rcd_cnt_q      <= rcd_cnt_d;
      ras_cnt_q      <= ras_cnt_d;
      rp_cnt_q       <= rp_cnt_d;
      rc_cnt_q       <= rc_cnt_d;
      if (st_q == S_IDLE && req_valid_i && (rc_cnt_q >= P_T_RC) && !refr_pending_q) begin
        if (req_we_i) begin
          pend_wr_q <= 1'b1;
        end else begin
          pend_rd_q <= 1'b1;
        end
      end else if (st_q == S_RCD && st_d == S_ACTIVE) begin
        if (lat_we_q) begin
          pend_wr_q <= 1'b1;
        end else begin
          pend_rd_q <= 1'b1;
        end
      end else if (pend_rd_q && st_q == S_ACTIVE && st_d == S_WAIT_RAS) begin
        pend_rd_q <= 1'b0;
      end else if (pend_wr_q && st_q == S_ACTIVE && st_d == S_WAIT_RAS) begin
        pend_wr_q <= 1'b0;
      end else if (st_q == S_ACTIVE && req_valid_i && (req_row_i != open_row_q)) begin
        if (req_we_i) begin
          pend_wr_q <= 1'b1;
        end else begin
          pend_rd_q <= 1'b1;
        end
      end
    end
  end

  logic refr_ack_q;
  always_ff @(posedge clk_i or negedge rst_ni) begin : g_rack
    if (!rst_ni) begin
      refr_ack_q <= 1'b0;
    end else begin
      refr_ack_q <= refr_ack_pulse;
    end
  end

  assign refresh_ack_o = refr_ack_q;

  assign dbg_ras_cnt_o = ras_cnt_q;

  always_comb begin : g_bstate
    if ((st_q == S_IDLE) && !refr_pending_q) begin
      bank_state_o = BANK_IDLE;
    end else if (refr_pending_q) begin
      bank_state_o = BANK_REFRESH;
    end else begin
      bank_state_o = BANK_ACTIVE;
    end
  end

endmodule : hbm4_ctrl_bank_fsm
