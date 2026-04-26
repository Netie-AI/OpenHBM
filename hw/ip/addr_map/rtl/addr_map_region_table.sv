// Copyright 2026 The Netie Open HBM Authors
// SPDX-License-Identifier: Apache-2.0
`default_nettype none
`timescale 1ns/1ps

// addr_map_region_table -- 16-entry priority-encoded region lookup.
//
// CSR writes update a *shadow* register; an explicit COMMIT register copy
// from shadow to live keeps in-flight requests from observing partial
// updates. This is what makes assertion #4 in the agent prompt
// (CSR atomicity) hold.
module addr_map_region_table
  import addr_map_pkg::*;
(
  input  logic                  clk_i,
  input  logic                  rst_ni,

  // Lookup port
  input  logic [SaW-1:0]        lookup_sa_i,
  output region_t               lookup_region_o,
  output logic                  lookup_hit_o,

  // CSR-driven updates: shadow array + commit pulse
  input  logic                  cfg_we_i,
  input  logic [3:0]            cfg_idx_i,
  input  region_t               cfg_wdata_i,
  input  logic                  cfg_commit_i
);

  region_t shadow_q [NumRegions];
  region_t live_q   [NumRegions];

  // Initialise everything to zero (invalid).
  always_ff @(posedge clk_i or negedge rst_ni) begin : p_shadow
    if (!rst_ni) begin
      for (int unsigned i = 0; i < NumRegions; i++) begin
        shadow_q[i] <= '0;
      end
    end else if (cfg_we_i) begin
      shadow_q[cfg_idx_i] <= cfg_wdata_i;
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin : p_live
    if (!rst_ni) begin
      for (int unsigned i = 0; i < NumRegions; i++) begin
        live_q[i] <= '0;
      end
    end else if (cfg_commit_i) begin
      for (int unsigned i = 0; i < NumRegions; i++) begin
        live_q[i] <= shadow_q[i];
      end
    end
  end

  // Lookup -- find the lowest-index entry whose [base_sa, base_sa + 2**size_log2)
  // contains the address. The base is upper-bits-aligned; the size_log2 is
  // a count of bytes.
  always_comb begin : c_lookup
    lookup_hit_o    = 1'b0;
    lookup_region_o = '0;
    for (int unsigned i = 0; i < NumRegions; i++) begin
      logic [SaW-1:0] region_base;
      logic [SaW-1:0] region_size;
      region_base = {live_q[i].base_sa, {(SaW-BaseSaW){1'b0}}};
      region_size = (1 << live_q[i].size_log2);
      if (live_q[i].valid &&
          (lookup_sa_i >= region_base) &&
          (lookup_sa_i <  region_base + region_size) &&
          !lookup_hit_o) begin
        lookup_hit_o    = 1'b1;
        lookup_region_o = live_q[i];
      end
    end
  end

`ifndef SYNTHESIS
  // CSR atomicity: a write to shadow does NOT propagate to live without commit.
  a_no_partial_propagate : assert property (
    @(posedge clk_i) disable iff (!rst_ni)
    cfg_we_i && !cfg_commit_i |=> $stable(live_q)
  );
`endif

endmodule : addr_map_region_table
