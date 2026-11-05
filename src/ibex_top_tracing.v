module ibex_top_tracing (
	clk_i,
	rst_ni,
	test_en_i,
	scan_rst_ni,
	ram_cfg_icache_tag_i,
	ram_cfg_rsp_icache_tag_o,
	ram_cfg_icache_data_i,
	ram_cfg_rsp_icache_data_o,
	hart_id_i,
	boot_addr_i,
	instr_req_o,
	instr_gnt_i,
	instr_rvalid_i,
	instr_addr_o,
	instr_rdata_i,
	instr_rdata_intg_i,
	instr_err_i,
	data_req_o,
	data_gnt_i,
	data_rvalid_i,
	data_we_o,
	data_be_o,
	data_addr_o,
	data_wdata_o,
	data_wdata_intg_o,
	data_rdata_i,
	data_rdata_intg_i,
	data_err_i,
	irq_software_i,
	irq_timer_i,
	irq_external_i,
	irq_fast_i,
	irq_nm_i,
	scramble_key_valid_i,
	scramble_key_i,
	scramble_nonce_i,
	scramble_req_o,
	debug_req_i,
	crash_dump_o,
	double_fault_seen_o,
	fetch_enable_i,
	alert_minor_o,
	alert_major_internal_o,
	alert_major_bus_o,
	core_sleep_o,
	lockstep_cmp_en_o,
	data_req_shadow_o,
	data_we_shadow_o,
	data_be_shadow_o,
	data_addr_shadow_o,
	data_wdata_shadow_o,
	data_wdata_intg_shadow_o,
	instr_req_shadow_o,
	instr_addr_shadow_o
);
	parameter [0:0] PMPEnable = 1'b0;
	parameter [31:0] PMPGranularity = 0;
	parameter [31:0] PMPNumRegions = 4;
	parameter [31:0] MHPMCounterNum = 0;
	parameter [31:0] MHPMCounterWidth = 40;
	parameter [0:0] RV32E = 1'b0;
	parameter integer RV32M = 32'sd2;
	parameter integer RV32B = 32'sd0;
	parameter integer RV32ZC = 32'sd3;
	parameter integer RegFile = 32'sd0;
	parameter [0:0] BranchTargetALU = 1'b0;
	parameter [0:0] WritebackStage = 1'b0;
	parameter [0:0] ICache = 1'b0;
	parameter [0:0] ICacheECC = 1'b0;
	parameter [0:0] ICacheTweakInfection = 1'b0;
	parameter [0:0] BranchPredictor = 1'b0;
	parameter [0:0] DbgTriggerEn = 1'b0;
	parameter [31:0] DbgHwBreakNum = 1;
	parameter [0:0] SecureIbex = 1'b0;
	parameter [31:0] LockstepOffset = 1;
	parameter [0:0] MemECC = SecureIbex;
	parameter [31:0] MemDataWidth = (MemECC ? 39 : 32);
	parameter [0:0] ICacheScramble = 1'b0;
	localparam signed [31:0] ibex_pkg_LfsrWidth = 32;
	localparam [31:0] ibex_pkg_RndCnstLfsrSeedDefault = 32'hac533bf4;
	parameter [31:0] RndCnstLfsrSeed = ibex_pkg_RndCnstLfsrSeedDefault;
	localparam [159:0] ibex_pkg_RndCnstLfsrPermDefault = 160'h1e35ecba467fd1b12e958152c04fa43878a8daed;
	parameter [159:0] RndCnstLfsrPerm = ibex_pkg_RndCnstLfsrPermDefault;
	parameter [31:0] DmBaseAddr = 32'h1a110000;
	parameter [31:0] DmAddrMask = 32'h00000fff;
	parameter [31:0] DmHaltAddr = 32'h1a110800;
	parameter [31:0] DmExceptionAddr = 32'h1a110808;
	input wire clk_i;
	input wire rst_ni;
	input wire test_en_i;
	input wire scan_rst_ni;
	input wire [11:0] ram_cfg_icache_tag_i;
	localparam [31:0] ibex_pkg_IC_NUM_WAYS = 2;
	output wire [1:0] ram_cfg_rsp_icache_tag_o;
	input wire [11:0] ram_cfg_icache_data_i;
	output wire [1:0] ram_cfg_rsp_icache_data_o;
	input wire [31:0] hart_id_i;
	input wire [31:0] boot_addr_i;
	output wire instr_req_o;
	input wire instr_gnt_i;
	input wire instr_rvalid_i;
	output wire [31:0] instr_addr_o;
	input wire [31:0] instr_rdata_i;
	input wire [6:0] instr_rdata_intg_i;
	input wire instr_err_i;
	output wire data_req_o;
	input wire data_gnt_i;
	input wire data_rvalid_i;
	output wire data_we_o;
	output wire [3:0] data_be_o;
	output wire [31:0] data_addr_o;
	output wire [31:0] data_wdata_o;
	output wire [6:0] data_wdata_intg_o;
	input wire [31:0] data_rdata_i;
	input wire [6:0] data_rdata_intg_i;
	input wire data_err_i;
	input wire irq_software_i;
	input wire irq_timer_i;
	input wire irq_external_i;
	input wire [14:0] irq_fast_i;
	input wire irq_nm_i;
	input wire scramble_key_valid_i;
	localparam [31:0] ibex_pkg_SCRAMBLE_KEY_W = 128;
	input wire [127:0] scramble_key_i;
	localparam [31:0] ibex_pkg_SCRAMBLE_NONCE_W = 64;
	input wire [63:0] scramble_nonce_i;
	output wire scramble_req_o;
	input wire debug_req_i;
	output wire [159:0] crash_dump_o;
	output wire double_fault_seen_o;
	localparam signed [31:0] ibex_pkg_IbexMuBiWidth = 4;
	input wire [3:0] fetch_enable_i;
	output wire alert_minor_o;
	output wire alert_major_internal_o;
	output wire alert_major_bus_o;
	output wire core_sleep_o;
	output wire [3:0] lockstep_cmp_en_o;
	output wire data_req_shadow_o;
	output wire data_we_shadow_o;
	output wire [3:0] data_be_shadow_o;
	output wire [31:0] data_addr_shadow_o;
	output wire [31:0] data_wdata_shadow_o;
	output wire [6:0] data_wdata_intg_shadow_o;
	output wire instr_req_shadow_o;
	output wire [31:0] instr_addr_shadow_o;
	initial begin
		$display("Fatal [elaboration] /home/bac/ibex/rtl/ibex_top_tracing.sv:122:5 - ibex_top_tracing");
		$finish("Fatal error: RVFI needs to be defined globally.");
	end
	wire rvfi_valid;
	wire [63:0] rvfi_order;
	wire [31:0] rvfi_insn;
	wire rvfi_trap;
	wire rvfi_halt;
	wire rvfi_intr;
	wire [1:0] rvfi_mode;
	wire [1:0] rvfi_ixl;
	wire [4:0] rvfi_rs1_addr;
	wire [4:0] rvfi_rs2_addr;
	wire [4:0] rvfi_rs3_addr;
	wire [31:0] rvfi_rs1_rdata;
	wire [31:0] rvfi_rs2_rdata;
	wire [31:0] rvfi_rs3_rdata;
	wire [4:0] rvfi_rd_addr;
	wire [31:0] rvfi_rd_wdata;
	wire [31:0] rvfi_pc_rdata;
	wire [31:0] rvfi_pc_wdata;
	wire [31:0] rvfi_mem_addr;
	wire [3:0] rvfi_mem_rmask;
	wire [3:0] rvfi_mem_wmask;
	wire [31:0] rvfi_mem_rdata;
	wire [31:0] rvfi_mem_wdata;
	wire [31:0] rvfi_ext_pre_mip;
	wire [31:0] rvfi_ext_post_mip;
	wire rvfi_ext_nmi;
	wire rvfi_ext_nmi_int;
	wire rvfi_ext_debug_req;
	wire rvfi_ext_debug_mode;
	wire rvfi_ext_rf_wr_suppress;
	wire [63:0] rvfi_ext_mcycle;
	wire [319:0] rvfi_ext_mhpmcounters;
	wire [319:0] rvfi_ext_mhpmcountersh;
	wire rvfi_ext_ic_scr_key_valid;
	wire rvfi_ext_irq_valid;
	wire rvfi_ext_expanded_insn_valid;
	wire [15:0] rvfi_ext_expanded_insn;
	wire rvfi_ext_expanded_insn_last;
	wire [319:0] unused_perf_regs;
	wire [319:0] unused_perf_regsh;
	wire [31:0] unused_rvfi_ext_pre_mip;
	wire [31:0] unused_rvfi_ext_post_mip;
	wire unused_rvfi_ext_nmi;
	wire unused_rvfi_ext_nmi_int;
	wire unused_rvfi_ext_debug_req;
	wire unused_rvfi_ext_debug_mode;
	wire unused_rvfi_ext_rf_wr_suppress;
	wire [63:0] unused_rvfi_ext_mcycle;
	wire unused_rvfi_ext_ic_scr_key_valid;
	wire unused_rvfi_ext_irq_valid;
	wire unused_rvfi_ext_expanded_insn_last;
	assign unused_rvfi_ext_pre_mip = rvfi_ext_pre_mip;
	assign unused_rvfi_ext_post_mip = rvfi_ext_post_mip;
	assign unused_rvfi_ext_nmi = rvfi_ext_nmi;
	assign unused_rvfi_ext_nmi_int = rvfi_ext_nmi_int;
	assign unused_rvfi_ext_debug_req = rvfi_ext_debug_req;
	assign unused_rvfi_ext_debug_mode = rvfi_ext_debug_mode;
	assign unused_rvfi_ext_rf_wr_suppress = rvfi_ext_rf_wr_suppress;
	assign unused_rvfi_ext_mcycle = rvfi_ext_mcycle;
	assign unused_perf_regs = rvfi_ext_mhpmcounters;
	assign unused_perf_regsh = rvfi_ext_mhpmcountersh;
	assign unused_rvfi_ext_ic_scr_key_valid = rvfi_ext_ic_scr_key_valid;
	assign unused_rvfi_ext_irq_valid = rvfi_ext_irq_valid;
	assign unused_rvfi_ext_expanded_insn_last = rvfi_ext_expanded_insn_last;
	ibex_top #(
		.PMPEnable(PMPEnable),
		.PMPGranularity(PMPGranularity),
		.PMPNumRegions(PMPNumRegions),
		.MHPMCounterNum(MHPMCounterNum),
		.MHPMCounterWidth(MHPMCounterWidth),
		.RV32E(RV32E),
		.RV32M(RV32M),
		.RV32B(RV32B),
		.RV32ZC(RV32ZC),
		.RegFile(RegFile),
		.BranchTargetALU(BranchTargetALU),
		.ICache(ICache),
		.ICacheECC(ICacheECC),
		.ICacheTweakInfection(ICacheTweakInfection),
		.BranchPredictor(BranchPredictor),
		.DbgTriggerEn(DbgTriggerEn),
		.DbgHwBreakNum(DbgHwBreakNum),
		.WritebackStage(WritebackStage),
		.SecureIbex(SecureIbex),
		.LockstepOffset(LockstepOffset),
		.MemECC(MemECC),
		.MemDataWidth(MemDataWidth),
		.ICacheScramble(ICacheScramble),
		.RndCnstLfsrSeed(RndCnstLfsrSeed),
		.RndCnstLfsrPerm(RndCnstLfsrPerm),
		.DmBaseAddr(DmBaseAddr),
		.DmAddrMask(DmAddrMask),
		.DmHaltAddr(DmHaltAddr),
		.DmExceptionAddr(DmExceptionAddr)
	) u_ibex_top(
		.clk_i(clk_i),
		.rst_ni(rst_ni),
		.test_en_i(test_en_i),
		.scan_rst_ni(scan_rst_ni),
		.ram_cfg_icache_tag_i(ram_cfg_icache_tag_i),
		.ram_cfg_rsp_icache_tag_o(ram_cfg_rsp_icache_tag_o),
		.ram_cfg_icache_data_i(ram_cfg_icache_data_i),
		.ram_cfg_rsp_icache_data_o(ram_cfg_rsp_icache_data_o),
		.hart_id_i(hart_id_i),
		.boot_addr_i(boot_addr_i),
		.instr_req_o(instr_req_o),
		.instr_gnt_i(instr_gnt_i),
		.instr_rvalid_i(instr_rvalid_i),
		.instr_addr_o(instr_addr_o),
		.instr_rdata_i(instr_rdata_i),
		.instr_rdata_intg_i(instr_rdata_intg_i),
		.instr_err_i(instr_err_i),
		.data_req_o(data_req_o),
		.data_gnt_i(data_gnt_i),
		.data_rvalid_i(data_rvalid_i),
		.data_we_o(data_we_o),
		.data_be_o(data_be_o),
		.data_addr_o(data_addr_o),
		.data_wdata_o(data_wdata_o),
		.data_wdata_intg_o(data_wdata_intg_o),
		.data_rdata_i(data_rdata_i),
		.data_rdata_intg_i(data_rdata_intg_i),
		.data_err_i(data_err_i),
		.irq_software_i(irq_software_i),
		.irq_timer_i(irq_timer_i),
		.irq_external_i(irq_external_i),
		.irq_fast_i(irq_fast_i),
		.irq_nm_i(irq_nm_i),
		.scramble_key_valid_i(scramble_key_valid_i),
		.scramble_key_i(scramble_key_i),
		.scramble_nonce_i(scramble_nonce_i),
		.scramble_req_o(scramble_req_o),
		.debug_req_i(debug_req_i),
		.crash_dump_o(crash_dump_o),
		.double_fault_seen_o(double_fault_seen_o),
		.rvfi_valid(rvfi_valid),
		.rvfi_order(rvfi_order),
		.rvfi_insn(rvfi_insn),
		.rvfi_trap(rvfi_trap),
		.rvfi_halt(rvfi_halt),
		.rvfi_intr(rvfi_intr),
		.rvfi_mode(rvfi_mode),
		.rvfi_ixl(rvfi_ixl),
		.rvfi_rs1_addr(rvfi_rs1_addr),
		.rvfi_rs2_addr(rvfi_rs2_addr),
		.rvfi_rs3_addr(rvfi_rs3_addr),
		.rvfi_rs1_rdata(rvfi_rs1_rdata),
		.rvfi_rs2_rdata(rvfi_rs2_rdata),
		.rvfi_rs3_rdata(rvfi_rs3_rdata),
		.rvfi_rd_addr(rvfi_rd_addr),
		.rvfi_rd_wdata(rvfi_rd_wdata),
		.rvfi_pc_rdata(rvfi_pc_rdata),
		.rvfi_pc_wdata(rvfi_pc_wdata),
		.rvfi_mem_addr(rvfi_mem_addr),
		.rvfi_mem_rmask(rvfi_mem_rmask),
		.rvfi_mem_wmask(rvfi_mem_wmask),
		.rvfi_mem_rdata(rvfi_mem_rdata),
		.rvfi_mem_wdata(rvfi_mem_wdata),
		.rvfi_ext_pre_mip(rvfi_ext_pre_mip),
		.rvfi_ext_post_mip(rvfi_ext_post_mip),
		.rvfi_ext_nmi(rvfi_ext_nmi),
		.rvfi_ext_nmi_int(rvfi_ext_nmi_int),
		.rvfi_ext_debug_req(rvfi_ext_debug_req),
		.rvfi_ext_debug_mode(rvfi_ext_debug_mode),
		.rvfi_ext_rf_wr_suppress(rvfi_ext_rf_wr_suppress),
		.rvfi_ext_mcycle(rvfi_ext_mcycle),
		.rvfi_ext_mhpmcounters(rvfi_ext_mhpmcounters),
		.rvfi_ext_mhpmcountersh(rvfi_ext_mhpmcountersh),
		.rvfi_ext_ic_scr_key_valid(rvfi_ext_ic_scr_key_valid),
		.rvfi_ext_irq_valid(rvfi_ext_irq_valid),
		.rvfi_ext_expanded_insn_valid(rvfi_ext_expanded_insn_valid),
		.rvfi_ext_expanded_insn(rvfi_ext_expanded_insn),
		.rvfi_ext_expanded_insn_last(rvfi_ext_expanded_insn_last),
		.fetch_enable_i(fetch_enable_i),
		.alert_minor_o(alert_minor_o),
		.alert_major_internal_o(alert_major_internal_o),
		.alert_major_bus_o(alert_major_bus_o),
		.core_sleep_o(core_sleep_o),
		.lockstep_cmp_en_o(lockstep_cmp_en_o),
		.data_req_shadow_o(data_req_shadow_o),
		.data_we_shadow_o(data_we_shadow_o),
		.data_be_shadow_o(data_be_shadow_o),
		.data_addr_shadow_o(data_addr_shadow_o),
		.data_wdata_shadow_o(data_wdata_shadow_o),
		.data_wdata_intg_shadow_o(data_wdata_intg_shadow_o),
		.instr_req_shadow_o(instr_req_shadow_o),
		.instr_addr_shadow_o(instr_addr_shadow_o)
	);
	ibex_tracer u_ibex_tracer(
		.clk_i(clk_i),
		.rst_ni(rst_ni),
		.hart_id_i(hart_id_i),
		.rvfi_valid(rvfi_valid),
		.rvfi_order(rvfi_order),
		.rvfi_insn(rvfi_insn),
		.rvfi_trap(rvfi_trap),
		.rvfi_halt(rvfi_halt),
		.rvfi_intr(rvfi_intr),
		.rvfi_mode(rvfi_mode),
		.rvfi_ixl(rvfi_ixl),
		.rvfi_rs1_addr(rvfi_rs1_addr),
		.rvfi_rs2_addr(rvfi_rs2_addr),
		.rvfi_rs3_addr(rvfi_rs3_addr),
		.rvfi_rs1_rdata(rvfi_rs1_rdata),
		.rvfi_rs2_rdata(rvfi_rs2_rdata),
		.rvfi_rs3_rdata(rvfi_rs3_rdata),
		.rvfi_rd_addr(rvfi_rd_addr),
		.rvfi_rd_wdata(rvfi_rd_wdata),
		.rvfi_pc_rdata(rvfi_pc_rdata),
		.rvfi_pc_wdata(rvfi_pc_wdata),
		.rvfi_mem_addr(rvfi_mem_addr),
		.rvfi_mem_rmask(rvfi_mem_rmask),
		.rvfi_mem_wmask(rvfi_mem_wmask),
		.rvfi_mem_rdata(rvfi_mem_rdata),
		.rvfi_mem_wdata(rvfi_mem_wdata),
		.rvfi_ext_expanded_insn_valid(rvfi_ext_expanded_insn_valid),
		.rvfi_ext_expanded_insn(rvfi_ext_expanded_insn)
	);
endmodule