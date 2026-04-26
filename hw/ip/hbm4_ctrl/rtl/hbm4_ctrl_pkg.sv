// Copyright 2026 The Netie Open HBM Authors
// SPDX-License-Identifier: Apache-2.0
`default_nettype none
`timescale 1ns/1ps

// hbm4_ctrl_pkg -- types and parameters shared across the controller hierarchy.
package hbm4_ctrl_pkg;

  // ---------- Speed bins ----------
  typedef enum logic [1:0] {
    SPEED_4800 = 2'h0,
    SPEED_6400 = 2'h1,
    SPEED_8000 = 2'h2,
    SPEED_9600 = 2'h3
  } speed_e;

  // ---------- Timing parameters (CSR-programmable, defaults [SEE-SPEC]) ----------
  // The widths are sized for the 9.6 Gb/s extension bin worst-case.
  typedef struct packed {
    logic [7:0]  tRCD;
    logic [7:0]  tRP;
    logic [7:0]  tRAS;
    logic [7:0]  tRC;
    logic [11:0] tRFC_ab;
    logic [11:0] tRFC_pb;
    logic [11:0] tRFC_sb;
    logic [15:0] tREFI;
    logic [7:0]  tFAW;
    logic [4:0]  tRRD_S;
    logic [4:0]  tRRD_L;
    logic [4:0]  tCCD_S;
    logic [4:0]  tCCD_L;
    logic [7:0]  tWR;
    logic [4:0]  tWTR_S;
    logic [4:0]  tWTR_L;
    logic [5:0]  CL;
    logic [5:0]  CWL;
  } timing_t;

  // ---------- Bank machine state ----------
  typedef enum logic [3:0] {
    BANK_IDLE       = 4'h0,
    BANK_ACT_WAIT   = 4'h1,
    BANK_ACTIVE     = 4'h2,
    BANK_RD         = 4'h3,
    BANK_WR         = 4'h4,
    BANK_PRE_WAIT   = 4'h5,
    BANK_REFRESH    = 4'h6,
    BANK_DRFM       = 4'h7
  } bank_state_e;

  // ---------- Refresh modes ----------
  typedef enum logic [1:0] {
    REF_AB  = 2'h0,
    REF_SB  = 2'h1,
    REF_PB  = 2'h2,
    REF_DRFM= 2'h3
  } refresh_mode_e;

  // ---------- Channel-level command (for the DFI bridge) ----------
  typedef enum logic [2:0] {
    CMD_NOP       = 3'h0,
    CMD_ACT       = 3'h1,
    CMD_PRE       = 3'h2,
    CMD_RD        = 3'h3,
    CMD_WR        = 3'h4,
    CMD_REF_AB    = 3'h5,
    CMD_REF_PB    = 3'h6,
    CMD_DRFM      = 3'h7
  } cmd_e;

endpackage : hbm4_ctrl_pkg
