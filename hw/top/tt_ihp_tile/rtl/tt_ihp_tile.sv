// Copyright 2026 The Netie Open HBM Authors
// SPDX-License-Identifier: Apache-2.0
`default_nettype none
`timescale 1ns/1ps

// tt_ihp_tile -- Tiny Tapeout TTIHP26a submission for IHP SG13G2.
//
// Same shape as tt_sky_tile but provisioned for the IHP harness.
// IHP SG13G2 is BiCMOS with 350 GHz SiGe HBTs, so future tiles can
// experiment with the analog support; this Phase-0 tile is digital only.

module tt_ihp_tile (
  input  logic [7:0] ui_in,
  output logic [7:0] uo_out,
  input  logic [7:0] uio_in,
  output logic [7:0] uio_out,
  output logic [7:0] uio_oe,
  input  logic       ena,
  input  logic       clk,
  input  logic       rst_n
);

  logic [15:0] cnt_q;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) cnt_q <= '0;
    else if (ena) cnt_q <= cnt_q + 16'h1;
  end

  assign uo_out  = cnt_q[15:8] ^ ui_in;
  assign uio_out = '0;
  assign uio_oe  = '0;

endmodule : tt_ihp_tile
