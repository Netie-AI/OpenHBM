// Copyright 2026 The Netie Open HBM Authors
// SPDX-License-Identifier: Apache-2.0
//
// Formal assumptions on hbm4_ctrl AXI4 primary inputs.
`default_nettype none
`timescale 1ns/1ps

module hbm4_ctrl_abs #(
    parameter int unsigned P_AXI_ADDR_W = hbm4_ctrl_pkg::AXI_ADDR_W
) (
    input logic                    clk_i,
    input logic                    rst_ni,
    input logic                    awvalid_i,
    input logic [P_AXI_ADDR_W-1:0] awaddr_i,
    input logic                    arvalid_i,
    input logic                    drfm_ack_i
);

  assume property (@(posedge clk_i) disable iff (!rst_ni) !$isunknown(awvalid_i));
  assume property (@(posedge clk_i) disable iff (!rst_ni) !$isunknown(arvalid_i));
  assume property (@(posedge clk_i) disable iff (!rst_ni) !$isunknown(awaddr_i));
  assume property (@(posedge clk_i) disable iff (!rst_ni) !$isunknown(drfm_ack_i));

endmodule : hbm4_ctrl_abs

`default_nettype wire
