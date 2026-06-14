// Copyright 2026 The Netie Open HBM Authors
// SPDX-License-Identifier: Apache-2.0
//
// ecc_pkg -- shared parameters and GF(2^8) helpers for ChipKill-style
// RS(18,16) systematic encoding (128-bit data + 16-bit parity, 8-bit symbols).
`default_nettype none
`timescale 1ns/1ps

package ecc_pkg;
  localparam int unsigned DataW  = 128;
  localparam int unsigned EccW  = 16;
  localparam int unsigned SymW  = 8;
  localparam int unsigned Nsym  = 18;  // 16 data + 2 parity
  localparam int unsigned Dsym  = 16;

`include "gf_tables.inc.sv"

  function automatic logic [7:0] gf_mul(input logic [7:0] a, input logic [7:0] b);
    logic [8:0] idx;
    if (a == 8'h0 || b == 8'h0) begin
      return 8'h0;
    end
    idx = 9'(GfLog[a]) + 9'(GfLog[b]);
    if (idx >= 9'd255) begin
      idx = idx - 9'd255;
    end
    return GfExp[9'(idx)];
  endfunction : gf_mul

  function automatic logic [7:0] gf_inv(input logic [7:0] a);
    return (a == 8'h0) ? 8'h0 : GfExp[9'(9'd255 - 9'(GfLog[a]))];
  endfunction : gf_inv

  function automatic void msg_syndromes(
      input logic [127:0] data_i,
      output logic [7:0]  r1,
      output logic [7:0]  r2
  );
    logic [7:0] di;
    r1 = 8'h0;
    r2 = 8'h0;
    for (int unsigned ii = 0; ii < 16; ii++) begin
      di = data_i[(7'(ii) * 7'd8) +: 8];
      r1 ^= gf_mul(di, GfExp[9'(ii)]);
      r2 ^= gf_mul(di, GfExp[9'(2 * ii)]);
    end
  endfunction : msg_syndromes

  function automatic void solve_parity(
      input logic [7:0] r1,
      input logic [7:0] r2,
      output logic [7:0] p0,
      output logic [7:0] p1
  );
    logic [7:0] a1, b1, a2, b2, det, invdet;
    a1 = GfExp[9'd16];
    b1 = GfExp[9'd17];
    a2 = GfExp[9'd32];
    b2 = GfExp[9'd34];
    det = gf_mul(a1, b2) ^ gf_mul(a2, b1);
    invdet = gf_inv(det);
    p0 = gf_mul((gf_mul(r1, b2) ^ gf_mul(r2, b1)), invdet);
    p1 = gf_mul((gf_mul(a1, r2) ^ gf_mul(a2, r1)), invdet);
  endfunction : solve_parity

  function automatic void cw_syndromes(
      input logic [127:0] data_i,
      input logic [15:0] ecc_i,
      output logic [7:0] s1,
      output logic [7:0] s2
  );
    logic [7:0] di;
    s1 = 8'h0;
    s2 = 8'h0;
    for (int unsigned ii = 0; ii < 16; ii++) begin
      di = data_i[(7'(ii) * 7'd8) +: 8];
      s1 ^= gf_mul(di, GfExp[9'(ii)]);
      s2 ^= gf_mul(di, GfExp[9'(2 * ii)]);
    end
    s1 ^= gf_mul(ecc_i[7:0], GfExp[9'd16]);
    s2 ^= gf_mul(ecc_i[7:0], GfExp[9'd32]);
    s1 ^= gf_mul(ecc_i[15:8], GfExp[9'd17]);
    s2 ^= gf_mul(ecc_i[15:8], GfExp[9'd34]);
  endfunction : cw_syndromes

endpackage : ecc_pkg

`default_nettype wire
