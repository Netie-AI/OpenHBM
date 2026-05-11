// Copyright 2026 The Netie Open HBM Authors
// SPDX-License-Identifier: Apache-2.0
`default_nettype none
`timescale 1ns/1ps

// Directed stimulus for mutation testing (Icarus / vvp).
module stim_refresh;

  logic        clk;
  logic        rst_n;
  logic        act_valid_i;
  logic [1:0]  act_bg_i;
  logic [1:0]  act_ba_i;
  logic [16:0] act_row_i;
  logic        trefw_tick_i;
  logic        credit_release_i;
  logic        drfm_pending_o;
  logic [1:0]  drfm_target_bg_o;
  logic [1:0]  drfm_target_ba_o;
  logic [16:0] drfm_target_row_o;
  logic        drfm_ack_i;
  logic        prac_overflow_alert_o;

  logic [31:0] pend_streak;

  refresh_mgr #(
      .PracThresh(24),
      .PracTopK  (64),
      .NumBanks  (16),
      .CreditMax (4),
      .RowW      (17),
      .BgW       (2),
      .BaW       (2),
      .CountW    (16)
  ) dut (
      .clk_i                 (clk),
      .rst_ni                (rst_n),
      .act_valid_i           (act_valid_i),
      .act_bg_i              (act_bg_i),
      .act_ba_i              (act_ba_i),
      .act_row_i             (act_row_i),
      .trefw_tick_i          (trefw_tick_i),
      .credit_release_i      (credit_release_i),
      .drfm_pending_o        (drfm_pending_o),
      .drfm_target_bg_o      (drfm_target_bg_o),
      .drfm_target_ba_o      (drfm_target_ba_o),
      .drfm_target_row_o     (drfm_target_row_o),
      .drfm_ack_i            (drfm_ack_i),
      .prac_overflow_alert_o (prac_overflow_alert_o)
  );

  initial clk = 1'b0;
  always #5 clk = ~clk;

  always_ff @(posedge clk or negedge rst_n) begin : ppend
    if (!rst_n) begin
      pend_streak <= '0;
    end else begin
      if (drfm_pending_o && !drfm_ack_i) pend_streak <= pend_streak + 1'b1;
      else begin
        pend_streak <= '0;
      end
    end
  end

  typedef int unsigned drv_t;

  initial begin : main
    rst_n            = 1'b0;
    act_valid_i      = 1'b0;
    act_bg_i         = '0;
    act_ba_i         = '0;
    act_row_i        = '0;
    trefw_tick_i     = 1'b0;
    credit_release_i = 1'b0;
    drfm_ack_i       = 1'b0;
    repeat (8) @(posedge clk);
    rst_n = 1'b1;
    repeat (2) @(posedge clk);

    for (drv_t cy = 0; cy < 1024; cy++) begin
      trefw_tick_i     <= 1'b0;
      credit_release_i <= 1'b0;
      drfm_ack_i       <= 1'b0;
      act_valid_i      <= 1'b0;

      unique case (cy % 61)
        0: begin
          trefw_tick_i <= 1'b1;
        end
        default: begin
          act_row_i   <= 17'd101;
          act_bg_i    <= 2'h0;
          act_ba_i    <= 2'h0;
          act_valid_i <= 1'b1;
        end
      endcase
      if ((cy % 13) == 7) credit_release_i <= 1'b1;

      @(posedge clk);

      if (pend_streak > 32'd240) begin
        $display("FAIL: pending stuck too long");
        $finish_and_return(1);
      end

      // Fair ack on pending (helps close mutants that drop handshake)
      if (drfm_pending_o && ((cy % 4) == 1)) begin
        drfm_ack_i <= 1'b1;
        @(posedge clk);
      end
    end

    $display("PASS: stim_refresh");
    $finish_and_return(0);
  end
endmodule : stim_refresh
