// Copyright 2026 The Netie Open HBM Authors
// SPDX-License-Identifier: Apache-2.0
`default_nettype none
`timescale 1ns/1ps

// ecc -- top-level wrapper. Dispatches between SEC-DED and chipkill based
// on the ECC_CLASS parameter.

import ecc_pkg::*;

module ecc #(
  parameter ecc_class_e ECC_CLASS = ECC_SECDED
) (
  input  logic                            clk_i,
  input  logic                            rst_ni,

  input  logic                            valid_i,
  input  logic                            is_encode_i,
  input  logic [SECDED_K-1:0]             data_i,        // ECC_SECDED uses 64; chipkill uses lower 32
  input  logic [SECDED_N-1:0]             codeword_i,    // chipkill uses lower 64 of 72

  output logic [SECDED_N-1:0]             codeword_o,
  output logic [SECDED_K-1:0]             data_o,
  output logic                            correctable_o,
  output logic                            uncorrectable_o
);

  generate
    case (ECC_CLASS)
      ECC_SECDED: begin : g_secded
        ecc_secded u_secded (
          .clk_i, .rst_ni,
          .enc_valid_i      (valid_i & is_encode_i),
          .enc_data_i       (data_i),
          .enc_codeword_o   (codeword_o),
          .dec_valid_i      (valid_i & ~is_encode_i),
          .dec_codeword_i   (codeword_i),
          .dec_data_o       (data_o),
          .dec_correctable_o(correctable_o),
          .dec_uncorrectable_o(uncorrectable_o)
        );
      end
      ECC_CHIPKILL: begin : g_chipkill
        logic [CK_TOTAL_BITS-1:0] cw_in;
        logic [CK_TOTAL_BITS-1:0] cw_out;
        logic [CK_DATA_BITS-1:0]  d_out;
        assign cw_in = codeword_i[CK_TOTAL_BITS-1:0];
        ecc_chipkill u_ck (
          .clk_i, .rst_ni,
          .enc_valid_i      (valid_i & is_encode_i),
          .enc_data_i       (data_i[CK_DATA_BITS-1:0]),
          .enc_codeword_o   (cw_out),
          .dec_valid_i      (valid_i & ~is_encode_i),
          .dec_codeword_i   (cw_in),
          .dec_data_o       (d_out),
          .dec_correctable_o(correctable_o),
          .dec_uncorrectable_o(uncorrectable_o)
        );
        // Pad the wider output with zeros at the upper bits.
        assign codeword_o = {{(SECDED_N - CK_TOTAL_BITS){1'b0}}, cw_out};
        assign data_o     = {{(SECDED_K - CK_DATA_BITS){1'b0}}, d_out};
      end
      default: begin : g_none
        // ECC_NONE: identity. Codeword is data zero-extended.
        assign codeword_o      = {8'h0, data_i};
        assign data_o          = codeword_i[SECDED_K-1:0];
        assign correctable_o   = 1'b0;
        assign uncorrectable_o = 1'b0;
      end
    endcase
  endgenerate

endmodule : ecc
