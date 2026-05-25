// Copyright 2026 The Netie Open HBM Authors
// SPDX-License-Identifier: Apache-2.0
//
// Top: NUM_CHANNELS pseudo-channels, each an independent AXI4 + 16-bank cluster.
`default_nettype none
`timescale 1ns/1ps

module hbm4_ctrl #(
    parameter int unsigned NUM_CHANNELS  = 1,
    parameter int unsigned AXI_ID_W      = hbm4_ctrl_pkg::AXI_ID_W,
    parameter int unsigned AXI_ADDR_W    = hbm4_ctrl_pkg::AXI_ADDR_W,
    parameter int unsigned AXI_DATA_W    = hbm4_ctrl_pkg::AXI_DATA_W,
    parameter int unsigned BANK_GROUPS   = hbm4_ctrl_pkg::BANK_GROUPS,
    parameter int unsigned BANKS_PER_BG  = hbm4_ctrl_pkg::BANKS_PER_BG,
    parameter int unsigned ROW_W         = hbm4_ctrl_pkg::ROW_W,
    parameter int unsigned COL_W           = hbm4_ctrl_pkg::COL_W,
    parameter int unsigned T_RCD           = hbm4_ctrl_pkg::T_RCD,
    parameter int unsigned T_RAS           = hbm4_ctrl_pkg::T_RAS,
    parameter int unsigned T_RP            = hbm4_ctrl_pkg::T_RP,
    parameter int unsigned T_RC            = hbm4_ctrl_pkg::T_RC
) (
    input logic clk_i,
    input logic rst_ni,

    input  logic [AXI_ID_W-1:0]     awid_i [0:NUM_CHANNELS-1],  // verilog_lint: waive unpacked-dimensions-range-ordering
    input  logic [AXI_ADDR_W-1:0]   awaddr_i [0:NUM_CHANNELS-1],  // verilog_lint: waive unpacked-dimensions-range-ordering
    input  logic [7:0]              awlen_i [0:NUM_CHANNELS-1],  // verilog_lint: waive unpacked-dimensions-range-ordering
    input  logic [2:0]              awsize_i [0:NUM_CHANNELS-1],  // verilog_lint: waive unpacked-dimensions-range-ordering
    input  logic [1:0]              awburst_i [0:NUM_CHANNELS-1],  // verilog_lint: waive unpacked-dimensions-range-ordering
    input  logic                    awvalid_i [0:NUM_CHANNELS-1],  // verilog_lint: waive unpacked-dimensions-range-ordering
    output logic                    awready_o [0:NUM_CHANNELS-1],  // verilog_lint: waive unpacked-dimensions-range-ordering

    input  logic [AXI_DATA_W-1:0]    wdata_i [0:NUM_CHANNELS-1],  // verilog_lint: waive unpacked-dimensions-range-ordering
    input  logic [AXI_DATA_W/8-1:0] wstrb_i [0:NUM_CHANNELS-1],  // verilog_lint: waive unpacked-dimensions-range-ordering
    input  logic                    wlast_i [0:NUM_CHANNELS-1],  // verilog_lint: waive unpacked-dimensions-range-ordering
    input  logic                    wvalid_i [0:NUM_CHANNELS-1],  // verilog_lint: waive unpacked-dimensions-range-ordering
    output logic                    wready_o [0:NUM_CHANNELS-1],  // verilog_lint: waive unpacked-dimensions-range-ordering

    output logic [AXI_ID_W-1:0] bid_o [0:NUM_CHANNELS-1],  // verilog_lint: waive unpacked-dimensions-range-ordering
    output logic [1:0]          bresp_o [0:NUM_CHANNELS-1],  // verilog_lint: waive unpacked-dimensions-range-ordering
    output logic                bvalid_o [0:NUM_CHANNELS-1],  // verilog_lint: waive unpacked-dimensions-range-ordering
    input  logic                bready_i [0:NUM_CHANNELS-1],  // verilog_lint: waive unpacked-dimensions-range-ordering

    input  logic [AXI_ID_W-1:0]   arid_i [0:NUM_CHANNELS-1],  // verilog_lint: waive unpacked-dimensions-range-ordering
    input  logic [AXI_ADDR_W-1:0] araddr_i [0:NUM_CHANNELS-1],  // verilog_lint: waive unpacked-dimensions-range-ordering
    input  logic [7:0]            arlen_i [0:NUM_CHANNELS-1],  // verilog_lint: waive unpacked-dimensions-range-ordering
    input  logic [2:0]            arsize_i [0:NUM_CHANNELS-1],  // verilog_lint: waive unpacked-dimensions-range-ordering
    input  logic [1:0]            arburst_i [0:NUM_CHANNELS-1],  // verilog_lint: waive unpacked-dimensions-range-ordering
    input  logic                  arvalid_i [0:NUM_CHANNELS-1],  // verilog_lint: waive unpacked-dimensions-range-ordering
    output logic                  arready_o [0:NUM_CHANNELS-1],  // verilog_lint: waive unpacked-dimensions-range-ordering

    output logic [AXI_ID_W-1:0]   rid_o [0:NUM_CHANNELS-1],  // verilog_lint: waive unpacked-dimensions-range-ordering
    output logic [AXI_DATA_W-1:0] rdata_o [0:NUM_CHANNELS-1],  // verilog_lint: waive unpacked-dimensions-range-ordering
    output logic [1:0]            rresp_o [0:NUM_CHANNELS-1],  // verilog_lint: waive unpacked-dimensions-range-ordering
    output logic                  rlast_o [0:NUM_CHANNELS-1],  // verilog_lint: waive unpacked-dimensions-range-ordering
    output logic                  rvalid_o [0:NUM_CHANNELS-1],  // verilog_lint: waive unpacked-dimensions-range-ordering
    input  logic                  rready_i [0:NUM_CHANNELS-1],  // verilog_lint: waive unpacked-dimensions-range-ordering

    output logic                  cmd_valid_o [0:NUM_CHANNELS-1],  // verilog_lint: waive unpacked-dimensions-range-ordering
    output hbm4_ctrl_pkg::cmd_e  cmd_o [0:NUM_CHANNELS-1],  // verilog_lint: waive unpacked-dimensions-range-ordering
    output hbm4_ctrl_pkg::bank_addr_t cmd_bank_o [0:NUM_CHANNELS-1],  // verilog_lint: waive unpacked-dimensions-range-ordering
    output logic [ROW_W-1:0]     cmd_row_o [0:NUM_CHANNELS-1],  // verilog_lint: waive unpacked-dimensions-range-ordering
    output logic [COL_W-1:0]     cmd_col_o [0:NUM_CHANNELS-1],  // verilog_lint: waive unpacked-dimensions-range-ordering
    output logic                  drfm_req_o [0:NUM_CHANNELS-1],  // verilog_lint: waive unpacked-dimensions-range-ordering
    input  logic                  drfm_ack_i [0:NUM_CHANNELS-1],  // verilog_lint: waive unpacked-dimensions-range-ordering
    output hbm4_ctrl_pkg::bank_state_e fpv_bank0_state_o,
    output logic [15:0]                fpv_bank0_ras_cnt_o
);

  import hbm4_ctrl_pkg::*;

  bank_state_e fpv_bank_state [0:NUM_CHANNELS-1];  // verilog_lint: waive unpacked-dimensions-range-ordering
  logic [15:0] fpv_bank_ras [0:NUM_CHANNELS-1];  // verilog_lint: waive unpacked-dimensions-range-ordering

  genvar ch;
  generate
    for (ch = 0; ch < NUM_CHANNELS; ch++) begin : g_channel
      hbm4_ctrl_chan_top #(
          .CHAN_ID      (ch),
          .AXI_ID_W     (AXI_ID_W),
          .AXI_ADDR_W   (AXI_ADDR_W),
          .AXI_DATA_W   (AXI_DATA_W),
          .BANK_GROUPS  (BANK_GROUPS),
          .BANKS_PER_BG (BANKS_PER_BG),
          .ROW_W        (ROW_W),
          .COL_W        (COL_W),
          .T_RCD        (T_RCD),
          .T_RAS        (T_RAS),
          .T_RP         (T_RP),
          .T_RC         (T_RC)
      ) u_chan (
          .clk_i              (clk_i),
          .rst_ni             (rst_ni),
          .awid_i             (awid_i[ch]),
          .awaddr_i           (awaddr_i[ch]),
          .awlen_i            (awlen_i[ch]),
          .awsize_i           (awsize_i[ch]),
          .awburst_i          (awburst_i[ch]),
          .awvalid_i          (awvalid_i[ch]),
          .awready_o          (awready_o[ch]),
          .wdata_i            (wdata_i[ch]),
          .wstrb_i            (wstrb_i[ch]),
          .wlast_i            (wlast_i[ch]),
          .wvalid_i           (wvalid_i[ch]),
          .wready_o           (wready_o[ch]),
          .bid_o              (bid_o[ch]),
          .bresp_o            (bresp_o[ch]),
          .bvalid_o           (bvalid_o[ch]),
          .bready_i           (bready_i[ch]),
          .arid_i             (arid_i[ch]),
          .araddr_i           (araddr_i[ch]),
          .arlen_i            (arlen_i[ch]),
          .arsize_i           (arsize_i[ch]),
          .arburst_i          (arburst_i[ch]),
          .arvalid_i          (arvalid_i[ch]),
          .arready_o          (arready_o[ch]),
          .rid_o              (rid_o[ch]),
          .rdata_o            (rdata_o[ch]),
          .rresp_o            (rresp_o[ch]),
          .rlast_o            (rlast_o[ch]),
          .rvalid_o           (rvalid_o[ch]),
          .rready_i           (rready_i[ch]),
          .cmd_valid_o        (cmd_valid_o[ch]),
          .cmd_o              (cmd_o[ch]),
          .cmd_bank_o         (cmd_bank_o[ch]),
          .cmd_row_o          (cmd_row_o[ch]),
          .cmd_col_o          (cmd_col_o[ch]),
          .drfm_req_o         (drfm_req_o[ch]),
          .drfm_ack_i         (drfm_ack_i[ch]),
          .fpv_bank0_state_o  (fpv_bank_state[ch]),
          .fpv_bank0_ras_cnt_o(fpv_bank_ras[ch])
      );
    end
  endgenerate

  assign fpv_bank0_state_o   = fpv_bank_state[0];
  assign fpv_bank0_ras_cnt_o = fpv_bank_ras[0];

endmodule : hbm4_ctrl

`default_nettype wire
