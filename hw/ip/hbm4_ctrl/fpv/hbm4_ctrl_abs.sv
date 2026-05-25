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
    input logic                    drfm_ack_i,
    input logic                    dfi_ctrlupd_req_i,
    input logic                    dfi_ctrlupd_ack_i,
    input logic                    dfi_phyupd_req_i,
    input logic                    dfi_lp_ctrl_req_i,
    input logic                    dfi_lp_ctrl_ack_i,
    input logic                    pwrdn_req_i,
    input logic                    sref_req_i,
    input logic                    exit_req_i,
    input logic [7:0]              temp_celsius_i
);

  assume property (@(posedge clk_i) disable iff (!rst_ni) !$isunknown(awvalid_i));
  assume property (@(posedge clk_i) disable iff (!rst_ni) !$isunknown(arvalid_i));
  assume property (@(posedge clk_i) disable iff (!rst_ni) !$isunknown(awaddr_i));
  assume property (@(posedge clk_i) disable iff (!rst_ni) !$isunknown(drfm_ack_i));
  assume property (@(posedge clk_i) disable iff (!rst_ni) !$isunknown(dfi_ctrlupd_req_i));
  assume property (@(posedge clk_i) disable iff (!rst_ni) !$isunknown(dfi_ctrlupd_ack_i));
  assume property (@(posedge clk_i) disable iff (!rst_ni) !$isunknown(dfi_phyupd_req_i));

  property p_ack_after_req;
    @(posedge clk_i) disable iff (!rst_ni)
    dfi_ctrlupd_ack_i |-> dfi_ctrlupd_req_i;
  endproperty
  a_ack_after_req: assume property (p_ack_after_req);

  // P3: bound phyupd_req pulse width for BMC
  logic [1:0] phyupd_len_q;
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      phyupd_len_q <= 2'd0;
    end else if (dfi_phyupd_req_i) begin
      phyupd_len_q <= phyupd_len_q + 2'd1;
    end else begin
      phyupd_len_q <= 2'd0;
    end
  end
  a_phyupd_bound: assume property (@(posedge clk_i) disable iff (!rst_ni)
      phyupd_len_q <= 2'd3);

  property lp_ack_response;
    @(posedge clk_i) disable iff (!rst_ni)
    dfi_lp_ctrl_req_i |-> ##[1:4] dfi_lp_ctrl_ack_i;
  endproperty
  a_lp_ack_response: assume property (lp_ack_response);

  assume property (@(posedge clk_i) disable iff (!rst_ni) !(pwrdn_req_i && exit_req_i));
  assume property (@(posedge clk_i) disable iff (!rst_ni) !(sref_req_i && exit_req_i));

  // Constrain temperature to realistic sensor range
  assume property (@(posedge clk_i) disable iff (!rst_ni)
      (temp_celsius_i >= 8'd0) && (temp_celsius_i <= 8'd125));

endmodule : hbm4_ctrl_abs

`default_nettype wire
