// Copyright 2026 The Netie Open HBM Authors
// SPDX-License-Identifier: Apache-2.0
//
// addr_map_reg_top.sv -- THIS FILE IS A PLACEHOLDER for the reggen output.
//
// In the production flow this file is GENERATED from data/addr_map.hjson by
// util/reggen/regtool.py. The placeholder below exists so the IP elaborates
// during scaffolding -- it forwards bare CSR signals through. It is illegal
// to hand-edit a real <ip>_reg_top.sv per CLAUDE.md s7.

`default_nettype none
`timescale 1ns/1ps

module addr_map_reg_top
  import addr_map_pkg::*;
#(
  parameter int unsigned ApbAW = 12,
  parameter int unsigned ApbDW = 32
)(
  input  logic              clk_i,
  input  logic              rst_ni,

  // APB
  input  logic              apb_psel_i,
  input  logic              apb_penable_i,
  input  logic              apb_pwrite_i,
  input  logic [ApbAW-1:0]  apb_paddr_i,
  input  logic [ApbDW-1:0]  apb_pwdata_i,
  output logic [ApbDW-1:0]  apb_prdata_o,
  output logic              apb_pready_o,
  output logic              apb_pslverr_o,

  // Region table side (to addr_map.sv)
  output logic              cfg_we_o,
  output logic [3:0]        cfg_idx_o,
  output region_t           cfg_wdata_o,
  output logic              cfg_commit_o,
  output mode_e             cfg_default_mode_o
);

  // Placeholder: every APB transaction completes in 1 cycle and writes
  // the lower 32 bits of region 0. Reggen replaces this with the real decoder.
  region_t scratch_q;
  mode_e   default_mode_q;

  always_ff @(posedge clk_i or negedge rst_ni) begin : p_apb
    if (!rst_ni) begin
      scratch_q       <= '0;
      default_mode_q  <= MODE_CH_STRIPED;
    end else if (apb_psel_i && apb_penable_i && apb_pwrite_i) begin
      scratch_q       <= region_t'(apb_pwdata_i);
      default_mode_q  <= MODE_CH_STRIPED;
    end
  end

  assign cfg_we_o          = apb_psel_i && apb_penable_i && apb_pwrite_i;
  assign cfg_idx_o         = '0;
  assign cfg_wdata_o       = scratch_q;
  assign cfg_commit_o      = apb_psel_i && apb_penable_i && apb_pwrite_i;
  assign cfg_default_mode_o = default_mode_q;

  assign apb_pready_o   = 1'b1;
  assign apb_pslverr_o  = 1'b0;
  assign apb_prdata_o   = '0;

endmodule : addr_map_reg_top
