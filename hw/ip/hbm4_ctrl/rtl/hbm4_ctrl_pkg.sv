// Copyright 2026 The Netie Open HBM Authors
// SPDX-License-Identifier: Apache-2.0
`default_nettype none
`timescale 1ns/1ps

package hbm4_ctrl_pkg;

  parameter int unsigned BANK_GROUPS     = 4;
  parameter int unsigned BANKS_PER_BG    = 4;
  parameter int unsigned ROW_W           = 15;
  parameter int unsigned COL_W           = 6;
  parameter int unsigned NUM_BANKS       = BANK_GROUPS * BANKS_PER_BG;

  parameter int unsigned T_RCD = 4;
  parameter int unsigned T_RAS = 10;
  parameter int unsigned T_RP  = 4;
  parameter int unsigned T_RC  = 14;

  // AXI4 front-end (Phase 1 v0.2)
  parameter int unsigned AXI_ID_W   = 4;
  parameter int unsigned AXI_ADDR_W = 32;
  parameter int unsigned AXI_DATA_W  = 64;

  typedef enum logic [2:0] {
    IDLE_CMD = 3'd0,
    ACT      = 3'd1,
    RD       = 3'd2,
    WR       = 3'd3,
    PRE      = 3'd4,
    REF      = 3'd5
  } cmd_e;

  typedef enum logic [1:0] {
    BANK_IDLE     = 2'd0,
    BANK_ACTIVE   = 2'd1,
    BANK_REFRESH  = 2'd2
  } bank_state_e;

  typedef logic [$clog2(NUM_BANKS)-1:0] bank_addr_t;
  typedef logic [ROW_W-1:0] row_t;
  typedef logic [COL_W-1:0] col_t;

endpackage : hbm4_ctrl_pkg
