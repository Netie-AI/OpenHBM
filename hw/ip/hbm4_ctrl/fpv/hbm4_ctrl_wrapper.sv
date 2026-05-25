// Copyright 2026 The Netie Open HBM Authors
// SPDX-License-Identifier: Apache-2.0
//
// Formal wrapper + BMC assertions (bank 0 observability) with AXI4 stimulus.
`default_nettype none
`timescale 1ns/1ps

module hbm4_ctrl_fpv_wrapper;

  import hbm4_ctrl_pkg::*;
  import hbm4_ctrl_axi4_pkg::*;
  import hbm4_ctrl_dfi_pkg::*;

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

  localparam int unsigned DfiAddrW = hbm4_ctrl_dfi_pkg::DFI_ADDR_W;
  localparam int unsigned DfiDataW = hbm4_ctrl_dfi_pkg::DFI_DATA_W;
  localparam int unsigned DfiBgW   = hbm4_ctrl_dfi_pkg::DFI_BG_W;
  localparam int unsigned DfiBankW = hbm4_ctrl_dfi_pkg::DFI_BANK_W;

  logic [DfiAddrW-1:0]   dfi_address_o;
  logic                  dfi_ras_n_o;
  logic                  dfi_cas_n_o;
  logic                  dfi_we_n_o;
  logic [DfiBgW-1:0]     dfi_bank_group_o;
  logic [DfiBankW-1:0]   dfi_bank_o;
  logic                  dfi_cs_n_o;
  logic                  dfi_cke_o;
  logic                  dfi_reset_n_o;
  logic [DfiDataW-1:0]   dfi_wrdata_o;
  logic [DfiDataW/8-1:0] dfi_wrdata_mask_o;
  logic                  dfi_wrdata_en_o;
  logic                  dfi_wrdata_ack_i;
  logic [DfiDataW-1:0]   dfi_rddata_i;
  logic                  dfi_rddata_valid_i;
  logic                  dfi_rddata_en_o;
  logic                  dfi_ctrlupd_req_o;
  logic                  dfi_ctrlupd_ack_i;
  logic                  dfi_phyupd_req_i;
  logic                  dfi_phyupd_ack_o;
  logic                  dfi_lp_ctrl_req_o;
  logic [3:0]            dfi_lp_ctrl_wakeup_o;
  logic                  dfi_lp_ctrl_ack_i;
  logic                  dfi_lp_data_req_o;
  logic                  dfi_lp_data_ack_i;

  logic                  pwrdn_req_i;
  logic                  sref_req_i;
  logic                  exit_req_i;
  hbm4_ctrl_pkg::chan_pw_state_e pw_state_o;

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
      pwrdn_req_i <= 1'b0;
      sref_req_i  <= 1'b0;
      exit_req_i  <= 1'b0;
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

  logic [Aiw-1:0]        awid_arr [0:0];
  logic [Aaw-1:0]        awaddr_arr [0:0];
  logic [7:0]            awlen_arr [0:0];
  logic [2:0]            awsize_arr [0:0];
  logic [1:0]            awburst_arr [0:0];
  logic                  awvalid_arr [0:0];
  logic                  awready_arr [0:0];
  logic [Adw-1:0]        wdata_arr [0:0];
  logic [Adw/8-1:0]      wstrb_arr [0:0];
  logic                  wlast_arr [0:0];
  logic                  wvalid_arr [0:0];
  logic                  wready_arr [0:0];
  logic [Aiw-1:0]        bid_arr [0:0];
  logic [1:0]            bresp_arr [0:0];
  logic                  bvalid_arr [0:0];
  logic                  bready_arr [0:0];
  logic [Aiw-1:0]        arid_arr [0:0];
  logic [Aaw-1:0]        araddr_arr [0:0];
  logic [7:0]            arlen_arr [0:0];
  logic [2:0]            arsize_arr [0:0];
  logic [1:0]            arburst_arr [0:0];
  logic                  arvalid_arr [0:0];
  logic                  arready_arr [0:0];
  logic [Aiw-1:0]        rid_arr [0:0];
  logic [Adw-1:0]        rdata_arr [0:0];
  logic [1:0]            rresp_arr [0:0];
  logic                  rlast_arr [0:0];
  logic                  rvalid_arr [0:0];
  logic                  rready_arr [0:0];
  logic                  cmd_valid_arr [0:0];
  cmd_e                  cmd_arr [0:0];
  bank_addr_t            cmd_bank_arr [0:0];
  logic [ROW_W-1:0]     cmd_row_arr [0:0];
  logic [COL_W-1:0]     cmd_col_arr [0:0];
  logic                  drfm_req_arr [0:0];
  logic                  drfm_ack_arr [0:0];
  logic [DfiAddrW-1:0]   dfi_address_arr [0:0];
  logic                  dfi_ras_n_arr [0:0];
  logic                  dfi_cas_n_arr [0:0];
  logic                  dfi_we_n_arr [0:0];
  logic [DfiBgW-1:0]     dfi_bank_group_arr [0:0];
  logic [DfiBankW-1:0]   dfi_bank_arr [0:0];
  logic                  dfi_cs_n_arr [0:0];
  logic                  dfi_cke_arr [0:0];
  logic                  dfi_reset_n_arr [0:0];
  logic [DfiDataW-1:0]   dfi_wrdata_arr [0:0];
  logic [DfiDataW/8-1:0] dfi_wrdata_mask_arr [0:0];
  logic                  dfi_wrdata_en_arr [0:0];
  logic                  dfi_wrdata_ack_arr [0:0];
  logic [DfiDataW-1:0]   dfi_rddata_arr [0:0];
  logic                  dfi_rddata_valid_arr [0:0];
  logic                  dfi_rddata_en_arr [0:0];
  logic                  dfi_ctrlupd_req_arr [0:0];
  logic                  dfi_ctrlupd_ack_arr [0:0];
  logic                  dfi_phyupd_req_arr [0:0];
  logic                  dfi_phyupd_ack_arr [0:0];
  logic                  dfi_lp_ctrl_req_arr [0:0];
  logic [3:0]            dfi_lp_ctrl_wakeup_arr [0:0];
  logic                  dfi_lp_ctrl_ack_arr [0:0];
  logic                  dfi_lp_data_req_arr [0:0];
  logic                  dfi_lp_data_ack_arr [0:0];
  logic                  pwrdn_req_arr [0:0];
  logic                  sref_req_arr [0:0];
  logic                  exit_req_arr [0:0];
  hbm4_ctrl_pkg::chan_pw_state_e pw_state_arr [0:0];

  assign dfi_wrdata_ack_i     = 1'b1;
  assign dfi_rddata_i         = '0;
  assign dfi_rddata_valid_i   = 1'b0;
  assign dfi_lp_ctrl_ack_i    = 1'b0;
  assign dfi_lp_data_ack_i    = 1'b0;

  assign awid_arr[0]     = awid_i;
  assign awaddr_arr[0]   = awaddr_i;
  assign awlen_arr[0]    = awlen_i;
  assign awsize_arr[0]   = awsize_i;
  assign awburst_arr[0]  = awburst_i;
  assign awvalid_arr[0]  = awvalid_i;
  assign wdata_arr[0]    = wdata_i;
  assign wstrb_arr[0]    = wstrb_i;
  assign wlast_arr[0]    = wlast_i;
  assign wvalid_arr[0]   = wvalid_i;
  assign bready_arr[0]   = bready_i;
  assign arid_arr[0]     = arid_i;
  assign araddr_arr[0]  = araddr_i;
  assign arlen_arr[0]    = arlen_i;
  assign arsize_arr[0]  = arsize_i;
  assign arburst_arr[0] = arburst_i;
  assign arvalid_arr[0] = arvalid_i;
  assign rready_arr[0]   = rready_i;
  assign drfm_ack_arr[0] = drfm_ack_i;
  assign pwrdn_req_arr[0] = pwrdn_req_i;
  assign sref_req_arr[0]  = sref_req_i;
  assign exit_req_arr[0]  = exit_req_i;

  assign awready_o   = awready_arr[0];
  assign wready_o    = wready_arr[0];
  assign bid_o       = bid_arr[0];
  assign bresp_o     = bresp_arr[0];
  assign bvalid_o    = bvalid_arr[0];
  assign arready_o   = arready_arr[0];
  assign rid_o       = rid_arr[0];
  assign rdata_o     = rdata_arr[0];
  assign rresp_o     = rresp_arr[0];
  assign rlast_o     = rlast_arr[0];
  assign rvalid_o    = rvalid_arr[0];
  assign cmd_valid_o = cmd_valid_arr[0];
  assign cmd_o       = cmd_arr[0];
  assign cmd_bank_o  = cmd_bank_arr[0];
  assign cmd_row_o   = cmd_row_arr[0];
  assign cmd_col_o   = cmd_col_arr[0];
  assign drfm_req_o  = drfm_req_arr[0];

  assign dfi_address_o        = dfi_address_arr[0];
  assign dfi_ras_n_o          = dfi_ras_n_arr[0];
  assign dfi_cas_n_o          = dfi_cas_n_arr[0];
  assign dfi_we_n_o           = dfi_we_n_arr[0];
  assign dfi_bank_group_o     = dfi_bank_group_arr[0];
  assign dfi_bank_o           = dfi_bank_arr[0];
  assign dfi_cs_n_o           = dfi_cs_n_arr[0];
  assign dfi_cke_o            = dfi_cke_arr[0];
  assign dfi_reset_n_o        = dfi_reset_n_arr[0];
  assign dfi_wrdata_o         = dfi_wrdata_arr[0];
  assign dfi_wrdata_mask_o    = dfi_wrdata_mask_arr[0];
  assign dfi_wrdata_en_o      = dfi_wrdata_en_arr[0];
  assign dfi_rddata_en_o      = dfi_rddata_en_arr[0];
  assign dfi_ctrlupd_req_o    = dfi_ctrlupd_req_arr[0];
  assign dfi_phyupd_ack_o     = dfi_phyupd_ack_arr[0];
  assign dfi_lp_ctrl_req_o    = dfi_lp_ctrl_req_arr[0];
  assign dfi_lp_ctrl_wakeup_o = dfi_lp_ctrl_wakeup_arr[0];
  assign dfi_lp_data_req_o    = dfi_lp_data_req_arr[0];

  assign dfi_ctrlupd_ack_arr[0] = dfi_ctrlupd_ack_i;
  assign dfi_phyupd_req_arr[0]    = dfi_phyupd_req_i;
  assign dfi_wrdata_ack_arr[0]    = dfi_wrdata_ack_i;
  assign dfi_rddata_arr[0]        = dfi_rddata_i;
  assign dfi_rddata_valid_arr[0]  = dfi_rddata_valid_i;
  assign dfi_lp_ctrl_ack_arr[0]   = dfi_lp_ctrl_ack_i;
  assign dfi_lp_data_ack_arr[0]   = dfi_lp_data_ack_i;

  hbm4_ctrl #(
      .NUM_CHANNELS(1)
  ) dut (
      .clk_i              (clk_i),
      .rst_ni             (rst_ni),
      .awid_i             (awid_arr),
      .awaddr_i           (awaddr_arr),
      .awlen_i            (awlen_arr),
      .awsize_i           (awsize_arr),
      .awburst_i          (awburst_arr),
      .awvalid_i          (awvalid_arr),
      .awready_o          (awready_arr),
      .wdata_i            (wdata_arr),
      .wstrb_i            (wstrb_arr),
      .wlast_i            (wlast_arr),
      .wvalid_i           (wvalid_arr),
      .wready_o           (wready_arr),
      .bid_o              (bid_arr),
      .bresp_o            (bresp_arr),
      .bvalid_o           (bvalid_arr),
      .bready_i           (bready_arr),
      .arid_i             (arid_arr),
      .araddr_i           (araddr_arr),
      .arlen_i            (arlen_arr),
      .arsize_i           (arsize_arr),
      .arburst_i          (arburst_arr),
      .arvalid_i          (arvalid_arr),
      .arready_o          (arready_arr),
      .rid_o              (rid_arr),
      .rdata_o            (rdata_arr),
      .rresp_o            (rresp_arr),
      .rlast_o            (rlast_arr),
      .rvalid_o           (rvalid_arr),
      .rready_i           (rready_arr),
      .cmd_valid_o        (cmd_valid_arr),
      .cmd_o              (cmd_arr),
      .cmd_bank_o         (cmd_bank_arr),
      .cmd_row_o          (cmd_row_arr),
      .cmd_col_o          (cmd_col_arr),
      .drfm_req_o           (drfm_req_arr),
      .drfm_ack_i           (drfm_ack_arr),
      .fpv_bank0_state_o    (fpv_bank0_state_o),
      .fpv_bank0_ras_cnt_o  (fpv_bank0_ras_cnt_o),
      .dfi_address_o        (dfi_address_arr),
      .dfi_ras_n_o          (dfi_ras_n_arr),
      .dfi_cas_n_o          (dfi_cas_n_arr),
      .dfi_we_n_o           (dfi_we_n_arr),
      .dfi_bank_group_o     (dfi_bank_group_arr),
      .dfi_bank_o           (dfi_bank_arr),
      .dfi_cs_n_o           (dfi_cs_n_arr),
      .dfi_cke_o            (dfi_cke_arr),
      .dfi_reset_n_o        (dfi_reset_n_arr),
      .dfi_wrdata_o         (dfi_wrdata_arr),
      .dfi_wrdata_mask_o    (dfi_wrdata_mask_arr),
      .dfi_wrdata_en_o      (dfi_wrdata_en_arr),
      .dfi_wrdata_ack_i     (dfi_wrdata_ack_arr),
      .dfi_rddata_i         (dfi_rddata_arr),
      .dfi_rddata_valid_i   (dfi_rddata_valid_arr),
      .dfi_rddata_en_o      (dfi_rddata_en_arr),
      .dfi_ctrlupd_req_o    (dfi_ctrlupd_req_arr),
      .dfi_ctrlupd_ack_i    (dfi_ctrlupd_ack_arr),
      .dfi_phyupd_req_i     (dfi_phyupd_req_arr),
      .dfi_phyupd_ack_o     (dfi_phyupd_ack_arr),
      .dfi_lp_ctrl_req_o    (dfi_lp_ctrl_req_arr),
      .dfi_lp_ctrl_wakeup_o (dfi_lp_ctrl_wakeup_arr),
      .dfi_lp_ctrl_ack_i    (dfi_lp_ctrl_ack_arr),
      .dfi_lp_data_req_o    (dfi_lp_data_req_arr),
      .dfi_lp_data_ack_i    (dfi_lp_data_ack_arr),
      .pwrdn_req_i          (pwrdn_req_arr),
      .sref_req_i           (sref_req_arr),
      .exit_req_i           (exit_req_arr),
      .pw_state_o           (pw_state_arr)
  );

  assign pw_state_o = pw_state_arr[0];

  hbm4_ctrl_abs u_abs (
      .clk_i               (clk_i),
      .rst_ni              (rst_ni),
      .awvalid_i           (awvalid_i),
      .awaddr_i            (awaddr_i),
      .arvalid_i           (arvalid_i),
      .drfm_ack_i          (drfm_ack_i),
      .dfi_ctrlupd_req_i   (dfi_ctrlupd_req_o),
      .dfi_ctrlupd_ack_i   (dfi_ctrlupd_ack_i),
      .dfi_phyupd_req_i    (dfi_phyupd_req_i),
      .dfi_lp_ctrl_req_i   (dfi_lp_ctrl_req_o),
      .dfi_lp_ctrl_ack_i   (dfi_lp_ctrl_ack_i),
      .pwrdn_req_i         (pwrdn_req_i),
      .sref_req_i          (sref_req_i),
      .exit_req_i          (exit_req_i)
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

  property p_ctrlupd_hold;
    @(posedge clk_i) disable iff (!rst_ni)
    (dut.g_channel[0].u_chan.u_dfi.dfi_ctrlupd_req_o &&
     !dut.g_channel[0].u_chan.u_dfi.dfi_ctrlupd_ack_i) |=>
    dut.g_channel[0].u_chan.u_dfi.dfi_ctrlupd_req_o;
  endproperty
  ap_ctrlupd_hold: assert property (p_ctrlupd_hold);

  property p_no_cmd_ctrlupd;
    @(posedge clk_i) disable iff (!rst_ni)
    (dut.g_channel[0].u_chan.u_dfi.dfi_ctrlupd_req_o &&
     dut.g_channel[0].u_chan.u_dfi.dfi_ctrlupd_ack_i) |->
    dut.g_channel[0].u_chan.u_dfi.dfi_cs_n_o;
  endproperty
  ap_no_cmd_ctrlupd: assert property (p_no_cmd_ctrlupd);

  property p_phyupd_gated;
    @(posedge clk_i) disable iff (!rst_ni)
    dut.g_channel[0].u_chan.u_dfi.dfi_phyupd_ack_o |->
    dut.g_channel[0].u_chan.u_dfi.dfi_phyupd_req_i;
  endproperty
  ap_phyupd_gated: assert property (p_phyupd_gated);

  property p4_inhibit_only_in_lp;
    @(posedge clk_i) disable iff (!rst_ni)
    dut.g_channel[0].u_chan.u_pwrdn.inhibit_cmds_o |->
      (dut.g_channel[0].u_chan.u_pwrdn.pw_state_o != CHAN_ACTIVE) ||
      (dut.g_channel[0].u_chan.u_pwrdn.timer_q != '0);
  endproperty
  P4F1_inhibit: assert property (p4_inhibit_only_in_lp);

  property p4_cke_deassert_after_idle;
    @(posedge clk_i) disable iff (!rst_ni)
    $fell(dut.g_channel[0].u_chan.u_pwrdn.cke_req_o) |->
      $past(&dut.g_channel[0].u_chan.u_pwrdn.bank_idle_i, 1);
  endproperty
  P4F2_cke_after_idle: assert property (p4_cke_deassert_after_idle);

  property p4_no_cmd_cke_low;
    @(posedge clk_i) disable iff (!rst_ni)
    !dut.g_channel[0].u_chan.u_pwrdn.cke_req_o |->
      dut.g_channel[0].u_chan.u_dfi.dfi_cs_n_o;
  endproperty
  P4F3_no_cmd_cke_low: assert property (p4_no_cmd_cke_low);

  property p4_txsr_respected;
    @(posedge clk_i) disable iff (!rst_ni)
    $rose(dut.g_channel[0].u_chan.u_pwrdn.pw_state_o == CHAN_SREF_EXIT) |->
      ##[T_XSR:T_XSR+5] !dut.g_channel[0].u_chan.u_pwrdn.inhibit_cmds_o;
  endproperty
  P4F4_txsr: assert property (p4_txsr_respected);

endmodule : hbm4_ctrl_fpv_wrapper

`default_nettype wire
