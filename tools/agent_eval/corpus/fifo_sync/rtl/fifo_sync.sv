// Copyright 2026 The Netie Open HBM Authors
// SPDX-License-Identifier: Apache-2.0
`default_nettype none
`timescale 1ns/1ps

// fifo_sync -- a single-clock-domain synchronous FIFO.
//
// Reset                : asynchronous assert, synchronous deassert
// Latency              : 1 cycle (push to pop visibility)
// Throughput           : 1 element per cycle
// Width / Depth        : parameterised; depth must be power of 2
// Full / Empty flags   : registered, deassert in the same cycle the
//                        non-blocking condition is satisfied.
//
// The implementation is a circular buffer with a binary read/write
// pointer pair. Because read and write share a clock, no Gray coding
// is required. For a CDC variant see fifo_async.
module fifo_sync #(
  parameter int unsigned Width = 8,
  parameter int unsigned Depth = 8,
  // Derived
  localparam int unsigned PtrW = $clog2(Depth)
) (
  input  logic              clk_i,
  input  logic              rst_ni,

  input  logic              push_i,
  input  logic [Width-1:0]  push_data_i,
  output logic              full_o,

  input  logic              pop_i,
  output logic [Width-1:0]  pop_data_o,
  output logic              empty_o,

  output logic [PtrW:0]     fill_o
);

  // Storage
  logic [Width-1:0] mem [Depth];

  // Pointers carry one extra bit so wrap can be distinguished from empty.
  logic [PtrW:0] wptr_q, rptr_q;

  // Element count
  assign fill_o = wptr_q - rptr_q;

  assign empty_o = (wptr_q == rptr_q);
  assign full_o  = (fill_o == PtrW'(Depth));

  always_ff @(posedge clk_i or negedge rst_ni) begin : p_ptrs
    if (!rst_ni) begin
      wptr_q <= '0;
      rptr_q <= '0;
    end else begin
      if (push_i && !full_o)  wptr_q <= wptr_q + 1'b1;
      if (pop_i  && !empty_o) rptr_q <= rptr_q + 1'b1;
    end
  end

  always_ff @(posedge clk_i) begin : p_mem
    if (push_i && !full_o) begin
      mem[wptr_q[PtrW-1:0]] <= push_data_i;
    end
  end

  assign pop_data_o = mem[rptr_q[PtrW-1:0]];

  // ---------------------------------------------------------------------------
  // SVA -- protocol invariants
  // ---------------------------------------------------------------------------
`ifndef SYNTHESIS
  // No push when full (caller is required to gate).
  a_no_push_when_full : assert property (
    @(posedge clk_i) disable iff (!rst_ni)
    !(push_i && full_o)
  );
  // No pop when empty.
  a_no_pop_when_empty : assert property (
    @(posedge clk_i) disable iff (!rst_ni)
    !(pop_i && empty_o)
  );
  // Fill never exceeds depth.
  a_fill_in_range : assert property (
    @(posedge clk_i) disable iff (!rst_ni)
    fill_o <= PtrW'(Depth)
  );
`endif

endmodule : fifo_sync
