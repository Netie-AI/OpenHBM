// Copyright 2026 The Netie Open HBM Authors
// SPDX-License-Identifier: Apache-2.0
//
// Simulation-only 64K-entry DRAM array for end-to-end DV (P9).
`default_nettype none
`timescale 1ns/1ps

module hbm4_dram_model #(
    parameter int unsigned DQ_WIDTH  = 128,
    parameter int unsigned NUM_BANKS = 16,
    parameter int unsigned MEM_DEPTH = 65536
) (
    input  logic                  clk_i,
    input  logic                  rst_ni,

    input  logic                  cmd_valid_i,
    input  logic [3:0]            cmd_bank_i,
    input  logic [15:0]           cmd_row_i,
    input  logic [9:0]            cmd_col_i,
    input  logic                  cmd_is_write_i,
    input  logic [DQ_WIDTH-1:0]   wdata_i,
    input  logic [DQ_WIDTH/8-1:0] wstrb_i,

    output logic [DQ_WIDTH-1:0]   rdata_o,
    output logic                  rdata_valid_o
);

  logic [DQ_WIDTH-1:0] mem [0:MEM_DEPTH-1];
  logic [15:0]         flat_addr;

  assign flat_addr = {cmd_bank_i, cmd_row_i[7:0], cmd_col_i[3:0]};

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      rdata_o       <= '0;
      rdata_valid_o <= 1'b0;
    end else begin
      rdata_valid_o <= 1'b0;
      if (cmd_valid_i) begin
        if (cmd_is_write_i) begin
          for (int b = 0; b < DQ_WIDTH / 8; b++) begin
            if (wstrb_i[b]) begin
              mem[flat_addr][b*8 +: 8] <= wdata_i[b*8 +: 8];
            end
          end
        end else begin
          rdata_o       <= mem[flat_addr];
          rdata_valid_o <= 1'b1;
        end
      end
    end
  end

endmodule : hbm4_dram_model

`default_nettype wire
