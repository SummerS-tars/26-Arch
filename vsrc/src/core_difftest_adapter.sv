`ifndef __CORE_DIFFTEST_ADAPTER_SV
`define __CORE_DIFFTEST_ADAPTER_SV

`ifdef VERILATOR
`include "include/common.sv"
`endif

// Difftest commit adapter: GPR bypass, skip rules, and Verilator hooks.
// Skip rules (Lab4/Lab5 compatibility):
//   - low-address MMIO load/store (addr[31] == 0)
//   - PMP CSR accesses (pmpcfg0 / pmpaddr0)
module core_difftest_adapter import common::*;(
	input  logic        clk,
	input  logic [7:0]  coreid,
	input  logic        commit_valid,
	input  logic [63:0] pc,
	input  logic [31:0] instr,
	input  logic        reg_write_fire,
	input  logic [4:0]  rd,
	input  logic [63:0] wb_data,
	input  logic        mem_read_wb,
	input  logic        mem_write_wb,
	input  logic [63:0] alu_result_wb,
	input  logic        is_csr_wb,
	input  csr_addr_t   csr_addr_wb,
	input  logic        trap_valid,
	input  logic [2:0]  trap_code,
	input  logic [63:0] cycle_cnt,
	input  logic [63:0] instr_cnt,
	input  priv_mode_t  priv_mode,
	input  logic [31:0][63:0] gpr_dbg,
	input  logic [63:0] mstatus,
	input  logic [63:0] sstatus,
	input  logic [63:0] mepc,
	input  logic [63:0] sepc,
	input  logic [63:0] mtval,
	input  logic [63:0] stval,
	input  logic [63:0] mtvec,
	input  logic [63:0] stvec,
	input  logic [63:0] mcause,
	input  logic [63:0] scause,
	input  logic [63:0] satp,
	input  logic [63:0] mip,
	input  logic [63:0] mie,
	input  logic [63:0] mscratch,
	input  logic [63:0] sscratch,
	input  logic [63:0] mideleg,
	input  logic [63:0] medeleg
);
	logic        skip;
	logic [63:0] gpr_dt [32];

	assign skip = ((mem_read_wb || mem_write_wb) && (alu_result_wb[31] == 1'b0)) ||
		(is_csr_wb && (csr_addr_wb == 12'h3a0 || csr_addr_wb == 12'h3b0));

	always_comb begin
		for (int i = 0; i < 32; i++) begin
			if (i == 0)
				gpr_dt[i] = 64'b0;
			else if (reg_write_fire && rd == i[4:0])
				gpr_dt[i] = wb_data;
			else
				gpr_dt[i] = gpr_dbg[i];
		end
	end

	DifftestInstrCommit DifftestInstrCommit(
		.clock              (clk),
		.coreid             (coreid),
		.index              (8'b0),
		.valid              (commit_valid),
		.pc                 (pc),
		.instr              (instr),
		.skip               (skip),
		.isRVC              (1'b0),
		.scFailed           (1'b0),
		.wen                (reg_write_fire),
		.wdest              ({3'b0, rd}),
		.wdata              (wb_data)
	);

	DifftestArchIntRegState DifftestArchIntRegState (
		.clock              (clk),
		.coreid             (coreid),
		.gpr_0              (gpr_dt[0]),
		.gpr_1              (gpr_dt[1]),
		.gpr_2              (gpr_dt[2]),
		.gpr_3              (gpr_dt[3]),
		.gpr_4              (gpr_dt[4]),
		.gpr_5              (gpr_dt[5]),
		.gpr_6              (gpr_dt[6]),
		.gpr_7              (gpr_dt[7]),
		.gpr_8              (gpr_dt[8]),
		.gpr_9              (gpr_dt[9]),
		.gpr_10             (gpr_dt[10]),
		.gpr_11             (gpr_dt[11]),
		.gpr_12             (gpr_dt[12]),
		.gpr_13             (gpr_dt[13]),
		.gpr_14             (gpr_dt[14]),
		.gpr_15             (gpr_dt[15]),
		.gpr_16             (gpr_dt[16]),
		.gpr_17             (gpr_dt[17]),
		.gpr_18             (gpr_dt[18]),
		.gpr_19             (gpr_dt[19]),
		.gpr_20             (gpr_dt[20]),
		.gpr_21             (gpr_dt[21]),
		.gpr_22             (gpr_dt[22]),
		.gpr_23             (gpr_dt[23]),
		.gpr_24             (gpr_dt[24]),
		.gpr_25             (gpr_dt[25]),
		.gpr_26             (gpr_dt[26]),
		.gpr_27             (gpr_dt[27]),
		.gpr_28             (gpr_dt[28]),
		.gpr_29             (gpr_dt[29]),
		.gpr_30             (gpr_dt[30]),
		.gpr_31             (gpr_dt[31])
	);

	DifftestTrapEvent DifftestTrapEvent(
		.clock              (clk),
		.coreid             (coreid),
		.valid              (trap_valid),
		.code               (trap_code),
		.pc                 (pc),
		.cycleCnt           (cycle_cnt),
		.instrCnt           (instr_cnt)
	);

	DifftestCSRState DifftestCSRState(
		.clock              (clk),
		.coreid             (coreid),
		.priviledgeMode     (priv_mode),
		.mstatus            (mstatus),
		.sstatus            (sstatus),
		.mepc               (mepc),
		.sepc               (sepc),
		.mtval              (mtval),
		.stval              (stval),
		.mtvec              (mtvec),
		.stvec              (stvec),
		.mcause             (mcause),
		.scause             (scause),
		.satp               (satp),
		.mip                (mip),
		.mie                (mie),
		.mscratch           (mscratch),
		.sscratch           (sscratch),
		.mideleg            (mideleg),
		.medeleg            (medeleg)
	);
endmodule

`endif
