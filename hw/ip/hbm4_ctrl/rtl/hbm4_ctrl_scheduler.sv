// Copyright 2026 The Netie Open HBM Authors
// SPDX-License-Identifier: Apache-2.0
//
// Per-channel command scheduler: DWRR across four QoS classes, round-robin within class.
`default_nettype none
`timescale 1ns/1ps

module hbm4_ctrl_scheduler #(
    parameter int unsigned P_NUM_BANKS = hbm4_ctrl_pkg::NUM_BANKS
) (
    input  logic                                       clk_i,
    input  logic                                       rst_ni,
    input  logic [P_NUM_BANKS-1:0]                      bank_cmd_valid_i,
    input  hbm4_ctrl_pkg::cmd_e [P_NUM_BANKS-1:0]       bank_cmd_i,
    input  hbm4_ctrl_pkg::row_t [P_NUM_BANKS-1:0]       bank_cmd_row_i,
    input  hbm4_ctrl_pkg::col_t [P_NUM_BANKS-1:0]       bank_cmd_col_i,
    input  hbm4_ctrl_pkg::qos_class_e [P_NUM_BANKS-1:0] bank_qos_i,
    input  logic                                       page_policy_i,
    output logic                                       cmd_valid_o,
    output hbm4_ctrl_pkg::cmd_e                         cmd_o,
    output hbm4_ctrl_pkg::bank_addr_t                 cmd_bank_o,
    output hbm4_ctrl_pkg::row_t                        cmd_row_o,
    output hbm4_ctrl_pkg::col_t                        cmd_col_o,
    input  logic                                       cmd_accepted_i,
    output logic [P_NUM_BANKS-1:0]                    bank_cmd_accepted_o,
    output logic                                       qos_starvation_o
);

  import hbm4_ctrl_pkg::*;

  localparam int unsigned StarvCntW = $clog2(QosStarvationLimit + 1) + 1;

  logic [7:0]              deficit_counter_q [4];
  logic [StarvCntW-1:0]    starvation_cnt_q;
  qos_class_e              current_class_q;
  bank_addr_t              rr_q;

  logic [3:0]              class_pending;
  logic                    force_p3;
  qos_class_e              serve_class;
  bank_addr_t              win_id;
  logic                    found;

  logic [7:0]              deficit_counter_n [4];
  logic [StarvCntW-1:0]    starvation_cnt_n;
  qos_class_e              current_class_n;
  bank_addr_t              rr_n;
  logic                    qos_starvation_n;
  logic                    served_p3;

  function automatic logic [7:0] qos_weight(qos_class_e cls);
    unique case (cls)
      QOS_P0: qos_weight = 8'(QosW0);
      QOS_P1: qos_weight = 8'(QosW1);
      QOS_P2: qos_weight = 8'(QosW2);
      default: qos_weight = 8'(QosW3);
    endcase
  endfunction

  function automatic qos_class_e qos_next(qos_class_e cls);
    return qos_class_e'(cls + qos_class_e'(1));
  endfunction

  always_comb begin : g_class_pending
    class_pending = 4'b0000;
    for (int unsigned bb = 0; bb < P_NUM_BANKS; bb++) begin
      if (bank_cmd_valid_i[bb]) begin
        class_pending[bank_qos_i[bb]] = 1'b1;
      end
    end
  end

  always_comb begin : g_serve_class
    force_p3    = (starvation_cnt_q >= StarvCntW'(QosStarvationLimit)) && class_pending[QOS_P3];
    serve_class = current_class_q;
    if (force_p3) begin
      serve_class = QOS_P3;
    end else begin
      logic picked;
      picked = 1'b0;
      for (int unsigned ii = 0; ii < 4; ii++) begin
        qos_class_e cand;
        cand = qos_class_e'(current_class_q + qos_class_e'(ii));
        if (!picked && class_pending[cand] && (deficit_counter_q[cand] != 8'd0)) begin
          serve_class = cand;
          picked      = 1'b1;
        end
      end
      if (!picked) begin
        for (int unsigned jj = 0; jj < 4; jj++) begin
          qos_class_e cand2;
          cand2 = qos_class_e'(current_class_q + qos_class_e'(jj));
          if (!picked && class_pending[cand2]) begin
            serve_class = cand2;
            picked      = 1'b1;
          end
        end
      end
    end
  end

  always_comb begin : g_pick
    found  = 1'b0;
    win_id = rr_q;
    for (int unsigned ii = 0; ii < P_NUM_BANKS; ii++) begin
      bank_addr_t cand;
      cand = bank_addr_t'(rr_q + bank_addr_t'(ii));
      if (!found && bank_cmd_valid_i[cand] && (bank_qos_i[cand] == serve_class)) begin
        win_id = cand;
        found  = 1'b1;
      end
    end
  end

  assign cmd_valid_o = found;
  assign cmd_o       = found ? bank_cmd_i[win_id] : IDLE_CMD;
  assign cmd_row_o   = found ? bank_cmd_row_i[win_id] : '0;
  assign cmd_col_o   = found ? bank_cmd_col_i[win_id] : '0;
  assign cmd_bank_o  = win_id;

  always_comb begin : g_acc
    bank_cmd_accepted_o = '0;
    if (found && cmd_accepted_i) begin
      bank_cmd_accepted_o[win_id] = 1'b1;
    end
  end

  always_comb begin : g_next
    deficit_counter_n  = deficit_counter_q;
    starvation_cnt_n   = starvation_cnt_q;
    current_class_n    = current_class_q;
    rr_n               = rr_q;
    qos_starvation_n   = (starvation_cnt_q >= StarvCntW'(QosStarvationLimit));
    served_p3          = found && cmd_accepted_i && (serve_class == QOS_P3);

    if (found && cmd_accepted_i) begin
      rr_n = bank_addr_t'(win_id + bank_addr_t'(1));
      if (deficit_counter_q[serve_class] != 8'd0) begin
        deficit_counter_n[serve_class] = deficit_counter_q[serve_class] - 8'd1;
      end
      if (deficit_counter_n[serve_class] == 8'd0) begin
        qos_class_e nxt;
        nxt = qos_next(serve_class);
        current_class_n = nxt;
        deficit_counter_n[nxt] = deficit_counter_q[nxt] + qos_weight(nxt);
      end
    end else if (!found && |class_pending) begin
      qos_class_e nxt2;
      logic       adv;
      adv = 1'b0;
      for (int unsigned kk = 0; kk < 4; kk++) begin
        qos_class_e cand3;
        cand3 = qos_class_e'(current_class_q + qos_class_e'(kk));
        if (!adv && class_pending[cand3]) begin
          nxt2            = qos_next(cand3);
          current_class_n = nxt2;
          adv             = 1'b1;
        end
      end
    end

    if (served_p3) begin
      starvation_cnt_n = '0;
    end else if (starvation_cnt_q < StarvCntW'(QosStarvationLimit)) begin
      starvation_cnt_n = starvation_cnt_q + StarvCntW'(1);
    end

    qos_starvation_n = (starvation_cnt_n >= StarvCntW'(QosStarvationLimit));

    // P9: closed-page PRE after RD/WR when page_policy_i==1
    if (page_policy_i) begin
      ;  // stub — bank_fsm force_pre integration in P9
    end
  end

  assign qos_starvation_o = qos_starvation_n;

  always_ff @(posedge clk_i or negedge rst_ni) begin : g_regs
    if (!rst_ni) begin
      rr_q <= '0;
      current_class_q <= QOS_P0;
      starvation_cnt_q <= '0;
      deficit_counter_q[0] <= 8'(QosW0);
      deficit_counter_q[1] <= 8'(QosW1);
      deficit_counter_q[2] <= 8'(QosW2);
      deficit_counter_q[3] <= 8'(QosW3);
    end else begin
      rr_q             <= rr_n;
      current_class_q  <= current_class_n;
      starvation_cnt_q <= starvation_cnt_n;
      deficit_counter_q[0] <= deficit_counter_n[0];
      deficit_counter_q[1] <= deficit_counter_n[1];
      deficit_counter_q[2] <= deficit_counter_n[2];
      deficit_counter_q[3] <= deficit_counter_n[3];
    end
  end

endmodule : hbm4_ctrl_scheduler
