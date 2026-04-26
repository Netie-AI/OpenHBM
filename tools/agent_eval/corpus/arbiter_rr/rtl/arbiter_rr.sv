// Copyright 2026 The Netie Open HBM Authors
// SPDX-License-Identifier: Apache-2.0
`default_nettype none
`timescale 1ns/1ps

// arbiter_rr -- a simple round-robin arbiter over N requesters.
//
// Issues at most one grant per cycle. The pointer advances past the granted
// requester so the next round starts after it. Anti-starvation is the
// default; weighted variants live in a different module.
module arbiter_rr #(
  parameter int unsigned N = 4
) (
  input  logic           clk_i,
  input  logic           rst_ni,
  input  logic [N-1:0]   req_i,
  output logic [N-1:0]   gnt_o,
  output logic           any_gnt_o,
  output logic [$clog2(N)-1:0] gnt_idx_o
);

  localparam int unsigned IdxW = $clog2(N);

  logic [IdxW-1:0] ptr_q;

  // Build a rotated request mask, find the lowest-set bit, then rotate back.
  logic [N-1:0] rotated_req;
  logic [N-1:0] rotated_gnt;
  always_comb begin
    rotated_req = '0;
    for (int unsigned i = 0; i < N; i++) begin
      rotated_req[i] = req_i[(i + ptr_q) % N];
    end
  end

  // Lowest-set-bit isolation: rotated_req & -rotated_req
  assign rotated_gnt = rotated_req & (~rotated_req + 1'b1);

  always_comb begin
    gnt_o = '0;
    for (int unsigned i = 0; i < N; i++) begin
      gnt_o[(i + ptr_q) % N] = rotated_gnt[i];
    end
  end

  assign any_gnt_o = |gnt_o;

  always_comb begin : c_idx
    gnt_idx_o = '0;
    for (int unsigned i = 0; i < N; i++) begin
      if (gnt_o[i]) gnt_idx_o = IdxW'(i);
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin : p_ptr
    if (!rst_ni) begin
      ptr_q <= '0;
    end else if (any_gnt_o) begin
      ptr_q <= (gnt_idx_o + IdxW'(1)) % IdxW'(N);
    end
  end

  // ---------------------------------------------------------------------------
  // SVA
  // ---------------------------------------------------------------------------
`ifndef SYNTHESIS
  // At most one bit set in gnt_o.
  a_onehot_gnt : assert property (
    @(posedge clk_i) disable iff (!rst_ni)
    $countones(gnt_o) <= 1
  );
  // No grant without a request at the same position.
  a_gnt_implies_req : assert property (
    @(posedge clk_i) disable iff (!rst_ni)
    (gnt_o & ~req_i) == '0
  );
  // If any req is high, exactly one grant is issued.
  a_progress : assert property (
    @(posedge clk_i) disable iff (!rst_ni)
    (|req_i) |-> any_gnt_o
  );
`endif

endmodule : arbiter_rr
