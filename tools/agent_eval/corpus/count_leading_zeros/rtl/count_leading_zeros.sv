// Copyright 2026 The Netie Open HBM Authors
// SPDX-License-Identifier: Apache-2.0
`default_nettype none
`timescale 1ns/1ps

// count_leading_zeros -- corpus stub. Replace with the real implementation.
// See tools/agent_eval/corpus/_template/MANIFEST.md for the per-block
// requirements before promoting this to a "landed" mini-block.
module count_leading_zeros (
  input  logic clk_i,
  input  logic rst_ni,
  input  logic d_i,
  output logic q_o
);
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) q_o <= 1'b0;
    else         q_o <= d_i;
  end

`ifndef SYNTHESIS
  a_q_follows_d : assert property (
    @(posedge clk_i) disable iff (!rst_ni)
    q_o == $past(d_i)
  );
`endif
endmodule : count_leading_zeros