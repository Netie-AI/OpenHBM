// Copyright 2026 The Netie Open HBM Authors
// SPDX-License-Identifier: Apache-2.0
//
// Formal wrapper + BMC assertions (bank 0 observability) with AXI4 stimulus.
`default_nettype none
`timescale 1ns/1ps

module hbm4_ctrl_fpv_wrapper;

  import hbm4_ctrl_pkg::*;
  import hbm4_ctrl_axi4_pkg::*;

  localparam int unsigned Aiw = AXI_ID_W;
  localparam int unsigned Aaw = AXI_ADDR_W;
  localparam int unsigned Adw = AXI_DATA_W;

  logic                  clk_i;
  logic                  rst_ni;

  logic [Aiw-1:0]        awid_i;
  logic [Aaw-1:0]        awaddr_i;
  logic [7:0]            awlen_i;
  logic [2:0]            awsize_i;
  logic [1:0]            awburst_i;
  logic                  awvalid_i;
  logic                  awready_o;

  logic [Adw-1:0]        wdata_i;
  logic [Adw/8-1:0]      wstrb_i;
  logic                  wlast_i;
  logic                  wvalid_i;
  logic                  wready_o;

  logic [Aiw-1:0]        bid_o;
  logic [1:0]            bresp_o;
  logic                  bvalid_o;
  logic                  bready_i;

  logic [Aiw-1:0]        arid_i;
  logic [Aaw-1:0]        araddr_i;
  logic [7:0]            arlen_i;
  logic [2:0]            arsize_i;
  logic [1:0]            arburst_i;
  logic                  arvalid_i;
  logic                  arready_o;

  logic [Aiw-1:0]        rid_o;
  logic [Adw-1:0]        rdata_o;
  logic [1:0]            rresp_o;
  logic                  rlast_o;
  logic                  rvalid_o;
  logic                  rready_i;

  logic                  cmd_valid_o;
  cmd_e                  cmd_o;
  bank_addr_t            cmd_bank_o;
  logic [ROW_W-1:0]     cmd_row_o;
  logic [COL_W-1:0]     cmd_col_o;
  logic                  drfm_req_o;
  logic                  drfm_ack_i;
  bank_state_e           fpv_bank0_state_o;
  logic [15:0]         fpv_bank0_ras_cnt_o;

  logic [15:0]         cyc_since_act;

  always_ff @(posedge clk_i or negedge rst_ni) begin : g_stim
    if (!rst_ni) begin
      awid_i     <= '0;
      awaddr_i   <= '0;
      awlen_i    <= '0;
      awsize_i   <= 3'd3;
      awburst_i  <= BURST_INCR;
      awvalid_i  <= 1'b0;
      wdata_i    <= '0;
      wstrb_i    <= '1;
      wlast_i    <= 1'b0;
      wvalid_i   <= 1'b0;
      bready_i   <= 1'b1;
      arid_i     <= '0;
      araddr_i   <= '0;
      arlen_i    <= '0;
      arsize_i   <= 3'd3;
      arburst_i  <= BURST_INCR;
      arvalid_i  <= 1'b0;
      rready_i   <= 1'b1;
      drfm_ack_i <= 1'b0;
    end else begin
      awvalid_i  <= ~awvalid_i;
      awaddr_i   <= awaddr_i ^ Aaw'(32'h0000_0040);
      arvalid_i  <= ~arvalid_i;
      araddr_i   <= araddr_i ^ Aaw'(32'h0000_0080);
      wvalid_i   <= awvalid_i;
      wlast_i    <= 1'b1;
      drfm_ack_i <= 1'b0;
    end
  end

`ifdef OPENHBM_FPV
  initial clk_i = 1'b0;
  always #5 clk_i = ~clk_i;

  initial begin
    rst_ni = 1'b0;
    #20;
    rst_ni = 1'b1;
  end
`endif

  hbm4_ctrl dut (
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
      .cmd_valid_o        (cmd_valid_o),
      .cmd_o              (cmd_o),
      .cmd_bank_o         (cmd_bank_o),
      .cmd_row_o          (cmd_row_o),
      .cmd_col_o          (cmd_col_o),
      .drfm_req_o         (drfm_req_o),
      .drfm_ack_i         (drfm_ack_i),
      .fpv_bank0_state_o (fpv_bank0_state_o),
      .fpv_bank0_ras_cnt_o(fpv_bank0_ras_cnt_o)
  );

  hbm4_ctrl_abs u_abs (
      .clk_i       (clk_i),
      .rst_ni      (rst_ni),
      .awvalid_i   (awvalid_i),
      .awaddr_i    (awaddr_i),
      .arvalid_i   (arvalid_i),
      .drfm_ack_i  (drfm_ack_i)
  );

  always_ff @(posedge clk_i or negedge rst_ni) begin : g_cyc_act
    if (!rst_ni) begin
      cyc_since_act <= '0;
    end else begin
      if (cmd_valid_o && (cmd_bank_o == '0) && (cmd_o == ACT)) begin
        cyc_since_act <= '0;
      end else begin
        cyc_since_act <= cyc_since_act + 16'd1;
      end
    end
  end

  a_no_rdwr_idle : assert property (@(posedge clk_i) disable iff (!rst_ni)
      (cmd_valid_o && (cmd_bank_o == '0) && ((cmd_o == RD) || (cmd_o == WR))) |->
      (fpv_bank0_state_o == BANK_ACTIVE));

  a_rcd : assert property (@(posedge clk_i) disable iff (!rst_ni)
      (cmd_valid_o && (cmd_bank_o == '0) && (cmd_o == RD)) |-> (cyc_since_act >= T_RCD));

  a_ras : assert property (@(posedge clk_i) disable iff (!rst_ni)
      (cmd_valid_o && (cmd_bank_o == '0) && (cmd_o == PRE)) |-> (fpv_bank0_ras_cnt_o >= T_RAS));

endmodule : hbm4_ctrl_fpv_wrapper

`default_nettype wire
