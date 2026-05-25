// Copyright 2026 The Netie Open HBM Authors
// SPDX-License-Identifier: Apache-2.0
//
// Single pseudo-channel: AXI4 slave + sixteen per-bank FSMs + round-robin scheduler.
`default_nettype none
`timescale 1ns/1ps

module hbm4_ctrl_chan_top #(
    parameter int unsigned CHAN_ID       = 0,
    parameter int unsigned AXI_ID_W      = hbm4_ctrl_pkg::AXI_ID_W,
    parameter int unsigned AXI_ADDR_W    = hbm4_ctrl_pkg::AXI_ADDR_W,
    parameter int unsigned AXI_DATA_W    = hbm4_ctrl_pkg::AXI_DATA_W,
    parameter int unsigned BANK_GROUPS   = hbm4_ctrl_pkg::BANK_GROUPS,
    parameter int unsigned BANKS_PER_BG  = hbm4_ctrl_pkg::BANKS_PER_BG,
    parameter int unsigned ROW_W         = hbm4_ctrl_pkg::ROW_W,
    parameter int unsigned COL_W         = hbm4_ctrl_pkg::COL_W,
    parameter int unsigned T_RCD         = hbm4_ctrl_pkg::T_RCD,
    parameter int unsigned T_RAS         = hbm4_ctrl_pkg::T_RAS,
    parameter int unsigned T_RP          = hbm4_ctrl_pkg::T_RP,
    parameter int unsigned T_RC          = hbm4_ctrl_pkg::T_RC
) (
    input logic clk_i,
    input logic rst_ni,

    input  logic [AXI_ID_W-1:0]     awid_i,
    input  logic [AXI_ADDR_W-1:0]   awaddr_i,
    input  logic [7:0]              awlen_i,
    input  logic [2:0]              awsize_i,
    input  logic [1:0]              awburst_i,
    input  logic                    awvalid_i,
    output logic                    awready_o,

    input  logic [AXI_DATA_W-1:0]    wdata_i,
    input  logic [AXI_DATA_W/8-1:0] wstrb_i,
    input  logic                    wlast_i,
    input  logic                    wvalid_i,
    output logic                    wready_o,

    output logic [AXI_ID_W-1:0] bid_o,
    output logic [1:0]            bresp_o,
    output logic                  bvalid_o,
    input  logic                  bready_i,

    input  logic [AXI_ID_W-1:0]   arid_i,
    input  logic [AXI_ADDR_W-1:0] araddr_i,
    input  logic [7:0]            arlen_i,
    input  logic [2:0]            arsize_i,
    input  logic [1:0]            arburst_i,
    input  logic                  arvalid_i,
    output logic                  arready_o,

    output logic [AXI_ID_W-1:0]   rid_o,
    output logic [AXI_DATA_W-1:0] rdata_o,
    output logic [1:0]            rresp_o,
    output logic                  rlast_o,
    output logic                  rvalid_o,
    input  logic                  rready_i,

    output logic                  cmd_valid_o,
    output hbm4_ctrl_pkg::cmd_e  cmd_o,
    output hbm4_ctrl_pkg::bank_addr_t cmd_bank_o,
    output logic [ROW_W-1:0]     cmd_row_o,
    output logic [COL_W-1:0]     cmd_col_o,
    output logic                  drfm_req_o,
    input  logic                  drfm_ack_i,
    output hbm4_ctrl_pkg::bank_state_e fpv_bank0_state_o,
    output logic [15:0]           fpv_bank0_ras_cnt_o
);

  import hbm4_ctrl_pkg::*;

  localparam int unsigned NumB = BANK_GROUPS * BANKS_PER_BG;

  logic                  int_req_valid;
  bank_addr_t           int_req_bank;
  logic [ROW_W-1:0]     int_req_row;
  logic [COL_W-1:0]     int_req_col;
  logic                  int_req_we;
  logic                  int_req_ready;

  logic cmd_fire;
  assign cmd_fire = cmd_valid_o;

  hbm4_ctrl_axi4_slave #(
      .P_AXI_ID_W(AXI_ID_W),
      .P_AXI_ADDR_W(AXI_ADDR_W),
      .P_AXI_DATA_W(AXI_DATA_W),
      .P_ROW_W(ROW_W),
      .P_COL_W(COL_W),
      .P_BANK_GROUPS(BANK_GROUPS),
      .P_BANKS_PER_BG(BANKS_PER_BG)
  ) u_axi (
      .clk_i              (clk_i),
      .rst_ni             (rst_ni),
      .awid_i             (awid_i),
      .awaddr_i           (awaddr_i),
      .awlen_i            (awlen_i),
      .awsize_i           (awsize_i),
      .awburst_i          (awburst_i),
      .awvalid_i          (awvalid_i),
      .awready_o          (awready_o),
      .wdata_i            (wdata_i),
      .wstrb_i            (wstrb_i),
      .wlast_i            (wlast_i),
      .wvalid_i           (wvalid_i),
      .wready_o           (wready_o),
      .bid_o              (bid_o),
      .bresp_o            (bresp_o),
      .bvalid_o           (bvalid_o),
      .bready_i           (bready_i),
      .arid_i             (arid_i),
      .araddr_i           (araddr_i),
      .arlen_i            (arlen_i),
      .arsize_i           (arsize_i),
      .arburst_i          (arburst_i),
      .arvalid_i          (arvalid_i),
      .arready_o          (arready_o),
      .rid_o              (rid_o),
      .rdata_o            (rdata_o),
      .rresp_o            (rresp_o),
      .rlast_o            (rlast_o),
      .rvalid_o           (rvalid_o),
      .rready_i           (rready_i),
      .core_req_valid_o   (int_req_valid),
      .core_req_bank_o    (int_req_bank),
      .core_req_row_o     (int_req_row),
      .core_req_col_o     (int_req_col),
      .core_req_we_o      (int_req_we),
      .core_req_ready_i   (int_req_ready),
      .cmd_fire_i         (cmd_fire),
      .cmd_i              (cmd_o),
      .cmd_bank_i         (cmd_bank_o)
  );

  logic [NumB-1:0]                 b_req_ready;
  logic [NumB-1:0]                 b_cmd_valid;
  cmd_e [NumB-1:0]                 b_cmd;
  row_t [NumB-1:0]                 b_cmd_row;
  col_t [NumB-1:0]                 b_cmd_col;
  logic [NumB-1:0]                 b_cmd_accept;
  logic [NumB-1:0]                 b_refresh_req;
  bank_state_e [NumB-1:0]          b_bank_state;
  logic [15:0]                     b_ras_dbg[NumB];

  logic [15:0]                     cyc_q;
  logic                            drfm_arm_q;

  always_ff @(posedge clk_i or negedge rst_ni) begin : g_drfm_tim
    if (!rst_ni) begin
      cyc_q      <= '0;
      drfm_arm_q <= 1'b0;
    end else begin
      cyc_q <= cyc_q + 16'd1;
      if (cyc_q == 16'd240) begin
        drfm_arm_q <= 1'b1;
      end
      if (drfm_ack_i) begin
        drfm_arm_q <= 1'b0;
      end
    end
  end

  assign drfm_req_o = drfm_arm_q;

  always_comb begin : g_rf0
    b_refresh_req = '0;
    b_refresh_req[0] = drfm_ack_i;
  end

  genvar gi;
  generate
    for (gi = 0; gi < NumB; gi++) begin : g_bank
      hbm4_ctrl_bank_fsm #(
          .P_T_RCD (T_RCD),
          .P_T_RAS (T_RAS),
          .P_T_RP  (T_RP),
          .P_T_RC  (T_RC),
          .P_ROW_W (ROW_W),
          .P_COL_W (COL_W)
      ) u_bank (
          .clk_i           (clk_i),
          .rst_ni          (rst_ni),
          .req_valid_i     (int_req_valid && (int_req_bank == bank_addr_t'(gi))),
          .req_row_i       (int_req_row),
          .req_col_i       (int_req_col),
          .req_we_i        (int_req_we),
          .req_ready_o     (b_req_ready[gi]),
          .cmd_valid_o     (b_cmd_valid[gi]),
          .cmd_o           (b_cmd[gi]),
          .cmd_row_o       (b_cmd_row[gi]),
          .cmd_col_o       (b_cmd_col[gi]),
          .cmd_accepted_i  (b_cmd_accept[gi]),
          .refresh_req_i   (b_refresh_req[gi]),
          .refresh_ack_o   (),
          .bank_state_o    (b_bank_state[gi]),
          .dbg_ras_cnt_o   (b_ras_dbg[gi])
      );
    end
  endgenerate

  hbm4_ctrl_scheduler #(
      .P_NUM_BANKS (NumB)
  ) u_sched (
      .clk_i               (clk_i),
      .rst_ni              (rst_ni),
      .bank_cmd_valid_i    (b_cmd_valid),
      .bank_cmd_i          (b_cmd),
      .bank_cmd_row_i      (b_cmd_row),
      .bank_cmd_col_i      (b_cmd_col),
      .cmd_valid_o         (cmd_valid_o),
      .cmd_o               (cmd_o),
      .cmd_bank_o          (cmd_bank_o),
      .cmd_row_o           (cmd_row_o),
      .cmd_col_o           (cmd_col_o),
      .cmd_accepted_i      (cmd_valid_o),
      .bank_cmd_accepted_o (b_cmd_accept)
  );

  always_comb begin : g_rr
    int_req_ready = 1'b0;
    for (int unsigned bi = 0; bi < NumB; bi++) begin
      if (int_req_bank == bank_addr_t'(bi)) begin
        int_req_ready = b_req_ready[bi];
      end
    end
  end

  assign fpv_bank0_state_o   = b_bank_state[0];
  assign fpv_bank0_ras_cnt_o = b_ras_dbg[0];

endmodule : hbm4_ctrl_chan_top

`default_nettype wire
