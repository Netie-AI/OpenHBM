// Copyright 2026 The Netie Open HBM Authors
// SPDX-License-Identifier: Apache-2.0
`default_nettype none
`timescale 1ns/1ps

// addr_map_pkg -- shared types and parameters for the addr_map IP.
//
// The widths below match the JESD270-4A 32-channel x 2-pseudo-channel HBM4
// geometry. Re-targeting to HBM3 / GDDR / DDR5 is achieved by overriding
// these in a derived package.
package addr_map_pkg;

  // ---------- DRAM geometry ----------
  parameter int unsigned NUM_CHANNELS         = 32;  // 5-bit
  parameter int unsigned NUM_PSEUDO_CHANNELS  = 2;   // 1-bit per channel
  parameter int unsigned NUM_BANK_GROUPS      = 4;   // 2-bit
  parameter int unsigned NUM_BANKS_PER_GROUP  = 4;   // 2-bit
  parameter int unsigned NUM_ROWS             = 1 << 17;
  parameter int unsigned NUM_COLS             = 64;  // 32 B granules

  parameter int unsigned ChW = $clog2(NUM_CHANNELS);
  parameter int unsigned PChW = $clog2(NUM_PSEUDO_CHANNELS);
  parameter int unsigned BgW = $clog2(NUM_BANK_GROUPS);
  parameter int unsigned BaW = $clog2(NUM_BANKS_PER_GROUP);
  parameter int unsigned RowW = $clog2(NUM_ROWS);
  parameter int unsigned ColW = $clog2(NUM_COLS);

  parameter int unsigned SaW  = 64;  // system address width

  // ---------- Mapped address ----------
  typedef struct packed {
    logic [ChW-1:0]  ch;
    logic [PChW-1:0] pch;
    logic [BgW-1:0]  bg;
    logic [BaW-1:0]  ba;
    logic [RowW-1:0] row;
    logic [ColW-1:0] col;
  } pa_t;

  // ---------- Operation ----------
  typedef enum logic [1:0] {
    OP_READ     = 2'h0,
    OP_WRITE    = 2'h1,
    OP_ATOMIC   = 2'h2,
    OP_PREFETCH = 2'h3
  } op_e;

  // ---------- Mapping mode ----------
  typedef enum logic [1:0] {
    MODE_CH_STRIPED       = 2'h0,
    MODE_BANK_INTERLEAVED = 2'h1,
    MODE_ROW_STATIONARY   = 2'h2,
    MODE_RESERVED         = 2'h3
  } mode_e;

  // ---------- Region descriptor ----------
  parameter int unsigned NumRegions = 16;
  parameter int unsigned BaseSaW    = 40;        // 4 KiB-aligned base
  parameter int unsigned XorPolyW   = 32;
  parameter int unsigned SizeLog2W  = 6;

  typedef struct packed {
    logic                   valid;
    logic [BaseSaW-1:0]     base_sa;     // upper bits of system address
    logic [SizeLog2W-1:0]   size_log2;   // region = 2**size_log2 bytes
    mode_e                  mode;
    logic [XorPolyW-1:0]    xor_poly;    // taps over the upper system bits
  } region_t;

  // ---------- Default polynomials ----------
  // Selection rationale and ASPLOS/ISCA prior art lives in the ADR at
  // docs/rfcs/0001-addr-map-policy.md.
  parameter logic [XorPolyW-1:0] DEFAULT_POLY_CH_STRIPED       = 32'hA1B2_C3D4;
  parameter logic [XorPolyW-1:0] DEFAULT_POLY_BANK_INTERLEAVED = 32'h5A5A_A5A5;
  parameter logic [XorPolyW-1:0] DEFAULT_POLY_ROW_STATIONARY   = 32'hCAFE_BABE;

  // ---------- Pure helper: XOR-fold of upper bits into a smaller field ----------
  function automatic logic [31:0] xor_fold32(input logic [SaW-1:0] sa,
                                             input logic [XorPolyW-1:0] poly);
    logic [31:0] hi;
    logic [31:0] lo;
    hi = sa[SaW-1:SaW-32];
    lo = sa[31:0];
    return (hi & poly) ^ (lo & ~poly);
  endfunction

endpackage : addr_map_pkg
