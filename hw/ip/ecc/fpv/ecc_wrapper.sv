// Copyright 2026 The Netie Open HBM Authors
// SPDX-License-Identifier: Apache-2.0
//
// Formal wrapper (bounded): encoder parity zeros the RS syndromes on di==0.
// Exhaustive decode is verified in cocotb (see dv/tests/test_ecc.py).
`default_nettype none
`timescale 1ns/1ps

module ecc_wrapper;
  import ecc_pkg::*;

  logic [127:0] di;
  logic [15:0] pe;
  logic [7:0] s1;
  logic [7:0] s2;

  ecc_encode u_enc (
      .data_i(di),
      .ecc_o(pe)
  );

  always_comb begin
    cw_syndromes(di, pe, s1, s2);
  end

  always_comb begin
    assume (di == 128'h0);
  end

  always_comb begin
    assert (s1 == 8'h0);
    assert (s2 == 8'h0);
  end

endmodule : ecc_wrapper

`default_nettype wire
