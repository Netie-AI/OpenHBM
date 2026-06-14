// Copyright 2026 The Netie Open HBM Authors
// SPDX-License-Identifier: Apache-2.0
`default_nettype none
`timescale 1ns/1ps

module stim_addr_map_xor;

  import addr_map_pkg::*;

  logic [63:0] sa_i;
  logic [3:0]  poly_i;
  pa_t         pa_o;

  addr_map_xor u_dut (
      .sa_i  (sa_i),
      .poly_i(poly_i),
      .pa_o  (pa_o)
  );

  initial begin : main
    sa_i   = 64'h0000_0000_0000_0001;
    poly_i = 4'h1;
    #1;
    if (pa_o.valid && pa_o.row == '0 && pa_o.col == '0) begin
      $display("PASS: stim_addr_map_xor");
      $finish_and_return(0);
    end
    $display("FAIL: unexpected map output");
    $finish_and_return(1);
  end
endmodule : stim_addr_map_xor
