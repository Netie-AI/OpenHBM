// Copyright 2026 The Netie Open HBM Authors
// SPDX-License-Identifier: Apache-2.0
`default_nettype none
`timescale 1ns/1ps

// hbm4_bank_machine -- per-bank state machine.
//
// PHASE-1 SKELETON. This block currently emits only NOPs. The state
// transitions are wired so the SVA assertions can already be exercised,
// but the inner timer logic is a placeholder. The full implementation is
// gated on DRAMsim4 (hw/vip/dramsim4/) being live; until then, see the
// timing narrative below for the canonical happy-path schedule.
//
// CYCLE-BY-CYCLE NARRATIVE (read-then-write happy path):
//
//   cycle  cmd_o    note
//   ----------------------------------------------
//   0      NOP      bank IDLE; req_valid_i seen with row_open=0
//   1      ACT      issue ACTIVATE -- start tRCD timer
//   1+tRCD RD       issue READ
//   1+tRCD+1..+CL   data appears on read_data_path
//   ...    NOP/RD/WR within the open-row window, respecting tCCD
//   N      PRE      issue PRECHARGE -- start tRP timer
//   N+tRP  IDLE     bank back to IDLE
//
// Refresh interleaves with the above: a REF_AB / REF_PB / DRFM command
// preempts ACT during the bank's idle window via refresh_acceptor.
import hbm4_ctrl_pkg::*;

module hbm4_bank_machine (
  input  logic         clk_i,
  input  logic         rst_ni,

  input  timing_t      timing_i,

  // Request from scheduler
  input  logic         req_valid_i,
  output logic         req_ready_o,
  input  logic [16:0]  req_row_i,
  input  logic [5:0]   req_col_i,
  input  logic         req_is_write_i,

  // Refresh request
  input  logic         refresh_req_i,
  input  refresh_mode_e refresh_mode_i,
  output logic         refresh_ack_o,

  // DFI command
  output cmd_e         cmd_o,
  output logic         cmd_valid_o,
  output logic [16:0]  cmd_row_o,
  output logic [5:0]   cmd_col_o,

  // Observable state for SVA / debug
  output bank_state_e  state_o
);

  bank_state_e state_q;
  bank_state_e state_d;
  logic [16:0] open_row_q;

  always_comb begin : c_state
    state_d   = state_q;
    cmd_o         = CMD_NOP;
    cmd_valid_o   = 1'b0;
    cmd_row_o     = '0;
    cmd_col_o     = '0;
    req_ready_o   = 1'b0;
    refresh_ack_o = 1'b0;

    unique case (state_q)
      BANK_IDLE: begin
        if (refresh_req_i) begin
          state_d   = BANK_REFRESH;
          cmd_valid_o = 1'b1;
          cmd_o = (refresh_mode_i == REF_DRFM) ? CMD_DRFM
                : (refresh_mode_i == REF_PB)   ? CMD_REF_PB
                                               : CMD_REF_AB;
          refresh_ack_o = 1'b1;
        end else if (req_valid_i) begin
          state_d   = BANK_ACT_WAIT;
          cmd_o     = CMD_ACT;
          cmd_valid_o = 1'b1;
          cmd_row_o = req_row_i;
          req_ready_o = 1'b0; // we accept by transitioning, not by ready
        end
      end
      BANK_ACT_WAIT: state_d = BANK_ACTIVE;          // skeleton: 1-cycle stand-in for tRCD
      BANK_ACTIVE: begin
        if (req_valid_i && req_row_i == open_row_q) begin
          state_d   = req_is_write_i ? BANK_WR : BANK_RD;
          cmd_o     = req_is_write_i ? CMD_WR : CMD_RD;
          cmd_valid_o = 1'b1;
          cmd_col_o = req_col_i;
          req_ready_o = 1'b1;
        end else if (req_valid_i || refresh_req_i) begin
          // need precharge first
          state_d   = BANK_PRE_WAIT;
          cmd_o     = CMD_PRE;
          cmd_valid_o = 1'b1;
        end
      end
      BANK_RD, BANK_WR: state_d = BANK_ACTIVE;
      BANK_PRE_WAIT:    state_d = BANK_IDLE;          // skeleton: 1-cycle tRP
      BANK_REFRESH:     state_d = BANK_IDLE;          // skeleton: 1-cycle tRFC
      BANK_DRFM:        state_d = BANK_IDLE;
      default:          state_d = BANK_IDLE;
    endcase
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin : p_state
    if (!rst_ni) begin
      state_q    <= BANK_IDLE;
      open_row_q <= '0;
    end else begin
      state_q <= state_d;
      if (cmd_valid_o && cmd_o == CMD_ACT) begin
        open_row_q <= req_row_i;
      end
    end
  end

  assign state_o = state_q;

  // ---------------------------------------------------------------------------
  // SVA -- protocol invariants. The skeleton wires them but they only
  // bite once tRCD/tRP timers are real.
  // ---------------------------------------------------------------------------
`ifndef SYNTHESIS
  // Bank in OPEN state has exactly one ACTIVE row.
  a_open_row_consistency : assert property (
    @(posedge clk_i) disable iff (!rst_ni)
    (state_q == BANK_ACTIVE) |-> ($stable(open_row_q))
  );
  // No ACT immediately followed by PRE in the same cycle (would be a fault).
  a_no_act_pre_same_cycle : assert property (
    @(posedge clk_i) disable iff (!rst_ni)
    !(cmd_valid_o && (cmd_o == CMD_ACT)
      && (state_d == BANK_PRE_WAIT))
  );
`endif

endmodule : hbm4_bank_machine
