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

  // Phase 2: pseudo-channel scale-out (1..16)
  parameter int unsigned NUM_CHANNELS  = 4;
  parameter int unsigned CHAN_ID_W     = $clog2(NUM_CHANNELS > 1 ? NUM_CHANNELS : 2);

  typedef logic [CHAN_ID_W-1:0] chan_id_t;

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

  // P4 — power-down FSM states
  typedef enum logic [1:0] {
    CHAN_ACTIVE    = 2'd0,
    CHAN_PD        = 2'd1,
    CHAN_SREF      = 2'd2,
    CHAN_SREF_EXIT = 2'd3
  } chan_pw_state_e;

  // P4 — power-down timing parameters (cycles at 1 GHz ≈ 1 ns/cycle)
  localparam int unsigned T_CKE   = 3;    // verilog_lint: waive parameter-name-style -- JEDEC tCK
  localparam int unsigned T_CKESR = 4;    // verilog_lint: waive parameter-name-style -- JEDEC tCKESR
  localparam int unsigned T_XSR   = 200;  // verilog_lint: waive parameter-name-style -- JEDEC tXSR
  localparam int unsigned T_XPDLL = 10;   // verilog_lint: waive parameter-name-style -- JEDEC tXPDLL

endpackage : hbm4_ctrl_pkg
