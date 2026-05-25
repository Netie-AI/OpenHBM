// Copyright 2026 The Netie Open HBM Authors
// SPDX-License-Identifier: Apache-2.0
//
// AXI4 slave: AW/AR FIFO depth 4, INCR bursts; WRAP/FIXED → DECERR on B/R.
// Bridges to core req_* one beat at a time; wready requires AW FIFO non-empty.
`default_nettype none
`timescale 1ns/1ps

module hbm4_ctrl_axi4_slave #(
    parameter int unsigned P_AXI_ID_W     = hbm4_ctrl_pkg::AXI_ID_W,
    parameter int unsigned P_AXI_ADDR_W = hbm4_ctrl_pkg::AXI_ADDR_W,
    parameter int unsigned P_AXI_DATA_W = hbm4_ctrl_pkg::AXI_DATA_W,
    parameter int unsigned P_ROW_W       = hbm4_ctrl_pkg::ROW_W,
    parameter int unsigned P_COL_W       = hbm4_ctrl_pkg::COL_W,
    parameter int unsigned P_BANK_GROUPS = hbm4_ctrl_pkg::BANK_GROUPS,
    parameter int unsigned P_BANKS_PER_BG = hbm4_ctrl_pkg::BANKS_PER_BG,
    parameter int unsigned P_FIFO_D = 4
) (
    input logic clk_i,
    input logic rst_ni,

    input  logic [P_AXI_ID_W-1:0]    awid_i,
    input  logic [P_AXI_ADDR_W-1:0]  awaddr_i,
    input  logic [7:0]               awlen_i,
    input  logic [2:0]               awsize_i,
    input  logic [1:0]               awburst_i,
    input  logic [3:0]               awqos_i,
    input  logic                     awvalid_i,
    output logic                     awready_o,

    input  logic [P_AXI_DATA_W-1:0]   wdata_i,
    input  logic [P_AXI_DATA_W/8-1:0] wstrb_i,
    input  logic                      wlast_i,
    input  logic                      wvalid_i,
    output logic                      wready_o,

    output logic [P_AXI_ID_W-1:0] bid_o,
    output logic [1:0]            bresp_o,
    output logic                  bvalid_o,
    input  logic                  bready_i,

    input  logic [P_AXI_ID_W-1:0]   arid_i,
    input  logic [P_AXI_ADDR_W-1:0] araddr_i,
    input  logic [7:0]              arlen_i,
    input  logic [2:0]              arsize_i,
    input  logic [1:0]              arburst_i,
    input  logic [3:0]              arqos_i,
    input  logic                    arvalid_i,
    output logic                    arready_o,

    output logic [P_AXI_ID_W-1:0]   rid_o,
    output logic [P_AXI_DATA_W-1:0] rdata_o,
    output logic [1:0]              rresp_o,
    output logic                    rlast_o,
    output logic                    rvalid_o,
    input  logic                    rready_i,

    output logic                      core_req_valid_o,
    output hbm4_ctrl_pkg::bank_addr_t core_req_bank_o,
    output logic [P_ROW_W-1:0]        core_req_row_o,
    output logic [P_COL_W-1:0]        core_req_col_o,
    output logic                      core_req_we_o,
    input  logic                      core_req_ready_i,

    input logic                    cmd_fire_i,
    input hbm4_ctrl_pkg::cmd_e     cmd_i,
    input hbm4_ctrl_pkg::bank_addr_t cmd_bank_i,

    output logic [1:0]             qos_class_o
);

  import hbm4_ctrl_pkg::*;
  import hbm4_ctrl_axi4_pkg::*;

  localparam int unsigned BankPerBgW = $clog2(P_BANKS_PER_BG);
  localparam int unsigned BankGroupW = $clog2(P_BANK_GROUPS);
  localparam int unsigned PtrW       = $clog2(P_FIFO_D);
  // verilog_lint: waive parameter-name-style -- explicit int depth for AW/AR ready (avoid PtrW'(P_FIFO_D) truncation)
  localparam int unsigned FIFO_DEPTH_INT = P_FIFO_D;

  typedef struct packed {
    logic [P_AXI_ID_W-1:0]    id;
    logic [P_AXI_ADDR_W-1:0] addr;
    logic [7:0]               len;
    logic [2:0]               size;
    logic [1:0]               burst;
    logic [1:0]               qos;
    logic                     illegal;
  } ax_desc_t;

  function automatic bank_addr_t addr_to_bank(logic [P_AXI_ADDR_W-1:0] a);
    logic [BankGroupW-1:0] bg;
    logic [BankPerBgW-1:0] bk;
    bg = a[P_COL_W + BankPerBgW + BankGroupW - 1 : P_COL_W + BankPerBgW];
    bk = a[P_COL_W + BankPerBgW - 1 : P_COL_W];
    return bank_addr_t'(bg * bank_addr_t'(P_BANKS_PER_BG) + bank_addr_t'(bk));
  endfunction

  function automatic logic [P_ROW_W-1:0] addr_to_row(logic [P_AXI_ADDR_W-1:0] a);
    return a[P_COL_W + BankPerBgW + BankGroupW + P_ROW_W - 1 : P_COL_W + BankPerBgW + BankGroupW];
  endfunction

  function automatic logic [P_COL_W-1:0] col_beat(
      logic [P_AXI_ADDR_W-1:0] base_addr,
      logic [7:0]              beat,
      logic [2:0]              axsize
  );
    logic [31:0] inc;
    logic [31:0] sum;
    logic [P_COL_W-1:0] basec;
    basec = base_addr[P_COL_W-1:0];
    inc   = 32'd1 << axsize;
    sum   = {24'h0, basec} + beat * inc;
    return sum[P_COL_W-1:0];
  endfunction

  ax_desc_t [P_FIFO_D-1:0] aw_mem;
  ax_desc_t [P_FIFO_D-1:0] ar_mem;
  logic [PtrW-1:0]         aw_rp, aw_wp;
  logic [PtrW-1:0]         ar_rp, ar_wp;
  logic [$clog2(P_FIFO_D+1):0] aw_lvl;
  logic [$clog2(P_FIFO_D+1):0] ar_lvl;

  assign awready_o = (aw_lvl < FIFO_DEPTH_INT);
  assign arready_o = (ar_lvl < FIFO_DEPTH_INT);

  typedef enum logic [3:0] {
    S_IDLE,
    S_W_START,
    S_W_WAIT_W,
    S_W_ISSUE,
    S_W_WAIT0,
    S_W_WAIT_CMD,
    S_W_GAP,
    S_W_B,
    S_W_DECERR,
    S_R_START,
    S_R_ISSUE,
    S_R_WAIT0,
    S_R_WAIT_CMD,
    S_R_DRIVE,
    S_R_ILGL
  } st_e;

  st_e st_q;

  ax_desc_t txn;
  logic [7:0] beat;
  logic aw_push;
  logic ar_push;

  assign aw_push = awvalid_i && awready_o;
  assign ar_push = arvalid_i && arready_o;

  logic fifo_pop_aw_c;
  logic fifo_pop_ar_c;

  always_comb begin : g_fifo_pop
    fifo_pop_aw_c = 1'b0;
    fifo_pop_ar_c = 1'b0;
    if (st_q == S_W_DECERR) begin
      if (wvalid_i && (aw_lvl > '0) && wlast_i) begin
        fifo_pop_aw_c = 1'b1;
      end
    end else if (st_q == S_W_WAIT_CMD) begin
      if (cmd_fire_i && (cmd_i == WR) && (cmd_bank_i == addr_to_bank(txn.addr)) &&
          (beat == txn.len)) begin
        fifo_pop_aw_c = 1'b1;
      end
    end
    if (st_q == S_R_DRIVE) begin
      if (rvalid_o && rready_i && rlast_o) begin
        fifo_pop_ar_c = 1'b1;
      end
    end else if (st_q == S_R_ILGL) begin
      if (rvalid_o && rready_i) begin
        fifo_pop_ar_c = 1'b1;
      end
    end
  end

  logic [$clog2(P_FIFO_D+1):0] aw_lvl_next_c;
  logic [PtrW-1:0]         aw_wp_next_c;
  logic [PtrW-1:0]         aw_rp_next_c;
  logic                    aw_mem_we_c;
  logic [PtrW-1:0]         aw_mem_waddr_c;
  ax_desc_t                 aw_mem_wdata_c;

  logic [$clog2(P_FIFO_D+1):0] ar_lvl_next_c;
  logic [PtrW-1:0]         ar_wp_next_c;
  logic [PtrW-1:0]         ar_rp_next_c;
  logic                    ar_mem_we_c;
  logic [PtrW-1:0]         ar_mem_waddr_c;
  ax_desc_t                 ar_mem_wdata_c;

  always_comb begin : g_aw_fifo_next
    aw_lvl_next_c   = aw_lvl;
    aw_wp_next_c    = aw_wp;
    aw_rp_next_c    = aw_rp;
    aw_mem_we_c     = 1'b0;
    aw_mem_waddr_c  = aw_wp;
    aw_mem_wdata_c  = '0;
    if (aw_push) begin
      aw_lvl_next_c  = aw_lvl_next_c + PtrW'(1);
      aw_wp_next_c   = aw_wp + PtrW'(1);
      aw_mem_we_c    = 1'b1;
      aw_mem_waddr_c = aw_wp;
      aw_mem_wdata_c = '{
          id: awid_i,
          addr: awaddr_i,
          len: awlen_i,
          size: awsize_i,
          burst: awburst_i,
          qos: awqos_i[3:2],
          illegal: (awburst_i != BURST_INCR)
      };
    end
    if (fifo_pop_aw_c) begin
      aw_lvl_next_c = aw_lvl_next_c - PtrW'(1);
      aw_rp_next_c  = aw_rp + PtrW'(1);
    end
  end

  always_comb begin : g_ar_fifo_next
    ar_lvl_next_c   = ar_lvl;
    ar_wp_next_c    = ar_wp;
    ar_rp_next_c    = ar_rp;
    ar_mem_we_c     = 1'b0;
    ar_mem_waddr_c  = ar_wp;
    ar_mem_wdata_c  = '0;
    if (ar_push) begin
      ar_lvl_next_c  = ar_lvl_next_c + PtrW'(1);
      ar_wp_next_c   = ar_wp + PtrW'(1);
      ar_mem_we_c    = 1'b1;
      ar_mem_waddr_c = ar_wp;
      ar_mem_wdata_c = '{
          id: arid_i,
          addr: araddr_i,
          len: arlen_i,
          size: arsize_i,
          burst: arburst_i,
          qos: arqos_i[3:2],
          illegal: (arburst_i != BURST_INCR)
      };
    end
    if (fifo_pop_ar_c) begin
      ar_lvl_next_c = ar_lvl_next_c - PtrW'(1);
      ar_rp_next_c  = ar_rp + PtrW'(1);
    end
  end

  always_comb begin : g_wready
    wready_o = 1'b0;
    unique case (st_q)
      S_W_WAIT_W, S_W_DECERR: wready_o = (aw_lvl > '0);
      default:                wready_o = 1'b0;
    endcase
  end

  assign qos_class_o =
      (st_q inside {S_W_ISSUE, S_W_WAIT0, S_W_WAIT_CMD, S_W_GAP, S_W_B}) ? txn.qos :
      (st_q inside {S_R_ISSUE, S_R_WAIT0, S_R_WAIT_CMD, S_R_DRIVE}) ? txn.qos :
      (awvalid_i ? awqos_i[3:2] : arqos_i[3:2]);

  always_comb begin : g_core_req
    core_req_valid_o = 1'b0;
    core_req_we_o    = 1'b0;
    core_req_bank_o  = '0;
    core_req_row_o   = '0;
    core_req_col_o   = '0;
    unique case (st_q)
      S_W_ISSUE: begin
        core_req_valid_o = 1'b1;
        core_req_we_o    = 1'b1;
        core_req_bank_o  = addr_to_bank(txn.addr);
        core_req_row_o   = addr_to_row(txn.addr);
        core_req_col_o   = col_beat(txn.addr, beat, txn.size);
      end
      S_R_ISSUE: begin
        core_req_valid_o = 1'b1;
        core_req_we_o    = 1'b0;
        core_req_bank_o  = addr_to_bank(txn.addr);
        core_req_row_o   = addr_to_row(txn.addr);
        core_req_col_o   = col_beat(txn.addr, beat, txn.size);
      end
      default: ;
    endcase
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin : g_regs
    if (!rst_ni) begin
      st_q     <= S_IDLE;
      beat     <= '0;
      aw_rp    <= '0;
      aw_wp    <= '0;
      aw_lvl   <= '0;
      ar_rp    <= '0;
      ar_wp    <= '0;
      ar_lvl   <= '0;
      bvalid_o <= 1'b0;
      bid_o    <= '0;
      bresp_o  <= RESP_OKAY;
      rvalid_o <= 1'b0;
      rid_o    <= '0;
      rdata_o  <= '0;
      rresp_o  <= RESP_OKAY;
      rlast_o  <= 1'b0;
    end else begin

      unique case (st_q)
        S_IDLE: begin
          bvalid_o <= 1'b0;
          rvalid_o <= 1'b0;
          if (aw_lvl > '0) begin
            txn  <= aw_mem[aw_rp];
            beat <= '0;
            st_q <= S_W_START;
          end else if (ar_lvl > '0) begin
            txn  <= ar_mem[ar_rp];
            beat <= '0;
            st_q <= S_R_START;
          end
        end

        S_W_START: begin
          if (txn.illegal) begin
            st_q <= S_W_DECERR;
          end else begin
            st_q <= S_W_WAIT_W;
          end
        end

        S_W_DECERR: begin
          if (wvalid_i && wready_o && wlast_i) begin
            bid_o    <= txn.id;
            bresp_o  <= RESP_DECERR;
            bvalid_o <= 1'b1;
            st_q     <= S_W_B;
          end
        end

        S_W_WAIT_W: begin
          if (wvalid_i && wready_o) begin
            st_q <= S_W_ISSUE;
          end
        end

        S_W_ISSUE: begin
          if (core_req_ready_i) begin
            st_q <= S_W_WAIT0;
          end
        end

        S_W_WAIT0: begin
          st_q <= S_W_WAIT_CMD;
        end

        S_W_WAIT_CMD: begin
          if (cmd_fire_i && (cmd_i == WR) && (cmd_bank_i == addr_to_bank(txn.addr))) begin
            if (beat == txn.len) begin
              bid_o    <= txn.id;
              bresp_o  <= RESP_OKAY;
              bvalid_o <= 1'b1;
              st_q     <= S_W_B;
            end else begin
              beat <= beat + 8'd1;
              st_q <= S_W_GAP;
            end
          end
        end

        S_W_GAP: begin
          st_q <= S_W_WAIT_W;
        end

        S_W_B: begin
          if (bvalid_o && bready_i) begin
            bvalid_o <= 1'b0;
            st_q     <= S_IDLE;
          end
        end

        S_R_START: begin
          if (txn.illegal) begin
            rid_o    <= txn.id;
            rdata_o  <= '0;
            rresp_o  <= RESP_DECERR;
            rlast_o  <= 1'b1;
            rvalid_o <= 1'b1;
            st_q     <= S_R_ILGL;
          end else begin
            st_q <= S_R_ISSUE;
          end
        end

        S_R_ISSUE: begin
          if (core_req_ready_i) begin
            st_q <= S_R_WAIT0;
          end
        end

        S_R_WAIT0: begin
          st_q <= S_R_WAIT_CMD;
        end

        S_R_WAIT_CMD: begin
          if (cmd_fire_i && (cmd_i == RD) && (cmd_bank_i == addr_to_bank(txn.addr))) begin
            rid_o    <= txn.id;
            rdata_o  <= {{(P_AXI_DATA_W - P_ROW_W - P_COL_W - 8) {1'b0}},
                addr_to_row(txn.addr), col_beat(txn.addr, beat, txn.size), beat};
            rresp_o  <= RESP_OKAY;
            rlast_o  <= (beat == txn.len);
            rvalid_o <= 1'b1;
            st_q     <= S_R_DRIVE;
          end
        end

        S_R_DRIVE: begin
          if (rvalid_o && rready_i) begin
            rvalid_o <= 1'b0;
            if (rlast_o) begin
              st_q <= S_IDLE;
            end else begin
              beat <= beat + 8'd1;
              st_q <= S_R_ISSUE;
            end
          end
        end

        S_R_ILGL: begin
          if (rvalid_o && rready_i) begin
            rvalid_o <= 1'b0;
            st_q     <= S_IDLE;
          end
        end

        default: st_q <= S_IDLE;
      endcase

      aw_lvl <= aw_lvl_next_c;
      aw_wp  <= aw_wp_next_c;
      aw_rp  <= aw_rp_next_c;
      if (aw_mem_we_c) begin
        aw_mem[aw_mem_waddr_c] <= aw_mem_wdata_c;
      end

      ar_lvl <= ar_lvl_next_c;
      ar_wp  <= ar_wp_next_c;
      ar_rp  <= ar_rp_next_c;
      if (ar_mem_we_c) begin
        ar_mem[ar_mem_waddr_c] <= ar_mem_wdata_c;
      end
    end
  end

endmodule : hbm4_ctrl_axi4_slave

`default_nettype wire
