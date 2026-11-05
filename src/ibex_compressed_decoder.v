module ibex_compressed_decoder (
	clk_i,
	rst_ni,
	valid_i,
	id_in_ready_i,
	instr_i,
	instr_o,
	is_compressed_o,
	gets_expanded_o,
	illegal_instr_o
);
	reg _sv2v_0;
	parameter integer RV32ZC = 32'sd3;
	parameter [0:0] ResetAll = 1'b0;
	input wire clk_i;
	input wire rst_ni;
	input wire valid_i;
	input wire id_in_ready_i;
	input wire [31:0] instr_i;
	output reg [31:0] instr_o;
	output wire is_compressed_o;
	output wire [1:0] gets_expanded_o;
	output reg illegal_instr_o;
	generate
		if (!((RV32ZC == 32'sd3) || (RV32ZC == 32'sd2))) begin : gen_unused_valid
			wire unused_valid;
			wire unused_id_in_ready;
			assign unused_valid = valid_i;
			assign unused_id_in_ready = id_in_ready_i;
		end
	endgenerate
	function automatic [6:0] cm_stack_adj_base;
		input reg [3:0] rlist;
		(* full_case, parallel_case *)
		case (rlist)
			4'd4, 4'd5, 4'd6, 4'd7: cm_stack_adj_base = 7'd16;
			4'd8, 4'd9, 4'd10, 4'd11: cm_stack_adj_base = 7'd32;
			4'd12, 4'd13, 4'd14: cm_stack_adj_base = 7'd48;
			4'd15: cm_stack_adj_base = 7'd64;
			default: cm_stack_adj_base = 7'd0;
		endcase
	endfunction
	function automatic [6:0] cm_stack_adj;
		input reg [3:0] rlist;
		input reg [1:0] spimm;
		cm_stack_adj = cm_stack_adj_base(rlist) + (spimm * 16);
	endfunction
	function automatic [4:0] cm_stack_adj_word;
		input reg [3:0] rlist;
		input reg [1:0] spimm;
		reg [6:0] tmp;
		reg [1:0] unused_tmp;
		begin
			tmp = cm_stack_adj(rlist, spimm);
			unused_tmp = tmp[1:0];
			cm_stack_adj_word = tmp[6:2];
		end
	endfunction
	function automatic [4:0] cm_rlist_top_reg;
		input reg [4:0] rlist;
		(* full_case, parallel_case *)
		case (rlist)
			5'd16, 5'd15, 5'd14, 5'd13, 5'd12, 5'd11, 5'd10, 5'd9, 5'd8, 5'd7: cm_rlist_top_reg = 5'd11 + rlist;
			5'd6, 5'd5: cm_rlist_top_reg = 5'd3 + rlist;
			5'd4: cm_rlist_top_reg = 5'd1;
			default: cm_rlist_top_reg = 5'd0;
		endcase
	endfunction
	function automatic [31:0] cm_push_store_reg;
		input reg [4:0] rlist;
		input reg [4:0] sp_offset;
		reg [11:0] neg_offset;
		reg signed [11:0] neg_offset_signed;
		reg [31:0] instr;
		begin
			neg_offset_signed = -$signed({5'b00000, sp_offset, 2'b00});
			neg_offset = $unsigned(neg_offset_signed);
			instr[6:0] = 7'h23;
			instr[11:7] = neg_offset[4:0];
			instr[14:12] = 3'b010;
			instr[19:15] = 5'd2;
			instr[24:20] = cm_rlist_top_reg(rlist);
			instr[31:25] = neg_offset[11:5];
			cm_push_store_reg = instr;
		end
	endfunction
	function automatic [31:0] cm_pop_load_reg;
		input reg [4:0] rlist;
		input reg [4:0] sp_offset;
		reg [31:0] instr;
		begin
			instr[6:0] = 7'h03;
			instr[11:7] = cm_rlist_top_reg(rlist);
			instr[14:12] = 3'b010;
			instr[19:15] = 5'd2;
			instr[31:20] = {5'b00000, sp_offset, 2'b00};
			cm_pop_load_reg = instr;
		end
	endfunction
	function automatic [31:0] cm_sp_addi;
		input reg [3:0] rlist;
		input reg [1:0] spimm;
		input reg decr;
		reg [11:0] imm;
		reg signed [11:0] imm_signed;
		reg [31:0] instr;
		begin
			decr = 1'b0;
			imm[11:7] = 1'sb0;
			imm[6:0] = cm_stack_adj(rlist, spimm);
			imm_signed = (decr ? -$signed(imm) : $signed(imm));
			instr[6:0] = 7'h13;
			instr[11:7] = 5'd2;
			instr[14:12] = 3'b000;
			instr[19:15] = 5'd2;
			instr[31:20] = $unsigned(imm_signed);
			cm_sp_addi = instr;
		end
	endfunction
	function automatic [31:0] cm_mv_reg;
		input reg [4:0] src;
		input reg [4:0] dst;
		reg [31:0] instr;
		begin
			instr[6:0] = 7'h13;
			instr[11:7] = dst;
			instr[14:12] = 3'b000;
			instr[19:15] = src;
			instr[31:20] = 12'd0;
			cm_mv_reg = instr;
		end
	endfunction
	function automatic [31:0] cm_zero_a0;
		input reg _sv2v_unused;
		cm_zero_a0 = cm_mv_reg(5'd0, 5'd10);
	endfunction
	function automatic [31:0] cm_ret_ra;
		input reg _sv2v_unused;
		reg [31:0] instr;
		begin
			instr[6:0] = 7'h67;
			instr[11:7] = 5'd0;
			instr[14:12] = 3'b000;
			instr[19:15] = 5'd1;
			instr[31:20] = 12'd0;
			cm_ret_ra = instr;
		end
	endfunction
	function automatic [31:0] cm_mvsa01;
		input reg a01;
		input reg [2:0] rs;
		reg [4:0] src;
		reg [4:0] dst;
		begin
			src = 5'd10 + {4'd0, a01};
			dst = {rs[2:1] > 2'd0, rs[2:1] == 2'd0, rs[2:0]};
			cm_mvsa01 = cm_mv_reg(src, dst);
		end
	endfunction
	function automatic [31:0] cm_mva01s;
		input reg [2:0] rs;
		input reg a01;
		reg [4:0] src;
		reg [4:0] dst;
		begin
			src = {rs[2:1] > 2'd0, rs[2:1] == 2'd0, rs[2:0]};
			dst = 5'd10 + {4'd0, a01};
			cm_mva01s = cm_mv_reg(src, dst);
		end
	endfunction
	function automatic [4:0] cm_rlist_init;
		input reg [3:0] instr_rlist;
		reg [4:0] rlist;
		begin
			rlist = {1'b0, instr_rlist};
			if (rlist == 5'd15)
				rlist = 5'd16;
			cm_rlist_init = rlist;
		end
	endfunction
	reg [4:0] cm_rlist_d;
	reg [4:0] cm_rlist_q;
	reg [4:0] cm_sp_offset_d;
	reg [4:0] cm_sp_offset_q;
	reg [2:0] cm_state_d;
	reg [2:0] cm_state_q;
	reg [1:0] gets_expanded;
	generate
		if ((RV32ZC == 32'sd3) || (RV32ZC == 32'sd2)) begin : gen_gets_expanded
			assign gets_expanded_o = (valid_i ? gets_expanded : 2'd0);
		end
		else begin : gen_gets_expanded
			assign gets_expanded_o = gets_expanded;
		end
	endgenerate
	always @(*) begin
		if (_sv2v_0)
			;
		instr_o = instr_i;
		illegal_instr_o = 1'b0;
		gets_expanded = 2'd0;
		cm_rlist_d = cm_rlist_q;
		cm_sp_offset_d = cm_sp_offset_q;
		cm_state_d = cm_state_q;
		(* full_case, parallel_case *)
		case (instr_i[1:0])
			2'b00:
				(* full_case, parallel_case *)
				case (instr_i[15:13])
					3'b000: begin
						instr_o = {2'b00, instr_i[10:7], instr_i[12:11], instr_i[5], instr_i[6], 12'h041, instr_i[4:2], 7'h13};
						if (instr_i[12:5] == 8'b00000000)
							illegal_instr_o = 1'b1;
					end
					3'b010: instr_o = {5'b00000, instr_i[5], instr_i[12:10], instr_i[6], 4'b0001, instr_i[9:7], 5'b01001, instr_i[4:2], 7'h03};
					3'b110: instr_o = {5'b00000, instr_i[5], instr_i[12], 2'b01, instr_i[4:2], 2'b01, instr_i[9:7], 3'b010, instr_i[11:10], instr_i[6], 9'h023};
					3'b100:
						if ((RV32ZC == 32'sd3) || (RV32ZC == 32'sd1))
							(* full_case, parallel_case *)
							case (instr_i[12:10])
								3'b000: instr_o = {10'b0000000000, instr_i[5], instr_i[6], 2'b01, instr_i[9:7], 5'b10001, instr_i[4:2], 7'h03};
								3'b001:
									(* full_case, parallel_case *)
									case (instr_i[6])
										1'b0: instr_o = {10'b0000000000, instr_i[5], 3'b001, instr_i[9:7], 5'b10101, instr_i[4:2], 7'h03};
										1'b1: instr_o = {10'b0000000000, instr_i[5], 3'b001, instr_i[9:7], 5'b00101, instr_i[4:2], 7'h03};
										default: illegal_instr_o = 1'b1;
									endcase
								3'b010: instr_o = {9'b000000001, instr_i[4:2], 2'b01, instr_i[9:7], 6'b000000, instr_i[5], instr_i[6], 7'h23};
								3'b011:
									(* full_case, parallel_case *)
									case (instr_i[6])
										1'b0: instr_o = {9'b000000001, instr_i[4:2], 2'b01, instr_i[9:7], 6'b001000, instr_i[5], 8'h23};
										1'b1: illegal_instr_o = 1'b1;
										default: illegal_instr_o = 1'b1;
									endcase
								default: illegal_instr_o = 1'b1;
							endcase
						else
							illegal_instr_o = 1'b1;
					3'b001, 3'b011, 3'b101, 3'b111: illegal_instr_o = 1'b1;
					default: illegal_instr_o = 1'b1;
				endcase
			2'b01:
				(* full_case, parallel_case *)
				case (instr_i[15:13])
					3'b000: instr_o = {{6 {instr_i[12]}}, instr_i[12], instr_i[6:2], instr_i[11:7], 3'b000, instr_i[11:7], 7'h13};
					3'b001, 3'b101: instr_o = {instr_i[12], instr_i[8], instr_i[10:9], instr_i[6], instr_i[7], instr_i[2], instr_i[11], instr_i[5:3], {9 {instr_i[12]}}, 4'b0000, ~instr_i[15], 7'h6f};
					3'b010: instr_o = {{6 {instr_i[12]}}, instr_i[12], instr_i[6:2], 8'b00000000, instr_i[11:7], 7'h13};
					3'b011: begin
						instr_o = {{15 {instr_i[12]}}, instr_i[6:2], instr_i[11:7], 7'h37};
						if (instr_i[11:7] == 5'h02)
							instr_o = {{3 {instr_i[12]}}, instr_i[4:3], instr_i[5], instr_i[2], instr_i[6], 24'h010113};
						if ({instr_i[12], instr_i[6:2]} == 6'b000000)
							illegal_instr_o = 1'b1;
					end
					3'b100:
						(* full_case, parallel_case *)
						case (instr_i[11:10])
							2'b00, 2'b01: begin
								instr_o = {1'b0, instr_i[10], 5'b00000, instr_i[6:2], 2'b01, instr_i[9:7], 5'b10101, instr_i[9:7], 7'h13};
								if (instr_i[12] == 1'b1)
									illegal_instr_o = 1'b1;
							end
							2'b10: instr_o = {{6 {instr_i[12]}}, instr_i[12], instr_i[6:2], 2'b01, instr_i[9:7], 5'b11101, instr_i[9:7], 7'h13};
							2'b11:
								(* full_case, parallel_case *)
								case ({instr_i[12], instr_i[6:5]})
									3'b000: instr_o = {9'b010000001, instr_i[4:2], 2'b01, instr_i[9:7], 5'b00001, instr_i[9:7], 7'h33};
									3'b001: instr_o = {9'b000000001, instr_i[4:2], 2'b01, instr_i[9:7], 5'b10001, instr_i[9:7], 7'h33};
									3'b010: instr_o = {9'b000000001, instr_i[4:2], 2'b01, instr_i[9:7], 5'b11001, instr_i[9:7], 7'h33};
									3'b011: instr_o = {9'b000000001, instr_i[4:2], 2'b01, instr_i[9:7], 5'b11101, instr_i[9:7], 7'h33};
									3'b100, 3'b101: illegal_instr_o = 1'b1;
									3'b110:
										if ((RV32ZC == 32'sd3) || (RV32ZC == 32'sd1))
											instr_o = {9'b000000101, instr_i[4:2], 2'b01, instr_i[9:7], 5'b00001, instr_i[9:7], 7'h33};
										else
											illegal_instr_o = 1'b1;
									3'b111:
										if ((RV32ZC == 32'sd3) || (RV32ZC == 32'sd1))
											(* full_case, parallel_case *)
											case ({instr_i[4:2]})
												3'b000: instr_o = {14'h03fd, instr_i[9:7], 5'b11101, instr_i[9:7], 7'h13};
												3'b001: instr_o = {14'b01100000010001, instr_i[9:7], 5'b00101, instr_i[9:7], 7'h13};
												3'b010: instr_o = {14'b00001000000001, instr_i[9:7], 5'b10001, instr_i[9:7], 7'h33};
												3'b011: instr_o = {14'b01100000010101, instr_i[9:7], 5'b00101, instr_i[9:7], 7'h13};
												3'b100: illegal_instr_o = 1'b1;
												3'b101: instr_o = {14'h3ffd, instr_i[9:7], 5'b10001, instr_i[9:7], 7'h13};
												default: illegal_instr_o = 1'b1;
											endcase
										else
											illegal_instr_o = 1'b1;
									default: illegal_instr_o = 1'b1;
								endcase
							default: illegal_instr_o = 1'b1;
						endcase
					3'b110, 3'b111: instr_o = {{4 {instr_i[12]}}, instr_i[6:5], instr_i[2], 7'b0000001, instr_i[9:7], 2'b00, instr_i[13], instr_i[11:10], instr_i[4:3], instr_i[12], 7'h63};
					default: illegal_instr_o = 1'b1;
				endcase
			2'b10:
				(* full_case, parallel_case *)
				case (instr_i[15:13])
					3'b000: begin
						instr_o = {7'b0000000, instr_i[6:2], instr_i[11:7], 3'b001, instr_i[11:7], 7'h13};
						if (instr_i[12] == 1'b1)
							illegal_instr_o = 1'b1;
					end
					3'b010: begin
						instr_o = {4'b0000, instr_i[3:2], instr_i[12], instr_i[6:4], 10'h012, instr_i[11:7], 7'h03};
						if (instr_i[11:7] == 5'b00000)
							illegal_instr_o = 1'b1;
					end
					3'b100:
						if (instr_i[12] == 1'b0) begin
							if (instr_i[6:2] != 5'b00000)
								instr_o = {7'b0000000, instr_i[6:2], 8'b00000000, instr_i[11:7], 7'h33};
							else begin
								instr_o = {12'b000000000000, instr_i[11:7], 15'h0067};
								if (instr_i[11:7] == 5'b00000)
									illegal_instr_o = 1'b1;
							end
						end
						else if (instr_i[6:2] != 5'b00000)
							instr_o = {7'b0000000, instr_i[6:2], instr_i[11:7], 3'b000, instr_i[11:7], 7'h33};
						else if (instr_i[11:7] == 5'b00000)
							instr_o = 32'h00100073;
						else
							instr_o = {12'b000000000000, instr_i[11:7], 15'h00e7};
					3'b101:
						if ((RV32ZC == 32'sd3) || (RV32ZC == 32'sd2))
							(* full_case, parallel_case *)
							casez (instr_i[12:8])
								5'b11000: begin
									gets_expanded = 2'd1;
									(* full_case, parallel_case *)
									case (cm_state_q)
										3'd0: begin
											cm_rlist_d = cm_rlist_init(instr_i[7:4]);
											instr_o = cm_push_store_reg(cm_rlist_d, 5'd1);
											if (cm_rlist_d <= 5'd3)
												illegal_instr_o = 1'b1;
											else if (cm_rlist_d == 5'd4) begin
												if (valid_i && id_in_ready_i)
													cm_state_d = 3'd2;
											end
											else begin
												cm_rlist_d = cm_rlist_d - 5'd1;
												cm_sp_offset_d = 5'd2;
												if (valid_i && id_in_ready_i)
													cm_state_d = 3'd1;
											end
										end
										3'd1: begin
											instr_o = cm_push_store_reg(cm_rlist_q, cm_sp_offset_q);
											if (id_in_ready_i) begin
												cm_rlist_d = cm_rlist_q - 5'd1;
												cm_sp_offset_d = cm_sp_offset_q + 5'd1;
												if (cm_rlist_q == 5'd4)
													cm_state_d = 3'd2;
											end
										end
										3'd2: begin
											instr_o = cm_sp_addi(instr_i[7:4], instr_i[3:2], 1'b1);
											if (id_in_ready_i) begin
												gets_expanded = 2'd2;
												cm_state_d = 3'd0;
											end
										end
										default: cm_state_d = 3'd0;
									endcase
								end
								5'b11010, 5'b11100, 5'b11110: begin
									gets_expanded = 2'd1;
									(* full_case, parallel_case *)
									case (cm_state_q)
										3'd0: begin
											cm_rlist_d = cm_rlist_init(instr_i[7:4]);
											cm_sp_offset_d = cm_stack_adj_word(instr_i[7:4], instr_i[3:2]) - 5'd1;
											instr_o = cm_pop_load_reg(cm_rlist_d, cm_sp_offset_d);
											if (cm_rlist_d <= 5'd3)
												illegal_instr_o = 1'b1;
											else if (cm_rlist_d == 5'd4) begin
												if (valid_i && id_in_ready_i)
													cm_state_d = 3'd4;
											end
											else begin
												cm_rlist_d = cm_rlist_d - 5'd1;
												cm_sp_offset_d = cm_sp_offset_d - 5'd1;
												if (valid_i && id_in_ready_i)
													cm_state_d = 3'd3;
											end
										end
										3'd3: begin
											instr_o = cm_pop_load_reg(cm_rlist_q, cm_sp_offset_q);
											if (id_in_ready_i) begin
												cm_rlist_d = cm_rlist_q - 5'd1;
												cm_sp_offset_d = cm_sp_offset_q - 5'd1;
												if (cm_rlist_q == 5'd4)
													cm_state_d = 3'd4;
											end
										end
										3'd4: begin
											instr_o = cm_sp_addi(instr_i[7:4], instr_i[3:2], 1'b0);
											if (id_in_ready_i)
												(* full_case, parallel_case *)
												case (instr_i[12:8])
													5'b11100: cm_state_d = 3'd5;
													5'b11110: cm_state_d = 3'd6;
													default: begin
														gets_expanded = 2'd2;
														cm_state_d = 3'd0;
													end
												endcase
										end
										3'd5: begin
											instr_o = cm_zero_a0(0);
											if (id_in_ready_i)
												cm_state_d = 3'd6;
										end
										3'd6: begin
											instr_o = cm_ret_ra(0);
											if (id_in_ready_i) begin
												gets_expanded = 2'd2;
												cm_state_d = 3'd0;
											end
										end
										default: cm_state_d = 3'd0;
									endcase
								end
								5'b011zz:
									(* full_case, parallel_case *)
									case (instr_i[6:5])
										2'b01: begin
											gets_expanded = 2'd1;
											(* full_case, parallel_case *)
											case (cm_state_q)
												3'd0: begin
													instr_o = cm_mvsa01(1'b0, instr_i[9:7]);
													if (valid_i && id_in_ready_i)
														cm_state_d = 3'd7;
												end
												3'd7: begin
													instr_o = cm_mvsa01(1'b1, instr_i[4:2]);
													if (id_in_ready_i) begin
														gets_expanded = 2'd2;
														cm_state_d = 3'd0;
													end
												end
												default: cm_state_d = 3'd0;
											endcase
										end
										2'b11: begin
											gets_expanded = 2'd1;
											(* full_case, parallel_case *)
											case (cm_state_q)
												3'd0: begin
													instr_o = cm_mva01s(instr_i[9:7], 1'b0);
													if (valid_i && id_in_ready_i)
														cm_state_d = 3'd7;
												end
												3'd7: begin
													instr_o = cm_mva01s(instr_i[4:2], 1'b1);
													if (id_in_ready_i) begin
														gets_expanded = 2'd2;
														cm_state_d = 3'd0;
													end
												end
												default: cm_state_d = 3'd0;
											endcase
										end
										default: illegal_instr_o = 1'b1;
									endcase
								default: illegal_instr_o = 1'b1;
							endcase
						else
							illegal_instr_o = 1'b1;
					3'b110: instr_o = {4'b0000, instr_i[8:7], instr_i[12], instr_i[6:2], 8'h12, instr_i[11:9], 9'h023};
					3'b001, 3'b011, 3'b111: illegal_instr_o = 1'b1;
					default: illegal_instr_o = 1'b1;
				endcase
			2'b11:
				;
			default: illegal_instr_o = 1'b1;
		endcase
	end
	assign is_compressed_o = instr_i[1:0] != 2'b11;
	always @(posedge clk_i or negedge rst_ni)
		if (!rst_ni)
			cm_state_q <= 3'd0;
		else
			cm_state_q <= cm_state_d;
	generate
		if (ResetAll) begin : g_cm_meta_ra
			always @(posedge clk_i or negedge rst_ni)
				if (!rst_ni) begin
					cm_rlist_q <= 1'sb0;
					cm_sp_offset_q <= 1'sb0;
				end
				else begin
					cm_rlist_q <= cm_rlist_d;
					cm_sp_offset_q <= cm_sp_offset_d;
				end
		end
		else begin : g_cm_meta_nr
			always @(posedge clk_i) begin
				cm_rlist_q <= cm_rlist_d;
				cm_sp_offset_q <= cm_sp_offset_d;
			end
		end
	endgenerate
	initial _sv2v_0 = 0;
endmodule