// Copyright 2026 The Netie Open HBM Authors
// SPDX-License-Identifier: Apache-2.0
//
// Per-channel activity monitor: throttle, gated power-down suggestion, page policy.
`default_nettype none
`timescale 1ns/1ps

module hbm4_ctrl_pmu
  import hbm4_ctrl_pkg::*;
(
    input  logic                    clk_i,
    input  logic                    rst_ni,

    input  logic                    cmd_valid_i,

    output logic                    pwrdn_req_o,
    output logic                    sref_req_o,
    output logic                    page_policy_o,
    output logic                    throttle_o,

    output logic [PmuCtrW-1:0]      activity_cnt_o,
    output hbm4_ctrl_pkg::pmu_state_e pmu_state_o
);

  pmu_state_e           state_q;
  logic [PmuCtrW-1:0] window_cnt_q;
  logic [PmuCtrW-1:0] active_cnt_q;
  logic [PmuCtrW-1:0] idle_run_q;

  pmu_state_e           state_d;

  always_comb begin
    state_d = state_q;
    unique case (state_q)
      PMU_NORMAL:
        if ((active_cnt_q >= PmuCtrW'(PmuThreshold)) &&
            (window_cnt_q == PmuCtrW'(PmuWindow - 1))) begin
          state_d = PMU_THROTTLE;
        end else if (idle_run_q >= PmuCtrW'(PmuIdleCnt)) begin
          state_d = PMU_GATED;
        end
      PMU_THROTTLE:
        if (window_cnt_q == PmuCtrW'(PmuWindow - 1)) begin
          state_d = PMU_NORMAL;
        end
      PMU_GATED:
        if (cmd_valid_i) begin
          state_d = PMU_NORMAL;
        end
      default: state_d = PMU_NORMAL;
    endcase
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      state_q      <= PMU_NORMAL;
      window_cnt_q <= '0;
      active_cnt_q <= '0;
      idle_run_q   <= '0;
    end else begin
      state_q <= state_d;

      if (window_cnt_q == PmuCtrW'(PmuWindow - 1)) begin
        window_cnt_q <= '0;
        active_cnt_q <= '0;
      end else begin
        window_cnt_q <= window_cnt_q + PmuCtrW'(1);
        if (cmd_valid_i) begin
          active_cnt_q <= active_cnt_q + PmuCtrW'(1);
        end
      end

      if (cmd_valid_i) begin
        idle_run_q <= '0;
      end else if (idle_run_q != PmuCtrW'({PmuCtrW{1'b1}})) begin
        idle_run_q <= idle_run_q + PmuCtrW'(1);
      end
    end
  end

  assign pmu_state_o    = state_q;
  assign activity_cnt_o = active_cnt_q;
  assign throttle_o     = (state_q == PMU_THROTTLE);

  assign pwrdn_req_o   = (state_q == PMU_GATED) && !cmd_valid_i;
  assign sref_req_o    = 1'b0;
  assign page_policy_o = (state_q == PMU_THROTTLE);

endmodule : hbm4_ctrl_pmu

`default_nettype wire
