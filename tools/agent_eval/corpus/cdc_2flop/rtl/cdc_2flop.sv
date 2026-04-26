// Copyright 2026 The Netie Open HBM Authors
// SPDX-License-Identifier: Apache-2.0
`default_nettype none
`timescale 1ns/1ps

// cdc_2flop -- the canonical 2-flop synchroniser.
//
// Use only for single-bit, level-encoded signals. Multi-bit must use
// prim_fifo_async or prim_sync_grayctr.
module cdc_2flop #(
  parameter int unsigned NumStages = 2,  // minimum 2; 3 for very high MTBF
  parameter logic        ResetVal  = 1'b0
) (
  input  logic clk_dst_i,
  input  logic rst_dst_ni,
  input  logic d_i,         // sampled in the source domain
  output logic q_o          // resynchronised to clk_dst_i
);

  // synopsys async_set_reset_local "rst_dst_ni"
  logic [NumStages-1:0] sync_q;

  always_ff @(posedge clk_dst_i or negedge rst_dst_ni) begin : p_sync
    if (!rst_dst_ni) begin
      sync_q <= {NumStages{ResetVal}};
    end else begin
      sync_q <= {sync_q[NumStages-2:0], d_i};
    end
  end

  assign q_o = sync_q[NumStages-1];

endmodule : cdc_2flop
