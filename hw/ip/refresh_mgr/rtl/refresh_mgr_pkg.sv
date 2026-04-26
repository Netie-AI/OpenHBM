// Copyright 2026 The Netie Open HBM Authors
// SPDX-License-Identifier: Apache-2.0
`default_nettype none
`timescale 1ns/1ps

package refresh_mgr_pkg;

  parameter int unsigned PracTopK    = 64;
  parameter int unsigned BgW         = 2;
  parameter int unsigned BaW         = 2;
  parameter int unsigned RowW        = 17;
  parameter int unsigned NumBanks    = 16;
  parameter int unsigned CreditMax   = 4;

  typedef struct packed {
    logic              valid;
    logic [RowW-1:0]   row;
    logic [11:0]       count;
  } prac_entry_t;

endpackage : refresh_mgr_pkg
