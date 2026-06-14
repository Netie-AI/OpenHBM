// Copyright 2026 The Netie Open HBM Authors
// SPDX-License-Identifier: Apache-2.0
//
// ecc_encode -- RS(18,16) systematic parity over GF(2^8), poly 0x11D.
`default_nettype none
`timescale 1ns/1ps

module ecc_encode (
    input logic [127:0] data_i,
    output logic [15:0] ecc_o
);
  import ecc_pkg::*;

  logic [7:0] r1, r2, p0, p1;

  always_comb begin
    msg_syndromes(data_i, r1, r2);
    solve_parity(r1, r2, p0, p1);
    ecc_o = {p1, p0};
  end
endmodule : ecc_encode

`default_nettype wire
