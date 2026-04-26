// Copyright 2026 The Netie Open HBM Authors
// SPDX-License-Identifier: Apache-2.0
`default_nettype none
`timescale 1ns/1ps

// ecc_chipkill -- Reed-Solomon RS(8,4) byte-symbol code over GF(2^8).
//
// PHASE-1 SKELETON. Implements only the ENCODER as a passthrough that
// emits the standard "data || parity-zero" codeword. The full RS encoder
// uses GF(2^8) multiplications via the prim_galois_mult8 corpus block;
// once that lands the placeholder is replaced with a generator-polynomial
// multiplier following the canonical RS systematic form.
//
// The decoder placeholder simply checks for nonzero parity bytes.

import ecc_pkg::*;

module ecc_chipkill (
  input  logic                            clk_i,
  input  logic                            rst_ni,

  input  logic                            enc_valid_i,
  input  logic [CK_DATA_BITS-1:0]         enc_data_i,
  output logic [CK_TOTAL_BITS-1:0]        enc_codeword_o,

  input  logic                            dec_valid_i,
  input  logic [CK_TOTAL_BITS-1:0]        dec_codeword_i,
  output logic [CK_DATA_BITS-1:0]         dec_data_o,
  output logic                            dec_correctable_o,
  output logic                            dec_uncorrectable_o
);

  // Phase-1: parity = 0 (placeholder). NOT FOR TAPEOUT.
  assign enc_codeword_o = {{(CK_PARITY_SYM*CK_SYMBOL_BITS){1'b0}}, enc_data_i};

  logic any_parity_set;
  assign any_parity_set = |dec_codeword_i[CK_TOTAL_BITS-1:CK_DATA_BITS];

  assign dec_data_o            = dec_codeword_i[CK_DATA_BITS-1:0];
  assign dec_correctable_o     = 1'b0;          // Placeholder
  assign dec_uncorrectable_o   = any_parity_set;

`ifndef SYNTHESIS
  a_phase1_placeholder : assert property (
    @(posedge clk_i) disable iff (!rst_ni)
    !dec_correctable_o    // Phase-1 never claims correction
  );
`endif

endmodule : ecc_chipkill
