// Copyright 2026 The Netie Open HBM Authors
// SPDX-License-Identifier: Apache-2.0
//
// Maps internal cmd_e bus to DFI 5.0 CA / data / update handshakes (one per channel).
`default_nettype none
`timescale 1ns/1ps

module hbm4_ctrl_dfi_bridge #(
    parameter int unsigned NUM_BANKS   = hbm4_ctrl_pkg::NUM_BANKS,
    parameter int unsigned BANKS_PER_BG = hbm4_ctrl_pkg::BANKS_PER_BG,
    parameter int unsigned ROW_W       = hbm4_ctrl_pkg::ROW_W,
    parameter int unsigned COL_W       = hbm4_ctrl_pkg::COL_W
) (
    input  logic clk_i,
    input  logic rst_ni,

    input  logic                          cmd_valid_i,
    input  hbm4_ctrl_pkg::cmd_e           cmd_i,
    input  logic [ROW_W-1:0]              cmd_row_i,
    input  logic [COL_W-1:0]              cmd_col_i,
    input  hbm4_ctrl_pkg::bank_addr_t     cmd_bank_i,
    output logic                          cmd_accepted_o,

    output logic [hbm4_ctrl_dfi_pkg::DFI_ADDR_W-1:0]   dfi_address_o,
    output logic                          dfi_ras_n_o,
    output logic                          dfi_cas_n_o,
    output logic                          dfi_we_n_o,
    output logic [hbm4_ctrl_dfi_pkg::DFI_BG_W-1:0]   dfi_bank_group_o,
    output logic [hbm4_ctrl_dfi_pkg::DFI_BANK_W-1:0] dfi_bank_o,
    output logic                          dfi_cs_n_o,
    output logic                          dfi_cke_o,
    output logic                          dfi_reset_n_o,

    output logic [hbm4_ctrl_dfi_pkg::DFI_DATA_W-1:0]         dfi_wrdata_o,
    output logic [hbm4_ctrl_dfi_pkg::DFI_DATA_W/8-1:0]       dfi_wrdata_mask_o,
    output logic                          dfi_wrdata_en_o,
    input  logic                          dfi_wrdata_ack_i,

    input  logic [hbm4_ctrl_dfi_pkg::DFI_DATA_W-1:0] dfi_rddata_i,
    input  logic                          dfi_rddata_valid_i,
    output logic                          dfi_rddata_en_o,

    output logic                          dfi_ctrlupd_req_o,
    input  logic                          dfi_ctrlupd_ack_i,
    input  logic                          dfi_phyupd_req_i,
    output logic                          dfi_phyupd_ack_o,

    output logic                          dfi_lp_ctrl_req_o,
    output logic [3:0]                    dfi_lp_ctrl_wakeup_o,
    input  logic                          dfi_lp_ctrl_ack_i,
    output logic                          dfi_lp_data_req_o,
    input  logic                          dfi_lp_data_ack_i,

    input  logic                          inhibit_cmds_i,
    input  logic                          cke_req_i
);

  import hbm4_ctrl_pkg::*;
  import hbm4_ctrl_dfi_pkg::*;

  localparam int unsigned BankIdxW = $clog2(NUM_BANKS);
  localparam int unsigned BgIdxW   = $clog2(BANKS_PER_BG);

  logic ctrlupd_inhibit;

  assign ctrlupd_inhibit = dfi_ctrlupd_req_o && dfi_ctrlupd_ack_i;

  always_comb begin : g_cmd_enc
    dfi_ras_n_o       = 1'b1;
    dfi_cas_n_o       = 1'b1;
    dfi_we_n_o        = 1'b1;
    dfi_cs_n_o        = 1'b1;
    dfi_address_o     = '0;
    dfi_bank_group_o  = cmd_bank_i[BankIdxW-1 : BgIdxW];
    dfi_bank_o        = cmd_bank_i[BgIdxW-1 : 0];
    dfi_rddata_en_o   = 1'b0;
    dfi_wrdata_en_o   = 1'b0;
    dfi_wrdata_mask_o = '0;
    dfi_wrdata_o      = '0;

    if (cmd_valid_i && !inhibit_cmds_i && !ctrlupd_inhibit) begin
      dfi_cs_n_o = 1'b0;
      unique case (cmd_i)
        ACT: begin
          dfi_ras_n_o   = 1'b0;
          dfi_address_o = DFI_ADDR_W'(cmd_row_i);
        end
        RD: begin
          dfi_cas_n_o     = 1'b0;
          dfi_address_o   = DFI_ADDR_W'(cmd_col_i);
          dfi_rddata_en_o = 1'b1;
        end
        WR: begin
          dfi_cas_n_o       = 1'b0;
          dfi_we_n_o        = 1'b0;
          dfi_address_o     = DFI_ADDR_W'(cmd_col_i);
          dfi_wrdata_en_o   = 1'b1;
          dfi_wrdata_mask_o = '0;
        end
        PRE: begin
          dfi_ras_n_o = 1'b0;
          dfi_we_n_o  = 1'b0;
        end
        REF: begin
          dfi_ras_n_o = 1'b0;
          dfi_cas_n_o = 1'b0;
        end
        default: ;
      endcase
    end
  end

  // Same-cycle accept while PHY backpressure is stubbed (P9 may register this).
  assign cmd_accepted_o = cmd_valid_i && !inhibit_cmds_i && !ctrlupd_inhibit;

  logic [11:0]        upd_timer_q;
  dfi_upd_state_e     upd_state_q;

  assign dfi_lp_ctrl_req_o    = 1'b0;
  assign dfi_lp_ctrl_wakeup_o = 4'h5;
  assign dfi_lp_data_req_o    = 1'b0;

  always_ff @(posedge clk_i or negedge rst_ni) begin : g_dfi_upd
    if (!rst_ni) begin
      upd_state_q       <= DFI_UPD_IDLE;
      upd_timer_q       <= '0;
      dfi_ctrlupd_req_o <= 1'b0;
      dfi_phyupd_ack_o  <= 1'b0;
      dfi_cke_o         <= 1'b0;
      dfi_reset_n_o     <= 1'b0;
    end else begin
      dfi_reset_n_o    <= 1'b1;
      dfi_cke_o        <= cke_req_i;
      upd_timer_q      <= upd_timer_q + 12'd1;
      dfi_phyupd_ack_o <= dfi_phyupd_req_i;

      unique case (upd_state_q)
        DFI_UPD_IDLE: begin
          if (upd_timer_q == 12'hFFF) begin
            upd_state_q       <= DFI_UPD_REQ;
            dfi_ctrlupd_req_o <= 1'b1;
          end
        end
        DFI_UPD_REQ: begin
          if (dfi_ctrlupd_ack_i) begin
            upd_state_q <= DFI_UPD_ACTIVE;
          end
        end
        DFI_UPD_ACTIVE: begin
          if (!dfi_ctrlupd_ack_i) begin
            dfi_ctrlupd_req_o <= 1'b0;
            upd_state_q       <= DFI_UPD_IDLE;
            upd_timer_q       <= '0;
          end
        end
        default: upd_state_q <= DFI_UPD_IDLE;
      endcase
    end
  end

  // Unused in stub (PHY model in P9); silence lint on inputs.
  logic unused_rdata;
  always_comb begin
    unused_rdata = |dfi_rddata_i | dfi_rddata_valid_i | dfi_wrdata_ack_i |
                   dfi_lp_ctrl_ack_i | dfi_lp_data_ack_i;
  end

endmodule : hbm4_ctrl_dfi_bridge

`default_nettype wire
