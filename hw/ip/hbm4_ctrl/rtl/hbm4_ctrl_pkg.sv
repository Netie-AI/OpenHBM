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

  // P5 — Temperature-aware refresh
  typedef enum logic [1:0] {
    TEMP_COLD   = 2'd0,   // < 45°C  → 2× tREFI
    TEMP_NORMAL = 2'd1,   // 45–85°C → 1× tREFI
    TEMP_HOT    = 2'd2    // > 85°C  → 0.5× tREFI
  } temp_band_e;

  // Base tREFI = 7800 ns; at 1 GHz = 7800 cycles
  localparam int unsigned TREFI_BASE = 7800;  // verilog_lint: waive parameter-name-style -- JEDEC tREFI
  localparam int unsigned TREFI_COLD = 15600;  // verilog_lint: waive parameter-name-style -- 2× base
  localparam int unsigned TREFI_HOT  = 3900;   // verilog_lint: waive parameter-name-style -- 0.5× base
  localparam int unsigned TEMP_HYST  = 2;      // verilog_lint: waive parameter-name-style -- °C guard

  // P6 — Training FSM states
  typedef enum logic [2:0] {
    TRAIN_IDLE  = 3'd0,
    TRAIN_WRLVL = 3'd1,
    TRAIN_RDLVL = 3'd2,
    TRAIN_DONE  = 3'd3,
    TRAIN_ERR   = 3'd4
  } train_state_e;

  localparam int unsigned TRAIN_TIMEOUT = 1024;  // verilog_lint: waive parameter-name-style -- cycles before TRAIN_ERR

  // P7 — QoS classes and DWRR weights
  typedef enum logic [1:0] {
    QOS_P0 = 2'd0,   // highest — real-time / interrupt
    QOS_P1 = 2'd1,   // high     — latency-sensitive
    QOS_P2 = 2'd2,   // normal   — best-effort bulk
    QOS_P3 = 2'd3    // low      — background scrub
  } qos_class_e;

  // DWRR weights per class (total = 15 slots per round)
  localparam int unsigned QosW0 = 8;   // verilog_lint: waive parameter-name-style -- P0 DWRR quantum
  localparam int unsigned QosW1 = 4;   // verilog_lint: waive parameter-name-style -- P1 DWRR quantum
  localparam int unsigned QosW2 = 2;   // verilog_lint: waive parameter-name-style -- P2 DWRR quantum
  localparam int unsigned QosW3 = 1;   // verilog_lint: waive parameter-name-style -- P3 DWRR quantum

  // Starvation guard: P3 guaranteed 1 slot per N rounds
  localparam int unsigned QosStarvationLimit = 64;  // verilog_lint: waive parameter-name-style -- P3 guard

  // P8 — RAS / error types
  typedef enum logic [1:0] {
    ERR_NONE = 2'd0,
    ERR_CE   = 2'd1,
    ERR_UE   = 2'd2
  } ras_err_type_e;

  localparam int unsigned RAS_LOG_DEPTH = 8;   // verilog_lint: waive parameter-name-style -- P8 log FIFO depth
  localparam int unsigned RAS_CTR_W     = 16;  // verilog_lint: waive parameter-name-style -- P8 counter width

endpackage : hbm4_ctrl_pkg
