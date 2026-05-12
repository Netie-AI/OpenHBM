`default_nettype none
module refresh_mgr_liveness_wrapper;
	localparam [31:0] FormalK = 8;
	localparam [31:0] FormalThresh = 8;
	localparam [31:0] FormalCredMax = 2;
	localparam [31:0] T_REFI_CYCLES = 48;
	localparam [31:0] PendBound = 96;
	reg rst_ni;
	wire clk_i;
	wire act_valid_i;
	localparam [31:0] refresh_mgr_pkg_BgW = 2;
	wire [1:0] act_bg_i;
	localparam [31:0] refresh_mgr_pkg_BaW = 2;
	wire [1:0] act_ba_i;
	localparam [31:0] refresh_mgr_pkg_RowW = 17;
	wire [16:0] act_row_i;
	wire trefw_tick_i;
	wire credit_release_i;
	wire drfm_pending_o;
	wire [1:0] drfm_target_bg_o;
	wire [1:0] drfm_target_ba_o;
	wire [16:0] drfm_target_row_o;
	wire drfm_ack_i;
	wire prac_overflow_alert_o;
	reg [7:0] ph;
	reg [15:0] pend_streak;
	function automatic [7:0] sv2v_cast_8;
		input reg [7:0] inp;
		sv2v_cast_8 = inp;
	endfunction
	always @(posedge clk_i or negedge rst_ni) begin : g_ph
		if (!rst_ni)
			ph <= 1'sb0;
		else if (ph == sv2v_cast_8(47))
			ph <= 1'sb0;
		else
			ph <= ph + 8'h01;
	end
	assign trefw_tick_i = rst_ni && (ph == 8'h00);
	localparam [31:0] refresh_mgr_pkg_CountW = 16;
	refresh_mgr #(
		.PracThresh(FormalThresh),
		.PracTopK(FormalK),
		.NumBanks(4),
		.CreditMax(FormalCredMax),
		.RowW(refresh_mgr_pkg_RowW),
		.BgW(refresh_mgr_pkg_BgW),
		.BaW(refresh_mgr_pkg_BaW),
		.CountW(refresh_mgr_pkg_CountW)
	) dut(
		.clk_i(clk_i),
		.rst_ni(rst_ni),
		.act_valid_i(act_valid_i),
		.act_bg_i(act_bg_i),
		.act_ba_i(act_ba_i),
		.act_row_i(act_row_i),
		.trefw_tick_i(trefw_tick_i),
		.credit_release_i(credit_release_i),
		.drfm_pending_o(drfm_pending_o),
		.drfm_target_bg_o(drfm_target_bg_o),
		.drfm_target_ba_o(drfm_target_ba_o),
		.drfm_target_row_o(drfm_target_row_o),
		.drfm_ack_i(drfm_ack_i),
		.prac_overflow_alert_o(prac_overflow_alert_o)
	);
	initial rst_ni = 1'b1;
	always @(posedge clk_i or negedge rst_ni) begin : g_penstr
		if (!rst_ni)
			pend_streak <= 1'sb0;
		else if (drfm_pending_o && !drfm_ack_i)
			pend_streak <= pend_streak + 16'h0001;
		else
			pend_streak <= 1'sb0;
	end
endmodule
module abs_bank_machine;
	
endmodule
`default_nettype none
`default_nettype none
module refresh_mgr (
	clk_i,
	rst_ni,
	act_valid_i,
	act_bg_i,
	act_ba_i,
	act_row_i,
	trefw_tick_i,
	credit_release_i,
	drfm_pending_o,
	drfm_target_bg_o,
	drfm_target_ba_o,
	drfm_target_row_o,
	drfm_ack_i,
	prac_overflow_alert_o
);
	parameter [31:0] PracThresh = 1024;
	localparam [31:0] refresh_mgr_pkg_PracTopK = 64;
	parameter [31:0] PracTopK = refresh_mgr_pkg_PracTopK;
	localparam [31:0] refresh_mgr_pkg_NumBanks = 16;
	parameter [31:0] NumBanks = refresh_mgr_pkg_NumBanks;
	localparam [31:0] refresh_mgr_pkg_CreditMax = 4;
	parameter [31:0] CreditMax = refresh_mgr_pkg_CreditMax;
	localparam [31:0] refresh_mgr_pkg_RowW = 17;
	parameter [31:0] RowW = refresh_mgr_pkg_RowW;
	localparam [31:0] refresh_mgr_pkg_BgW = 2;
	parameter [31:0] BgW = refresh_mgr_pkg_BgW;
	localparam [31:0] refresh_mgr_pkg_BaW = 2;
	parameter [31:0] BaW = refresh_mgr_pkg_BaW;
	localparam [31:0] refresh_mgr_pkg_CountW = 16;
	parameter [31:0] CountW = refresh_mgr_pkg_CountW;
	input wire clk_i;
	input wire rst_ni;
	input wire act_valid_i;
	input wire [BgW - 1:0] act_bg_i;
	input wire [BaW - 1:0] act_ba_i;
	input wire [RowW - 1:0] act_row_i;
	input wire trefw_tick_i;
	input wire credit_release_i;
	output reg drfm_pending_o;
	output reg [BgW - 1:0] drfm_target_bg_o;
	output reg [BaW - 1:0] drfm_target_ba_o;
	output reg [RowW - 1:0] drfm_target_row_o;
	input wire drfm_ack_i;
	output reg prac_overflow_alert_o;
	function automatic [CountW - 1:0] sv2v_cast_30147;
		input reg [CountW - 1:0] inp;
		sv2v_cast_30147 = inp;
	endfunction
	localparam [CountW - 1:0] ThreshW = sv2v_cast_30147(PracThresh);
	reg [((NumBanks * PracTopK) * 34) - 1:0] mem_q;
	reg [CountW - 1:0] credits_q [0:NumBanks - 1];
	reg pending_q;
	reg [BgW - 1:0] lat_bg_q;
	reg [BaW - 1:0] lat_ba_q;
	reg [RowW - 1:0] lat_row_q;
	function automatic signed [31:0] sv2v_cast_32_signed;
		input reg signed [31:0] inp;
		sv2v_cast_32_signed = inp;
	endfunction
	function automatic [31:0] idx_bank;
		input reg [BgW - 1:0] bg;
		input reg [BaW - 1:0] ba;
		idx_bank = sv2v_cast_32_signed({bg, ba});
	endfunction
	function automatic [BaW - 1:0] sv2v_cast_5E202;
		input reg [BaW - 1:0] inp;
		sv2v_cast_5E202 = inp;
	endfunction
	function automatic [BgW - 1:0] sv2v_cast_0B384;
		input reg [BgW - 1:0] inp;
		sv2v_cast_0B384 = inp;
	endfunction
	task automatic scan_hit_mem;
		input reg [((NumBanks * PracTopK) * 34) - 1:0] mem;
		output reg hit;
		output reg [BgW - 1:0] hbg;
		output reg [BaW - 1:0] hba;
		output reg [31:0] hbi;
		output reg [RowW - 1:0] hrow;
		begin
			hit = 1'b0;
			hbg = 1'sb0;
			hba = 1'sb0;
			hbi = 0;
			hrow = 1'sb0;
			begin : sv2v_autoblock_1
				reg [31:0] bk;
				for (bk = 0; bk < NumBanks; bk = bk + 1)
					begin : h_outer
						begin : sv2v_autoblock_2
							reg [31:0] sj;
							for (sj = 0; sj < PracTopK; sj = sj + 1)
								begin : h_inner
									if ((!hit && mem[(((((NumBanks - 1) - bk) * PracTopK) + ((PracTopK - 1) - sj)) * 34) + 33]) && ($unsigned(mem[(((((NumBanks - 1) - bk) * PracTopK) + ((PracTopK - 1) - sj)) * 34) + 15-:refresh_mgr_pkg_CountW]) >= $unsigned(ThreshW))) begin
										hit = 1'b1;
										hbi = bk;
										hrow = mem[(((((NumBanks - 1) - bk) * PracTopK) + ((PracTopK - 1) - sj)) * 34) + 32-:17];
										hba = sv2v_cast_5E202(bk);
										hbg = sv2v_cast_0B384(bk >> BaW);
									end
								end
						end
					end
			end
		end
	endtask
	task automatic tbl_decay_inplace;
		output reg [(PracTopK * 34) - 1:0] slots;
		reg [31:0] uu;
		for (uu = 0; uu < PracTopK; uu = uu + 1)
			begin : g_tw
				if (slots[(((PracTopK - 1) - uu) * 34) + 33] && (slots[(((PracTopK - 1) - uu) * 34) + 15-:refresh_mgr_pkg_CountW] != {16 {1'sb0}})) begin
					slots[(((PracTopK - 1) - uu) * 34) + 15-:refresh_mgr_pkg_CountW] = slots[(((PracTopK - 1) - uu) * 34) + 15-:refresh_mgr_pkg_CountW] - 1;
					if (slots[(((PracTopK - 1) - uu) * 34) + 15-:refresh_mgr_pkg_CountW] == {16 {1'sb0}})
						slots[(((PracTopK - 1) - uu) * 34) + 33] = 1'b0;
				end
			end
	endtask
	task automatic remove_row_inplace;
		output reg [(PracTopK * 34) - 1:0] slots;
		input reg [RowW - 1:0] rr;
		reg [31:0] uu;
		for (uu = 0; uu < PracTopK; uu = uu + 1)
			begin : g_rm
				if (slots[(((PracTopK - 1) - uu) * 34) + 33] && (slots[(((PracTopK - 1) - uu) * 34) + 32-:17] == rr)) begin
					slots[(((PracTopK - 1) - uu) * 34) + 33] = 1'b0;
					slots[(((PracTopK - 1) - uu) * 34) + 15-:refresh_mgr_pkg_CountW] = 1'sb0;
				end
			end
	endtask
	function automatic signed [CountW - 1:0] sv2v_cast_30147_signed;
		input reg signed [CountW - 1:0] inp;
		sv2v_cast_30147_signed = inp;
	endfunction
	task automatic mg_activate_inplace;
		output reg [(PracTopK * 34) - 1:0] slots;
		input reg [RowW - 1:0] r;
		reg [31:0] matched_idx;
		reg [31:0] free_ix;
		reg matched;
		begin
			matched = 1'b0;
			begin : sv2v_autoblock_3
				reg [31:0] uu;
				for (uu = 0; uu < PracTopK; uu = uu + 1)
					begin : g_ma
						if ((!matched && slots[(((PracTopK - 1) - uu) * 34) + 33]) && (slots[(((PracTopK - 1) - uu) * 34) + 32-:17] == r)) begin
							matched = 1'b1;
							matched_idx = uu;
						end
					end
			end
			if (matched) begin
				if ($unsigned(slots[(((PracTopK - 1) - matched_idx) * 34) + 15-:refresh_mgr_pkg_CountW]) < {CountW {1'b1}})
					slots[(((PracTopK - 1) - matched_idx) * 34) + 15-:refresh_mgr_pkg_CountW] = slots[(((PracTopK - 1) - matched_idx) * 34) + 15-:refresh_mgr_pkg_CountW] + 1;
			end
			else begin
				free_ix = PracTopK;
				begin : sv2v_autoblock_4
					reg [31:0] uu;
					for (uu = 0; uu < PracTopK; uu = uu + 1)
						begin : g_fr
							if ((free_ix == PracTopK) && (!slots[(((PracTopK - 1) - uu) * 34) + 33] || (slots[(((PracTopK - 1) - uu) * 34) + 15-:refresh_mgr_pkg_CountW] == {16 {1'sb0}})))
								free_ix = uu;
						end
				end
				if (free_ix != PracTopK) begin
					slots[(((PracTopK - 1) - free_ix) * 34) + 33] = 1'b1;
					slots[(((PracTopK - 1) - free_ix) * 34) + 32-:17] = r;
					slots[(((PracTopK - 1) - free_ix) * 34) + 15-:refresh_mgr_pkg_CountW] = sv2v_cast_30147_signed(1);
				end
				else begin
					begin : sv2v_autoblock_5
						reg [31:0] kk;
						for (kk = 0; kk < PracTopK; kk = kk + 1)
							begin : g_sg
								if (slots[(((PracTopK - 1) - kk) * 34) + 33] && (slots[(((PracTopK - 1) - kk) * 34) + 15-:refresh_mgr_pkg_CountW] != {16 {1'sb0}}))
									slots[(((PracTopK - 1) - kk) * 34) + 15-:refresh_mgr_pkg_CountW] = slots[(((PracTopK - 1) - kk) * 34) + 15-:refresh_mgr_pkg_CountW] - 1;
								if (slots[(((PracTopK - 1) - kk) * 34) + 15-:refresh_mgr_pkg_CountW] == {16 {1'sb0}})
									slots[(((PracTopK - 1) - kk) * 34) + 33] = 1'b0;
							end
					end
					free_ix = PracTopK;
					begin : sv2v_autoblock_6
						reg [31:0] kk2;
						for (kk2 = 0; kk2 < PracTopK; kk2 = kk2 + 1)
							begin : g_fr2
								if ((free_ix == PracTopK) && (!slots[(((PracTopK - 1) - kk2) * 34) + 33] || (slots[(((PracTopK - 1) - kk2) * 34) + 15-:refresh_mgr_pkg_CountW] == {16 {1'sb0}})))
									free_ix = kk2;
							end
					end
					if (free_ix != PracTopK) begin
						slots[(((PracTopK - 1) - free_ix) * 34) + 33] = 1'b1;
						slots[(((PracTopK - 1) - free_ix) * 34) + 32-:17] = r;
						slots[(((PracTopK - 1) - free_ix) * 34) + 15-:refresh_mgr_pkg_CountW] = sv2v_cast_30147_signed(1);
					end
				end
			end
		end
	endtask
	always @(posedge clk_i or negedge rst_ni) begin : g_seq
		if (!rst_ni) begin
			begin : sv2v_autoblock_7
				reg [31:0] bi;
				for (bi = 0; bi < NumBanks; bi = bi + 1)
					begin
						begin : sv2v_autoblock_8
							reg [31:0] sj;
							for (sj = 0; sj < PracTopK; sj = sj + 1)
								mem_q[((((NumBanks - 1) - bi) * PracTopK) + ((PracTopK - 1) - sj)) * 34+:34] <= 1'sb0;
						end
						credits_q[bi] <= sv2v_cast_30147(CreditMax);
					end
			end
			pending_q <= 1'b0;
			lat_bg_q <= 1'sb0;
			lat_ba_q <= 1'sb0;
			lat_row_q <= 1'sb0;
			drfm_pending_o <= 1'b0;
			drfm_target_bg_o <= 1'sb0;
			drfm_target_ba_o <= 1'sb0;
			drfm_target_row_o <= 1'sb0;
			prac_overflow_alert_o <= 1'b0;
		end
		else begin : clk_step_gen
			reg hit_pre_v;
			reg [BgW - 1:0] hit_pre_bg;
			reg [BaW - 1:0] hit_pre_ba;
			reg [RowW - 1:0] hit_pre_row;
			reg [31:0] hit_pre_bi;
			reg start_pend;
			reg [31:0] bk_ix;
			reg [31:0] rb_ix;
			reg hit_post_v;
			reg [BgW - 1:0] hp_bg;
			reg [BaW - 1:0] hp_ba;
			reg [RowW - 1:0] hp_row;
			reg [31:0] hp_bi;
			reg hit_ov_v;
			reg [BgW - 1:0] ov_bg;
			reg [BaW - 1:0] ov_ba;
			reg [RowW - 1:0] ov_row;
			reg [31:0] ov_bi;
			reg [((NumBanks * PracTopK) * 34) - 1:0] wq;
			reg [CountW - 1:0] nc [0:NumBanks - 1];
			reg pend_nxt;
			reg [BgW - 1:0] nlat_bg;
			reg [BaW - 1:0] nlat_ba;
			reg [RowW - 1:0] nlat_rw;
			scan_hit_mem(mem_q, hit_pre_v, hit_pre_bg, hit_pre_ba, hit_pre_bi, hit_pre_row);
			start_pend = pending_q;
			begin : sv2v_autoblock_9
				reg [31:0] bx;
				for (bx = 0; bx < NumBanks; bx = bx + 1)
					begin : g_cp
						begin : sv2v_autoblock_10
							reg [31:0] sy;
							for (sy = 0; sy < PracTopK; sy = sy + 1)
								wq[((((NumBanks - 1) - bx) * PracTopK) + ((PracTopK - 1) - sy)) * 34+:34] = mem_q[((((NumBanks - 1) - bx) * PracTopK) + ((PracTopK - 1) - sy)) * 34+:34];
						end
						nc[bx] = credits_q[bx];
					end
			end
			pend_nxt = pending_q;
			nlat_bg = lat_bg_q;
			nlat_ba = lat_ba_q;
			nlat_rw = lat_row_q;
			if (drfm_ack_i && pending_q) begin
				bk_ix = idx_bank(lat_bg_q, lat_ba_q);
				if ($unsigned(nc[bk_ix]) > 0)
					nc[bk_ix] = nc[bk_ix] - 1;
				remove_row_inplace(wq[34 * (((NumBanks - 1) - bk_ix) * PracTopK)+:34 * PracTopK], lat_row_q);
				pend_nxt = 1'b0;
			end
			if (trefw_tick_i) begin : sv2v_autoblock_11
				reg [31:0] bx;
				for (bx = 0; bx < NumBanks; bx = bx + 1)
					begin
						tbl_decay_inplace(wq[34 * (((NumBanks - 1) - bx) * PracTopK)+:34 * PracTopK]);
						nc[bx] = sv2v_cast_30147(CreditMax);
					end
			end
			else if (credit_release_i) begin
				if (start_pend)
					rb_ix = idx_bank(lat_bg_q, lat_ba_q);
				else if (hit_pre_v)
					rb_ix = hit_pre_bi;
				else
					rb_ix = 1'sb0;
				if ($unsigned(nc[rb_ix]) < $unsigned(sv2v_cast_30147(CreditMax)))
					nc[rb_ix] = nc[rb_ix] + 1;
			end
			if (!trefw_tick_i && act_valid_i) begin
				bk_ix = idx_bank(sv2v_cast_0B384(act_bg_i), sv2v_cast_5E202(act_ba_i));
				mg_activate_inplace(wq[34 * (((NumBanks - 1) - bk_ix) * PracTopK)+:34 * PracTopK], act_row_i);
			end
			scan_hit_mem(wq, hit_post_v, hp_bg, hp_ba, hp_bi, hp_row);
			if ((!pend_nxt && hit_post_v) && ($unsigned(nc[hp_bi]) > 0)) begin
				pend_nxt = 1'b1;
				nlat_bg = hp_bg;
				nlat_ba = hp_ba;
				nlat_rw = hp_row;
			end
			begin : sv2v_autoblock_12
				reg [31:0] bi;
				for (bi = 0; bi < NumBanks; bi = bi + 1)
					begin
						begin : sv2v_autoblock_13
							reg [31:0] sj;
							for (sj = 0; sj < PracTopK; sj = sj + 1)
								mem_q[((((NumBanks - 1) - bi) * PracTopK) + ((PracTopK - 1) - sj)) * 34+:34] <= wq[((((NumBanks - 1) - bi) * PracTopK) + ((PracTopK - 1) - sj)) * 34+:34];
						end
						credits_q[bi] <= nc[bi];
					end
			end
			pending_q <= pend_nxt;
			lat_bg_q <= nlat_bg;
			lat_ba_q <= nlat_ba;
			lat_row_q <= nlat_rw;
			drfm_pending_o <= pend_nxt;
			drfm_target_bg_o <= nlat_bg;
			drfm_target_ba_o <= nlat_ba;
			drfm_target_row_o <= nlat_rw;
			scan_hit_mem(wq, hit_ov_v, ov_bg, ov_ba, ov_bi, ov_row);
			prac_overflow_alert_o <= (hit_ov_v && !pend_nxt) && (nc[ov_bi] == {CountW {1'sb0}});
		end
	end
	genvar _gv_gbi_1;
	generate
		for (_gv_gbi_1 = 0; _gv_gbi_1 < sv2v_cast_32_signed(NumBanks); _gv_gbi_1 = _gv_gbi_1 + 1) begin : g_as_credits
			localparam gbi = _gv_gbi_1;
		end
	endgenerate
endmodule
