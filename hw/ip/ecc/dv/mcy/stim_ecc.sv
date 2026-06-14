// Copyright 2026 The Netie Open HBM Authors
// SPDX-License-Identifier: Apache-2.0
`default_nettype none
`timescale 1ns/1ps

// Directed stimulus for ECC mutation testing (Icarus / vvp).
module stim_ecc;

  logic [127:0] data_i;
  logic [15:0]  ecc_o;
  logic [127:0] corrected_o;
  logic         err_o;
  logic         derr_o;

  ecc u_dut (
      .data_i(data_i),
      .ecc_i (ecc_o),
      .corrected_o(corrected_o),
      .err_o (err_o),
      .derr_o(derr_o)
  );

  initial begin : main
    data_i = 128'h0;
    ecc_o  = 16'h0;
    #1;
    if (corrected_o !== 128'h0 || err_o || derr_o) begin
      $display("FAIL: zero codeword mismatch");
      $finish_and_return(1);
    end

    data_i = 128'h0123_4567_89ab_cdef_0123_4567_89ab_cdef;
    #1;
    if (err_o || derr_o) begin
      $display("FAIL: uncorrected data flagged error");
      $finish_and_return(1);
    end
    if (corrected_o !== data_i) begin
      $display("FAIL: corrected data mismatch");
      $finish_and_return(1);
    end

    $display("PASS: stim_ecc");
    $finish_and_return(0);
  end
endmodule : stim_ecc
