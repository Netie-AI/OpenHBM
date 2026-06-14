// Copyright 2026 The Netie Open HBM Authors
// SPDX-License-Identifier: Apache-2.0
//
// Temperature-aware tREFI scaler: COLD/NORMAL/HOT bands with 2°C hysteresis.
`default_nettype none
`timescale 1ns/1ps

module hbm4_ctrl_trefi_ctrl
  import hbm4_ctrl_pkg::*;
(
    input  logic        clk_i,
    input  logic        rst_ni,
    input  logic [7:0]  temp_celsius_i,
    output logic [15:0] trefi_cycles_o,
    output hbm4_ctrl_pkg::temp_band_e temp_band_o
);

  temp_band_e band_q;
  temp_band_e next_band;

  always_comb begin : g_next_band
    unique case (band_q)
      TEMP_COLD: begin
        if (temp_celsius_i >= 8'd47) begin
          next_band = TEMP_NORMAL;
        end else begin
          next_band = TEMP_COLD;
        end
      end
      TEMP_HOT: begin
        if (temp_celsius_i <= 8'd83) begin
          next_band = TEMP_NORMAL;
        end else begin
          next_band = TEMP_HOT;
        end
      end
      default: begin
        if (temp_celsius_i < 8'd45) begin
          next_band = TEMP_COLD;
        end else if (temp_celsius_i > 8'd85) begin
          next_band = TEMP_HOT;
        end else begin
          next_band = TEMP_NORMAL;
        end
      end
    endcase
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin : g_band
    if (!rst_ni) begin
      band_q <= TEMP_NORMAL;
    end else begin
      band_q <= next_band;
    end
  end

  assign temp_band_o = band_q;

  always_comb begin : g_trefi
    unique case (temp_band_o)
      TEMP_COLD: trefi_cycles_o = 16'(TREFI_COLD);
      TEMP_HOT:  trefi_cycles_o = 16'(TREFI_HOT);
      default:   trefi_cycles_o = 16'(TREFI_BASE);
    endcase
  end

endmodule : hbm4_ctrl_trefi_ctrl

`default_nettype wire
