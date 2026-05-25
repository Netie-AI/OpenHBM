// Copyright 2026 The Netie Open HBM Authors
// SPDX-License-Identifier: Apache-2.0
//
// AXI4 typedefs and small helpers for hbm4_ctrl front-end (AMBA AXI4 subset).
`default_nettype none
`timescale 1ns/1ps

package hbm4_ctrl_axi4_pkg;

  typedef enum logic [1:0] {
    RESP_OKAY   = 2'b00,
    RESP_EXOKAY = 2'b01,
    RESP_SLVERR = 2'b10,
    RESP_DECERR = 2'b11
  } axi_resp_e;

  typedef enum logic [1:0] {
    BURST_FIXED = 2'b00,
    BURST_INCR  = 2'b01,
    BURST_WRAP  = 2'b10,
    BURST_RSVD  = 2'b11
  } axi_burst_e;

endpackage : hbm4_ctrl_axi4_pkg
