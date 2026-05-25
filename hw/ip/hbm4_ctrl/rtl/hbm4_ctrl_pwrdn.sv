// Copyright 2026 The Netie Open HBM Authors
// SPDX-License-Identifier: Apache-2.0
//
// Per-channel power-down / self-refresh FSM with DFI LP handshake.
`default_nettype none
`timescale 1ns/1ps

module hbm4_ctrl_pwrdn
  import hbm4_ctrl_pkg::*;
#(
  parameter int unsigned NUM_BANKS = 16
) (
  input  logic              clk_i,
  input  logic              rst_ni,

  input  logic [NUM_BANKS-1:0] bank_idle_i,

  input  logic              pwrdn_req_i,
  input  logic              sref_req_i,
  input  logic              exit_req_i,

  output logic              dfi_lp_ctrl_req_o,
  output logic [3:0]        dfi_lp_ctrl_wakeup_o,
  input  logic              dfi_lp_ctrl_ack_i,

  output logic              inhibit_cmds_o,
  output logic              cke_req_o,

  output hbm4_ctrl_pkg::chan_pw_state_e pw_state_o
);

  chan_pw_state_e pw_state_q;
  chan_pw_state_e pw_state_d;
  logic           lp_req_q;
  logic           lp_req_d;
  logic           cke_q;
  logic           cke_d;
  logic           inhibit_q;
  logic           inhibit_d;
  logic [7:0]     timer_q;
  logic [7:0]     timer_d;
  logic           all_idle;

  assign all_idle              = &bank_idle_i;
  assign dfi_lp_ctrl_wakeup_o  = 4'h5;
  assign dfi_lp_ctrl_req_o     = lp_req_q;
  assign inhibit_cmds_o        = inhibit_q;
  assign cke_req_o             = cke_q;
  assign pw_state_o            = pw_state_q;

  always_comb begin : g_next_state
    pw_state_d = pw_state_q;
    unique case (pw_state_q)
      CHAN_ACTIVE: begin
        if (all_idle && pwrdn_req_i) begin
          pw_state_d = CHAN_PD;
        end else if (all_idle && sref_req_i) begin
          pw_state_d = CHAN_SREF;
        end
      end
      CHAN_PD: begin
        if (exit_req_i) begin
          pw_state_d = CHAN_ACTIVE;
        end
      end
      CHAN_SREF: begin
        if (exit_req_i) begin
          pw_state_d = CHAN_SREF_EXIT;
        end
      end
      CHAN_SREF_EXIT: begin
        if (timer_q == '0) begin
          pw_state_d = CHAN_ACTIVE;
        end
      end
      default: pw_state_d = CHAN_ACTIVE;
    endcase
  end

  always_comb begin : g_seq_next
    lp_req_d    = lp_req_q;
    cke_d       = cke_q;
    inhibit_d   = inhibit_q;
    timer_d     = timer_q;

    unique case (pw_state_q)
      CHAN_ACTIVE: begin
        if (all_idle && pwrdn_req_i) begin
          lp_req_d    = 1'b1;
          inhibit_d   = 1'b1;
        end else if (all_idle && sref_req_i) begin
          lp_req_d    = 1'b1;
          inhibit_d   = 1'b1;
        end else if (inhibit_q && (timer_q != '0)) begin
          timer_d     = timer_q - 8'd1;
        end else if (inhibit_q && (timer_q == '0)) begin
          inhibit_d   = 1'b0;
        end
      end
      CHAN_PD: begin
        if (dfi_lp_ctrl_ack_i) begin
          cke_d = 1'b0;
        end
        if (exit_req_i) begin
          lp_req_d    = 1'b0;
          cke_d       = 1'b1;
          timer_d     = T_XPDLL[7:0];
          inhibit_d   = 1'b1;
        end
      end
      CHAN_SREF: begin
        if (dfi_lp_ctrl_ack_i) begin
          cke_d = 1'b0;
        end
        if (exit_req_i) begin
          lp_req_d  = 1'b0;
          cke_d     = 1'b1;
          timer_d   = T_XSR[7:0];
          inhibit_d = 1'b1;
        end
      end
      CHAN_SREF_EXIT: begin
        if (timer_q != '0) begin
          timer_d = timer_q - 8'd1;
        end else begin
          inhibit_d = 1'b0;
        end
      end
      default: ;
    endcase
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin : g_regs
    if (!rst_ni) begin
      pw_state_q <= CHAN_ACTIVE;
      lp_req_q   <= 1'b0;
      cke_q      <= 1'b1;
      inhibit_q  <= 1'b0;
      timer_q    <= '0;
    end else begin
      pw_state_q <= pw_state_d;
      lp_req_q   <= lp_req_d;
      cke_q      <= cke_d;
      inhibit_q  <= inhibit_d;
      timer_q    <= timer_d;
    end
  end

endmodule : hbm4_ctrl_pwrdn

`default_nettype wire
