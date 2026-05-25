// Copyright 2026 The Netie Open HBM Authors
// SPDX-License-Identifier: Apache-2.0
`default_nettype none
`timescale 1ns/1ps

module hbm4_ctrl_scheduler #(
    parameter int unsigned P_NUM_BANKS = hbm4_ctrl_pkg::NUM_BANKS
) (
    input  logic                                       clk_i,
    input  logic                                       rst_ni,
    input  logic [P_NUM_BANKS-1:0]                      bank_cmd_valid_i,
    input  hbm4_ctrl_pkg::cmd_e [P_NUM_BANKS-1:0]       bank_cmd_i,
    input  hbm4_ctrl_pkg::row_t [P_NUM_BANKS-1:0]       bank_cmd_row_i,
    input  hbm4_ctrl_pkg::col_t [P_NUM_BANKS-1:0]       bank_cmd_col_i,
    output logic                                       cmd_valid_o,
    output hbm4_ctrl_pkg::cmd_e                         cmd_o,
    output hbm4_ctrl_pkg::bank_addr_t                 cmd_bank_o,
    output hbm4_ctrl_pkg::row_t                        cmd_row_o,
    output hbm4_ctrl_pkg::col_t                        cmd_col_o,
    input  logic                                       cmd_accepted_i,
    output logic [P_NUM_BANKS-1:0]                    bank_cmd_accepted_o
);

  import hbm4_ctrl_pkg::*;

  bank_addr_t rr_q;
  bank_addr_t win_id;
  logic       found;

  always_comb begin : g_pick
    found = 1'b0;
    win_id = rr_q;
    for (int unsigned ii = 0; ii < P_NUM_BANKS; ii++) begin
      bank_addr_t cand;
      cand = bank_addr_t'(rr_q + bank_addr_t'(ii));
      if (!found && bank_cmd_valid_i[cand]) begin
        win_id = cand;
        found  = 1'b1;
      end
    end
  end

  assign cmd_valid_o = found;
  assign cmd_o       = found ? bank_cmd_i[win_id] : IDLE_CMD;
  assign cmd_row_o   = found ? bank_cmd_row_i[win_id] : '0;
  assign cmd_col_o   = found ? bank_cmd_col_i[win_id] : '0;
  assign cmd_bank_o  = win_id;

  always_comb begin : g_acc
    bank_cmd_accepted_o = '0;
    if (found && cmd_accepted_i) begin
      bank_cmd_accepted_o[win_id] = 1'b1;
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin : g_rr
    if (!rst_ni) begin
      rr_q <= '0;
    end else if (found && cmd_accepted_i) begin
      rr_q <= bank_addr_t'(win_id + bank_addr_t'(1));
    end
  end

endmodule : hbm4_ctrl_scheduler
