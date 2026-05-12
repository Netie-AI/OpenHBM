// Copyright 2026 The Netie Open HBM Authors
// SPDX-License-Identifier: Apache-2.0
`default_nettype none
`timescale 1ns/1ps

package ecc_pkg;

  typedef enum logic [1:0] {
    ECC_NONE      = 2'h0,
    ECC_SECDED    = 2'h1,
    ECC_CHIPKILL  = 2'h2,
    ECC_RESERVED  = 2'h3
  } ecc_class_e;

  // SEC-DED is (72, 64) Hsiao.
  parameter int unsigned SECDED_K = 64;
  parameter int unsigned SECDED_M = 8;
  parameter int unsigned SECDED_N = SECDED_K + SECDED_M;

  // Chipkill is RS(8, 4) over GF(2^8): 8-symbol codeword, 4 data symbols,
  // tolerates one whole-symbol failure.
  parameter int unsigned CK_SYMBOL_BITS = 8;
  parameter int unsigned CK_DATA_SYM    = 4;
  parameter int unsigned CK_PARITY_SYM  = 4;
  parameter int unsigned CK_TOTAL_SYM   = CK_DATA_SYM + CK_PARITY_SYM;
  parameter int unsigned CK_DATA_BITS   = CK_DATA_SYM   * CK_SYMBOL_BITS;
  parameter int unsigned CK_TOTAL_BITS  = CK_TOTAL_SYM  * CK_SYMBOL_BITS;

endpackage : ecc_pkg
