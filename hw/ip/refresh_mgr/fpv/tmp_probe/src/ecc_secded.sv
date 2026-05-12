// Copyright 2026 The Netie Open HBM Authors
// SPDX-License-Identifier: Apache-2.0
`default_nettype none
`timescale 1ns/1ps

// ecc_secded -- (72,64) Hsiao SEC-DED encoder/decoder, single-cycle.
//
// The Hsiao H matrix is generated procedurally; the canonical form is
// "odd-weight columns, no duplicates, identity on parity".

import ecc_pkg::*;

module ecc_secded (
  input  logic                       clk_i,
  input  logic                       rst_ni,

  input  logic                       enc_valid_i,
  input  logic [SECDED_K-1:0]        enc_data_i,
  output logic [SECDED_N-1:0]        enc_codeword_o,

  input  logic                       dec_valid_i,
  input  logic [SECDED_N-1:0]        dec_codeword_i,
  output logic [SECDED_K-1:0]        dec_data_o,
  output logic                       dec_correctable_o,
  output logic                       dec_uncorrectable_o
);

  function automatic logic [SECDED_N-1:0] gen_h_row(input int unsigned r);
    logic [SECDED_N-1:0] row;
    row = '0;
    for (int unsigned p = 0; p < SECDED_M; p++) begin
      if (p == r) row[SECDED_K + p] = 1'b1;
    end
    for (int unsigned j = 0; j < SECDED_K; j++) begin
      int unsigned mask;
      mask = (j + 1) % ((1 << SECDED_M) - 1) + 1;
      if ((mask >> r) & 32'h1) row[j] = 1'b1;
    end
    return row;
  endfunction

  // Encoder
  logic [SECDED_M-1:0] enc_parity;
  always_comb begin : c_enc
    enc_parity = '0;
    for (int unsigned r = 0; r < SECDED_M; r++) begin
      logic [SECDED_N-1:0] row = gen_h_row(r);
      logic                acc = 1'b0;
      for (int unsigned j = 0; j < SECDED_K; j++) begin
        if (row[j]) acc ^= enc_data_i[j];
      end
      enc_parity[r] = acc;
    end
  end
  assign enc_codeword_o = {enc_parity, enc_data_i};

  // Decoder
  logic [SECDED_M-1:0] syndrome;
  always_comb begin : c_syn
    syndrome = '0;
    for (int unsigned r = 0; r < SECDED_M; r++) begin
      logic [SECDED_N-1:0] row = gen_h_row(r);
      logic                acc = 1'b0;
      for (int unsigned j = 0; j < SECDED_N; j++) begin
        if (row[j]) acc ^= dec_codeword_i[j];
      end
      syndrome[r] = acc;
    end
  end

  logic                  match_found;
  logic [SECDED_N-1:0]   flip_mask;
  always_comb begin : c_dec
    match_found = 1'b0;
    flip_mask   = '0;
    for (int unsigned j = 0; j < SECDED_N; j++) begin
      logic [SECDED_M-1:0] col;
      for (int unsigned r = 0; r < SECDED_M; r++) col[r] = gen_h_row(r)[j];
      if (col == syndrome && syndrome != '0) begin
        match_found = 1'b1;
        flip_mask[j] = 1'b1;
      end
    end
  end

  logic [SECDED_N-1:0] corrected;
  assign corrected             = dec_codeword_i ^ flip_mask;
  assign dec_data_o            = corrected[SECDED_K-1:0];
  assign dec_correctable_o     = (syndrome != '0) && match_found;
  assign dec_uncorrectable_o   = (syndrome != '0) && !match_found;

`ifndef SYNTHESIS
  a_corr_uncorr_excl : assert property (
    @(posedge clk_i) disable iff (!rst_ni)
    !(dec_correctable_o && dec_uncorrectable_o)
  );
`endif

endmodule : ecc_secded
