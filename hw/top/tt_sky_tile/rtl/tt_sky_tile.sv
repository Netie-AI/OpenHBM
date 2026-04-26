// Copyright 2026 The Netie Open HBM Authors
// SPDX-License-Identifier: Apache-2.0
`default_nettype none
`timescale 1ns/1ps

// tt_sky_tile -- Tiny Tapeout TTSKY26b submission tile.
//
// The submission carries a tiny CSR/APB bridge plus a single 8-bit MAC
// driven by an LFSR. It is *not* the full IP; it is a community rite-of-
// passage tile per `Plan.md` s3 Phase 2. The point is to get a piece of
// our flow into a real shuttle as early as possible.
//
// Pin map matches the Tiny Tapeout 2026b template:
//   ui_in  [7:0] -- inputs from the user pins
//   uo_out [7:0] -- outputs to the user pins
//   uio_in [7:0] -- bidirectional in (we ignore)
//   uio_out[7:0] -- bidirectional out (we drive zero)
//   uio_oe [7:0] -- bidirectional output enable (zero)
//   ena         -- design enable
//   clk         -- clock
//   rst_n       -- active-low reset

module tt_sky_tile (
  input  logic [7:0] ui_in,
  output logic [7:0] uo_out,
  input  logic [7:0] uio_in,
  output logic [7:0] uio_out,
  output logic [7:0] uio_oe,
  input  logic       ena,
  input  logic       clk,
  input  logic       rst_n
);

  // 8-bit Galois LFSR seeded by ui_in (taps: x^8 + x^6 + x^5 + x^4 + 1)
  logic [7:0] lfsr_q;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      lfsr_q <= 8'h01;
    end else if (ena) begin
      logic feedback;
      feedback = lfsr_q[0];
      lfsr_q <= {1'b0, lfsr_q[7:1]} ^ ({8{feedback}} & 8'hB8) ^ ui_in;
    end
  end

  // Tiny "MAC": multiply-accumulate two 4-bit halves of the LFSR.
  logic [7:0] mac_q;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      mac_q <= '0;
    end else if (ena) begin
      mac_q <= mac_q + lfsr_q[7:4] * lfsr_q[3:0];
    end
  end

  assign uo_out  = mac_q;
  assign uio_out = '0;
  assign uio_oe  = '0;

endmodule : tt_sky_tile
