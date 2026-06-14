// Copyright 2026 The Netie Open HBM Authors
// SPDX-License-Identifier: Apache-2.0
//
// ecc_decode -- bounded-distance-1 decoder: unique 1-symbol flip to a
// codeword yields correction; otherwise uncorrectable (ue_o).
`default_nettype none
`timescale 1ns/1ps

module ecc_decode (
    input logic [127:0] data_i,
    input logic [15:0] ecc_i,
    output logic [127:0] data_o,
    output logic [15:0] syndrome_o,
    output logic ce_o,
    output logic ue_o
);
  import ecc_pkg::*;

  logic [7:0] s1, s2;
  logic [7:0] t1, t2;
  logic [127:0] cand_d;
  logic [127:0] best_d;
  logic [13:0] n_sol;

  function automatic void cw_synd_after_flip(
      input logic [127:0] d_i,
      input logic [15:0] e_i,
      input logic [4:0] pos,
      input logic [7:0] mag,
      output logic [7:0] o1,
      output logic [7:0] o2
  );
    logic [127:0] dd;
    logic [15:0] ee;
    dd = d_i;
    ee = e_i;
    if (pos < 5'd16) begin
      dd[(7'(pos) * 7'd8) +: 8] = dd[(7'(pos) * 7'd8) +: 8] ^ mag;
    end else if (pos == 5'd16) begin
      ee[7:0] = ee[7:0] ^ mag;
    end else begin
      ee[15:8] = ee[15:8] ^ mag;
    end
    cw_syndromes(dd, ee, o1, o2);
  endfunction : cw_synd_after_flip

  always_comb begin
    cw_syndromes(data_i, ecc_i, s1, s2);
    syndrome_o = {s2, s1};
    n_sol = 14'd0;
    best_d = data_i;
    if (s1 == 8'h0 && s2 == 8'h0) begin
      data_o = data_i;
      ce_o   = 1'b0;
      ue_o   = 1'b0;
    end else begin
      for (int unsigned pos = 0; pos < 18; pos++) begin
        for (int unsigned mag = 1; mag < 256; mag++) begin
          cw_synd_after_flip(
              data_i, ecc_i, 5'(pos), 8'(mag), t1, t2);
          if (t1 == 8'h0 && t2 == 8'h0) begin
            n_sol = n_sol + 14'd1;
            cand_d = data_i;
            if (pos < 5'd16) begin
              cand_d[(7'(pos) * 7'd8) +: 8] = cand_d[(7'(pos) * 7'd8) +: 8] ^ 8'(mag);
            end
            best_d = cand_d;
          end
        end
      end
      if (n_sol == 14'd1) begin
        data_o = best_d;
        ce_o   = 1'b1;
        ue_o   = 1'b0;
      end else begin
        data_o = data_i;
        ce_o   = 1'b0;
        ue_o   = 1'b1;
      end
    end
  end
endmodule : ecc_decode

`default_nettype wire
