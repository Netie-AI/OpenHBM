// Copyright 2026 The Netie Open HBM Authors
// SPDX-License-Identifier: Apache-2.0
`default_nettype none
`timescale 1ns/1ps

// addr_map_xor -- per-region XOR-hash combinational mapper.
//
// Pure combinational. The wrapper (addr_map.sv) registers the output to
// guarantee single-cycle latency.
//
// The mapping operates on the *region-relative* offset:
//   offset = sa - region.base_sa (truncated to size_log2 bits)
// This guarantees no cross-region aliasing.
module addr_map_xor
  import addr_map_pkg::*;
(
  input  logic [SaW-1:0]   sa_i,
  input  region_t          region_i,
  input  mode_e            default_mode_i,

  output pa_t              pa_o
);

  // ---------- Compute region-relative offset ----------
  logic [SaW-1:0] base_full;
  assign base_full = {region_i.base_sa, {(SaW-BaseSaW){1'b0}}};
  logic [SaW-1:0] offs;
  assign offs = sa_i - base_full;

  // ---------- Choose mode ----------
  mode_e mode_eff;
  assign mode_eff = region_i.valid ? region_i.mode : default_mode_i;

  // ---------- Drive each PA field per mode ----------
  // The schemes are:
  //  - CH_STRIPED      :  low offs bits feed (pch, ch);  next feed (bg, ba); high feed row, top feed col
  //  - BANK_INTERLEAVED:  low offs bits feed (pch, bg, ba); next feed ch ; high feed row, top feed col
  //  - ROW_STATIONARY  :  low offs bits feed col;        next feed (bg, ba); next feed (pch, ch); high feed row
  //
  // The XOR polynomial scrambles `row` against the high offset bits so two
  // strided streams do not all land in the same row buffer.
  logic [31:0] xor_for_row;
  assign xor_for_row = xor_fold32(offs, region_i.xor_poly);

  always_comb begin : c_map
    pa_o = '0;
    unique case (mode_eff)
      MODE_CH_STRIPED: begin
        pa_o.pch = offs[5];                                  // 32 B granules
        pa_o.ch  = offs[ChW+5:6];
        pa_o.bg  = offs[ChW+5+BgW:ChW+6];
        pa_o.ba  = offs[ChW+5+BgW+BaW:ChW+6+BgW];
        pa_o.col = offs[ChW+5+BgW+BaW+ColW:ChW+6+BgW+BaW];
        pa_o.row = offs[ChW+5+BgW+BaW+ColW+RowW:ChW+6+BgW+BaW+ColW]
                   ^ xor_for_row[RowW-1:0];
      end
      MODE_BANK_INTERLEAVED: begin
        pa_o.pch = offs[5];
        pa_o.bg  = offs[BgW+5:6];
        pa_o.ba  = offs[BgW+5+BaW:BgW+6];
        pa_o.ch  = offs[BgW+5+BaW+ChW:BgW+6+BaW];
        pa_o.col = offs[BgW+5+BaW+ChW+ColW:BgW+6+BaW+ChW];
        pa_o.row = offs[BgW+5+BaW+ChW+ColW+RowW:BgW+6+BaW+ChW+ColW]
                   ^ xor_for_row[RowW-1:0];
      end
      MODE_ROW_STATIONARY: begin
        pa_o.col = offs[ColW+4:5];
        pa_o.bg  = offs[ColW+4+BgW:ColW+5];
        pa_o.ba  = offs[ColW+4+BgW+BaW:ColW+5+BgW];
        pa_o.pch = offs[ColW+6+BgW+BaW];
        pa_o.ch  = offs[ColW+6+BgW+BaW+ChW:ColW+7+BgW+BaW];
        pa_o.row = offs[ColW+6+BgW+BaW+ChW+RowW:ColW+7+BgW+BaW+ChW]
                   ^ xor_for_row[RowW-1:0];
      end
      default: begin
        // Reserved: pass-through low bits with no XOR.
        pa_o.pch = offs[5];
        pa_o.ch  = offs[ChW+5:6];
        pa_o.bg  = offs[ChW+5+BgW:ChW+6];
        pa_o.ba  = offs[ChW+5+BgW+BaW:ChW+6+BgW];
        pa_o.col = offs[ChW+5+BgW+BaW+ColW:ChW+6+BgW+BaW];
        pa_o.row = offs[ChW+5+BgW+BaW+ColW+RowW:ChW+6+BgW+BaW+ColW];
      end
    endcase
  end

endmodule : addr_map_xor
