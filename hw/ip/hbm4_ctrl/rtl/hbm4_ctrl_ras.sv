// Copyright 2026 The Netie Open HBM Authors
// SPDX-License-Identifier: Apache-2.0
//
// RAS: CE/UE interrupt latches, saturating counters, 8-entry error log FIFO.
`default_nettype none
`timescale 1ns/1ps

module hbm4_ctrl_ras
  import hbm4_ctrl_pkg::*;
#(
  parameter int unsigned NUM_BANKS = 16,
  parameter bit          INJECT_EN = 1'b1
) (
    input  logic                    clk_i,
    input  logic                    rst_ni,

    input  logic                    ce_i,
    input  logic                    ue_i,
    input  logic [3:0]              err_bank_i,
    input  logic [15:0]             err_addr_i,

    input  logic                    inject_ce_i,
    input  logic                    inject_ue_i,

    output logic                    ce_intr_o,
    output logic                    ue_intr_o,
    input  logic                    ce_clr_i,
    input  logic                    ue_clr_i,

    output logic [RAS_CTR_W-1:0]    ce_count_o,
    output logic [RAS_CTR_W-1:0]    ue_count_o,

    output logic                    log_valid_o,
    output hbm4_ctrl_pkg::ras_err_type_e log_type_o,
    output logic [3:0]              log_bank_o,
    output logic [15:0]             log_addr_o,
    input  logic                    log_pop_i
);

  localparam int unsigned PtrW = $clog2(RAS_LOG_DEPTH) + 1;
  localparam int unsigned IdxW = $clog2(RAS_LOG_DEPTH);

  logic                    effective_ce;
  logic                    effective_ue;
  logic                    log_full;
  logic                    log_empty;
  logic [IdxW-1:0]         log_widx;
  logic [IdxW-1:0]         log_ridx;

  logic                    ce_intr_q;
  logic                    ue_intr_q;
  logic [RAS_CTR_W-1:0]    ce_count_q;
  logic [RAS_CTR_W-1:0]    ue_count_q;
  logic [PtrW-1:0]         log_wptr_q;
  logic [PtrW-1:0]         log_rptr_q;
  hbm4_ctrl_pkg::ras_err_type_e log_type_mem_q [0:RAS_LOG_DEPTH-1];  // verilog_lint: waive unpacked-dimensions-range-ordering
  logic [3:0]              log_bank_mem_q [0:RAS_LOG_DEPTH-1];  // verilog_lint: waive unpacked-dimensions-range-ordering
  logic [15:0]             log_addr_mem_q [0:RAS_LOG_DEPTH-1];  // verilog_lint: waive unpacked-dimensions-range-ordering

  always_comb begin : g_inject_mux
    effective_ce = ce_i | (INJECT_EN & inject_ce_i);
    effective_ue = ue_i | (INJECT_EN & inject_ue_i);
  end

  assign log_full  = (log_wptr_q[IdxW] != log_rptr_q[IdxW]) &&
                     (log_wptr_q[IdxW-1:0] == log_rptr_q[IdxW-1:0]);
  assign log_empty = (log_wptr_q == log_rptr_q);
  assign log_widx  = log_wptr_q[IdxW-1:0];
  assign log_ridx  = log_rptr_q[IdxW-1:0];

  always_ff @(posedge clk_i or negedge rst_ni) begin : g_ras_seq
    if (!rst_ni) begin
      ce_intr_q   <= 1'b0;
      ue_intr_q   <= 1'b0;
      ce_count_q  <= '0;
      ue_count_q  <= '0;
      log_wptr_q  <= '0;
      log_rptr_q  <= '0;
    end else begin
      if (ce_clr_i) begin
        ce_intr_q <= 1'b0;
      end
      if (ue_clr_i) begin
        ue_intr_q <= 1'b0;
      end

      if (effective_ce) begin
        ce_intr_q <= 1'b1;
        if (ce_count_q != {RAS_CTR_W{1'b1}}) begin
          ce_count_q <= ce_count_q + RAS_CTR_W'(1);
        end
        if (!log_full) begin
          log_type_mem_q[log_widx] <= hbm4_ctrl_pkg::ERR_CE;
          log_bank_mem_q[log_widx] <= err_bank_i;
          log_addr_mem_q[log_widx] <= err_addr_i;
          log_wptr_q               <= log_wptr_q + PtrW'(1);
        end
      end

      if (effective_ue) begin
        ue_intr_q <= 1'b1;
        if (ue_count_q != {RAS_CTR_W{1'b1}}) begin
          ue_count_q <= ue_count_q + RAS_CTR_W'(1);
        end
        if (!log_full) begin
          log_type_mem_q[log_widx] <= hbm4_ctrl_pkg::ERR_UE;
          log_bank_mem_q[log_widx] <= err_bank_i;
          log_addr_mem_q[log_widx] <= err_addr_i;
          log_wptr_q               <= log_wptr_q + PtrW'(1);
        end
      end

      if (log_pop_i && !log_empty) begin
        log_rptr_q <= log_rptr_q + PtrW'(1);
      end
    end
  end

  assign ce_intr_o   = ce_intr_q;
  assign ue_intr_o   = ue_intr_q;
  assign ce_count_o  = ce_count_q;
  assign ue_count_o  = ue_count_q;
  assign log_valid_o = !log_empty;
  assign log_type_o  = log_type_mem_q[log_ridx];
  assign log_bank_o  = log_bank_mem_q[log_ridx];
  assign log_addr_o  = log_addr_mem_q[log_ridx];

endmodule : hbm4_ctrl_ras

`default_nettype wire
