// Copyright 2026 The Netie Open HBM Authors
// SPDX-License-Identifier: Apache-2.0
//
// Write-leveling / read-leveling training FSM with DFI handshake and traffic inhibit.
`default_nettype none
`timescale 1ns/1ps

module hbm4_ctrl_training
  import hbm4_ctrl_pkg::*;
(
  input  logic       clk_i,
  input  logic       rst_ni,

  input  logic       wrlvl_req_i,
  input  logic       rdlvl_req_i,

  output logic       dfi_wrlvl_req_o,
  output logic       dfi_rdlvl_req_o,
  input  logic       dfi_wrlvl_ack_i,
  input  logic       dfi_rdlvl_ack_i,

  output logic       inhibit_cmds_o,

  output logic       training_done_o,
  output logic       training_err_o,
  output hbm4_ctrl_pkg::train_state_e train_state_o
);

  train_state_e state_q;
  train_state_e state_d;
  logic [10:0]  timer_q;
  logic [10:0]  timer_d;
  logic         wrlvl_req_q;
  logic         wrlvl_req_d;
  logic         rdlvl_req_q;
  logic         rdlvl_req_d;
  logic         err_q;
  logic         err_d;

  assign train_state_o   = state_q;
  assign training_done_o = (state_q == TRAIN_DONE);
  assign inhibit_cmds_o  = (state_q == TRAIN_WRLVL) || (state_q == TRAIN_RDLVL);
  assign dfi_wrlvl_req_o = wrlvl_req_q;
  assign dfi_rdlvl_req_o = rdlvl_req_q;
  assign training_err_o  = err_q;

  always_comb begin : g_next
    state_d     = state_q;
    timer_d     = timer_q;
    wrlvl_req_d = wrlvl_req_q;
    rdlvl_req_d = rdlvl_req_q;
    err_d       = err_q;

    unique case (state_q)
      TRAIN_IDLE: begin
        wrlvl_req_d = 1'b0;
        rdlvl_req_d = 1'b0;
        if (wrlvl_req_i) begin
          state_d     = TRAIN_WRLVL;
          timer_d     = TRAIN_TIMEOUT[10:0];
          wrlvl_req_d = 1'b1;
          err_d       = 1'b0;
        end else if (rdlvl_req_i) begin
          state_d     = TRAIN_RDLVL;
          timer_d     = TRAIN_TIMEOUT[10:0];
          rdlvl_req_d = 1'b1;
          err_d       = 1'b0;
        end
      end
      TRAIN_WRLVL: begin
        wrlvl_req_d = 1'b1;
        if (timer_q == '0) begin
          state_d     = TRAIN_ERR;
          wrlvl_req_d = 1'b0;
          err_d       = 1'b1;
        end else if (dfi_wrlvl_ack_i) begin
          state_d     = TRAIN_DONE;
          wrlvl_req_d = 1'b0;
        end else begin
          timer_d = timer_q - 11'd1;
        end
      end
      TRAIN_RDLVL: begin
        rdlvl_req_d = 1'b1;
        if (timer_q == '0) begin
          state_d     = TRAIN_ERR;
          rdlvl_req_d = 1'b0;
          err_d       = 1'b1;
        end else if (dfi_rdlvl_ack_i) begin
          state_d     = TRAIN_DONE;
          rdlvl_req_d = 1'b0;
        end else begin
          timer_d = timer_q - 11'd1;
        end
      end
      TRAIN_DONE: begin
        state_d = TRAIN_IDLE;
      end
      TRAIN_ERR: begin
        wrlvl_req_d = 1'b0;
        rdlvl_req_d = 1'b0;
        if (wrlvl_req_i) begin
          state_d     = TRAIN_WRLVL;
          timer_d     = TRAIN_TIMEOUT[10:0];
          wrlvl_req_d = 1'b1;
          err_d       = 1'b0;
        end else if (rdlvl_req_i) begin
          state_d     = TRAIN_RDLVL;
          timer_d     = TRAIN_TIMEOUT[10:0];
          rdlvl_req_d = 1'b1;
          err_d       = 1'b0;
        end
      end
      default: state_d = TRAIN_IDLE;
    endcase
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin : g_seq
    if (!rst_ni) begin
      state_q     <= TRAIN_IDLE;
      timer_q     <= '0;
      wrlvl_req_q <= 1'b0;
      rdlvl_req_q <= 1'b0;
      err_q       <= 1'b0;
    end else begin
      state_q     <= state_d;
      timer_q     <= timer_d;
      wrlvl_req_q <= wrlvl_req_d;
      rdlvl_req_q <= rdlvl_req_d;
      err_q       <= err_d;
    end
  end

endmodule : hbm4_ctrl_training

`default_nettype wire
