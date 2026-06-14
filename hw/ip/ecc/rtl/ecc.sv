// Copyright 2026 The Netie Open HBM Authors
// SPDX-License-Identifier: Apache-2.0
//
// ecc -- integrated ChipKill-style RS encode + decode (registered outputs).
`default_nettype none
`timescale 1ns/1ps

module ecc (
    input logic clk_i,
    input logic rst_ni,
    input logic [127:0] data_i,
    input logic [15:0] ecc_i,
    output logic [127:0] data_o,
    output logic [15:0] ecc_o,
    output logic [15:0] syndrome_o,
    output logic ce_o,
    output logic ue_o
);
  logic [15:0] enc_ecc;
  logic [127:0] dec_data;
  logic [15:0] dec_syn;
  logic dec_ce;
  logic dec_ue;

  logic [127:0] din_r;
  logic [15:0] ecc_r;

  ecc_encode u_enc (
      .data_i(din_r),
      .ecc_o (enc_ecc)
  );

  ecc_decode u_dec (
      .data_i    (din_r),
      .ecc_i     (ecc_r),
      .data_o    (dec_data),
      .syndrome_o(dec_syn),
      .ce_o      (dec_ce),
      .ue_o      (dec_ue)
  );

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      din_r <= '0;
      ecc_r <= '0;
    end else begin
      din_r <= data_i;
      ecc_r <= ecc_i;
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      ecc_o      <= '0;
      data_o     <= '0;
      syndrome_o <= '0;
      ce_o       <= 1'b0;
      ue_o       <= 1'b0;
    end else begin
      ecc_o      <= enc_ecc;
      data_o     <= dec_data;
      syndrome_o <= dec_syn;
      ce_o       <= dec_ce;
      ue_o       <= dec_ue;
    end
  end
endmodule : ecc

`default_nettype wire
