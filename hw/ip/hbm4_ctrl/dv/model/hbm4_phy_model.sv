// Copyright 2026 The Netie Open HBM Authors
// SPDX-License-Identifier: Apache-2.0
//
// Simulation-only behavioural PHY: DFI 5.0 decode + training ack (P9).
`default_nettype none
`timescale 1ns/1ps

module hbm4_phy_model #(
    parameter bit          PHY_MODEL_EN = 1'b1,
    parameter int unsigned DQ_WIDTH     = 128,
    parameter int unsigned ADDR_W       = 10,
    parameter int unsigned BG_W         = 2,
    parameter int unsigned BANK_W       = 2,
    parameter int unsigned NUM_BANKS    = 16
) (
    input  logic                  dfi_clk_i,
    input  logic                  dfi_rst_ni,

    input  logic                  dfi_cs_n_i,
    input  logic                  dfi_cke_i,
    input  logic                  dfi_ras_n_i,
    input  logic                  dfi_cas_n_i,
    input  logic                  dfi_we_n_i,
    input  logic [ADDR_W-1:0]     dfi_address_i,
    input  logic [BG_W-1:0]       dfi_bank_group_i,
    input  logic [BANK_W-1:0]     dfi_bank_i,
    input  logic [DQ_WIDTH-1:0]   dfi_wrdata_i,
    input  logic [DQ_WIDTH/8-1:0] dfi_wrdata_mask_i,
    input  logic                  dfi_wrdata_en_i,
    output logic                  dfi_wrdata_ack_o,
    input  logic                  dfi_rddata_en_i,
    input  logic                  dfi_wrlvl_req_i,
    input  logic                  dfi_rdlvl_req_i,
    output logic                  dfi_wrlvl_ack_o,
    output logic                  dfi_rdlvl_ack_o,

    output logic                  phy_cmd_valid_o,
    output logic [3:0]            phy_cmd_bank_o,
    output logic [15:0]           phy_cmd_row_o,
    output logic [9:0]            phy_cmd_col_o,
    output logic                  phy_cmd_is_write_o,
    output logic [DQ_WIDTH-1:0]   phy_wdata_o,
    output logic [DQ_WIDTH/8-1:0] phy_wstrb_o,
    input  logic [DQ_WIDTH-1:0]   phy_rdata_i,
    input  logic                  phy_rdata_valid_i,

    output logic [DQ_WIDTH-1:0]   dfi_rddata_o,
    output logic                  dfi_rddata_valid_o
);

  if (!PHY_MODEL_EN) begin : g_disabled
    assign dfi_wrdata_ack_o   = 1'b0;
    assign dfi_wrlvl_ack_o    = 1'b0;
    assign dfi_rdlvl_ack_o    = 1'b0;
    assign phy_cmd_valid_o    = 1'b0;
    assign phy_cmd_is_write_o = 1'b0;
    assign phy_cmd_bank_o     = '0;
    assign phy_cmd_row_o      = '0;
    assign phy_cmd_col_o      = '0;
    assign phy_wdata_o        = '0;
    assign phy_wstrb_o        = '0;
    assign dfi_rddata_o       = '0;
    assign dfi_rddata_valid_o = 1'b0;
  end else begin : g_enabled

    logic [9:0]  wrlvl_ack_sr_q;
    logic [9:0]  rdlvl_ack_sr_q;
    logic [3:0]  decoded_bank;
    logic [15:0] decoded_row;
    logic [9:0]  decoded_col;
    logic        is_act;
    logic        is_rd;
    logic        is_wr;
    logic [15:0] open_row_q [NUM_BANKS-1:0];

    assign dfi_wrdata_ack_o = dfi_wrdata_en_i;

    always_comb begin
      decoded_bank = {dfi_bank_group_i, dfi_bank_i};
      is_act       = !dfi_cs_n_i && dfi_cke_i && !dfi_ras_n_i &&  dfi_cas_n_i &&  dfi_we_n_i;
      is_rd        = !dfi_cs_n_i && dfi_cke_i &&  dfi_ras_n_i && !dfi_cas_n_i &&  dfi_we_n_i;
      is_wr        = !dfi_cs_n_i && dfi_cke_i &&  dfi_ras_n_i && !dfi_cas_n_i && !dfi_we_n_i;
      decoded_row  = {6'b0, dfi_address_i};
      decoded_col  = {4'b0, dfi_address_i};
    end

    always_ff @(posedge dfi_clk_i or negedge dfi_rst_ni) begin
      if (!dfi_rst_ni) begin
        wrlvl_ack_sr_q       <= '0;
        rdlvl_ack_sr_q       <= '0;
        phy_cmd_valid_o      <= 1'b0;
        phy_cmd_is_write_o   <= 1'b0;
        phy_cmd_bank_o       <= '0;
        phy_cmd_row_o        <= '0;
        phy_cmd_col_o        <= '0;
        phy_wdata_o          <= '0;
        phy_wstrb_o          <= '0;
        dfi_rddata_o         <= '0;
        dfi_rddata_valid_o   <= 1'b0;
        for (int i = 0; i < NUM_BANKS; i++) begin
          open_row_q[i] <= '0;
        end
      end else begin
        wrlvl_ack_sr_q <= {wrlvl_ack_sr_q[8:0], dfi_wrlvl_req_i};
        rdlvl_ack_sr_q <= {rdlvl_ack_sr_q[8:0], dfi_rdlvl_req_i};

        if (is_act) begin
          open_row_q[decoded_bank] <= decoded_row;
        end

        phy_cmd_valid_o    <= is_rd || is_wr;
        phy_cmd_is_write_o <= is_wr;
        phy_cmd_bank_o     <= decoded_bank;
        phy_cmd_row_o      <= open_row_q[decoded_bank];
        phy_cmd_col_o      <= decoded_col;

        if (is_wr && dfi_wrdata_en_i) begin
          phy_wdata_o <= dfi_wrdata_i;
          phy_wstrb_o <= ~dfi_wrdata_mask_i;
        end else begin
          phy_wdata_o <= '0;
          phy_wstrb_o <= '0;
        end

        dfi_rddata_o       <= phy_rdata_i;
        dfi_rddata_valid_o <= phy_rdata_valid_i;
      end
    end

    assign dfi_wrlvl_ack_o = wrlvl_ack_sr_q[9];
    assign dfi_rdlvl_ack_o = rdlvl_ack_sr_q[9];

  end

endmodule : hbm4_phy_model

`default_nettype wire
