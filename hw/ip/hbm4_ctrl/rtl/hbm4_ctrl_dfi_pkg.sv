// Copyright 2026 The Netie Open HBM Authors
// SPDX-License-Identifier: Apache-2.0
`default_nettype none
`timescale 1ns/1ps

package hbm4_ctrl_dfi_pkg;

  // DFI 5.0 timing parameters
  parameter int unsigned DFI_ADDR_W      = 10;
  parameter int unsigned DFI_DATA_W      = 128;  // per channel
  parameter int unsigned DFI_BG_W        = 2;
  parameter int unsigned DFI_BANK_W      = 2;
  parameter int unsigned T_DFI_RDDATA_EN = 3;    // cycles
  parameter int unsigned T_DFI_WRDATA_EN = 1;    // cycles

  // DFI command encoding (maps to cmd_e from hbm4_ctrl_pkg)
  typedef enum logic [2:0] {
    DFI_NOP  = 3'b111,
    DFI_ACT  = 3'b011,  // RAS=0 CAS=1 WE=1
    DFI_RD   = 3'b101,  // RAS=1 CAS=0 WE=1
    DFI_WR   = 3'b100,  // RAS=1 CAS=0 WE=0
    DFI_PRE  = 3'b010,  // RAS=0 CAS=1 WE=0
    DFI_REF  = 3'b001   // RAS=0 CAS=0 WE=1
  } dfi_cmd_e;

  // DFI update FSM states
  typedef enum logic [1:0] {
    DFI_UPD_IDLE   = 2'd0,
    DFI_UPD_REQ    = 2'd1,
    DFI_UPD_ACTIVE = 2'd2,
    DFI_UPD_PHYREQ = 2'd3
  } dfi_upd_state_e;

endpackage : hbm4_ctrl_dfi_pkg
