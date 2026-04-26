// Copyright 2026 The Netie Open HBM Authors
// SPDX-License-Identifier: Apache-2.0
`default_nettype none
`timescale 1ns/1ps

// xor_addr_mapper_toy -- a 4-channel XOR address mapper for the corpus.
//
// This is a deliberately tiny precursor to hw/ip/addr_map. The full
// addr_map is parameterised over (channels, pseudo-channels, banks, rows,
// columns) and selects between three modes per-region. This toy version
// fixes the geometry to:
//   - 4 channels    (2 bits)
//   - 4 banks       (2 bits)
//   - 65,536 rows   (16 bits)
//   - 64 columns    (6 bits)
// and supports two modes: striped or bank-interleaved.
//
// It is small enough to fully exhaustive-prove via SymbiYosys.
module xor_addr_mapper_toy (
  input  logic        clk_i,
  input  logic        rst_ni,
  input  logic        mode_i,         // 0 = striped, 1 = bank-interleaved
  input  logic [25:0] sa_i,           // 64 MB address space
  output logic [1:0]  ch_o,
  output logic [1:0]  bank_o,
  output logic [15:0] row_o,
  output logic [5:0]  col_o,
  output logic        valid_o
);

  // Striped:           sa[1:0] -> ch     ; sa[3:2] -> bank ; sa[19:4]  -> row ; sa[25:20] -> col
  // Bank-interleaved:  sa[1:0] -> bank   ; sa[3:2] -> ch   ; sa[19:4]  -> row ; sa[25:20] -> col
  //
  // To make the mapper non-degenerate, XOR the high address bits into the
  // row to scramble locality.
  logic [15:0] xor_taps;
  assign xor_taps = sa_i[25:10];

  always_comb begin : c_map
    if (mode_i == 1'b0) begin
      ch_o   = sa_i[1:0];
      bank_o = sa_i[3:2];
    end else begin
      bank_o = sa_i[1:0];
      ch_o   = sa_i[3:2];
    end
    row_o = sa_i[19:4] ^ xor_taps;
    col_o = sa_i[25:20];
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin : p_valid
    if (!rst_ni) valid_o <= 1'b0;
    else         valid_o <= 1'b1;
  end

`ifndef SYNTHESIS
  // Bound asserts.
  a_ch_bound   : assert property (@(posedge clk_i) ch_o   < 2'd3 + 2'd1);
  a_bank_bound : assert property (@(posedge clk_i) bank_o < 2'd3 + 2'd1);
`endif

endmodule : xor_addr_mapper_toy
