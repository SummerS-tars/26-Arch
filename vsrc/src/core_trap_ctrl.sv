`ifndef __CORE_TRAP_CTRL_SV
`define __CORE_TRAP_CTRL_SV

`ifdef VERILATOR
`include "include/common.sv"
`include "include/trap.sv"
`endif

module core_trap_ctrl import common::*; import trap_pkg::*; (
	input  logic        inst_valid_wb,
	input  logic [63:0] pc_wb,
	input  logic [31:0] instr_wb,
	input  logic        exception_valid_wb,
	input  logic [63:0] exception_cause_wb,
	input  logic [63:0] exception_tval_wb,
	input  logic        is_ecall_wb,
	input  logic        is_mret_wb,
	input  logic        mem_read_wb,
	input  logic        mem_write_wb,
	input  logic        is_csr_wb,
	input  csr_addr_t   csr_addr_wb,
	input  logic        csr_write_enable_wb,
	input  csr_op_t     csr_op_wb,
	input  logic [63:0] csr_write_data_wb,
	input  logic [63:0] alu_result_wb,
	input  logic        reg_write_wb,
	input  logic [4:0]  rd_wb,
	input  logic        wb_fired,
	input  priv_mode_t  priv_mode_q,
	input  logic [63:0] csr_mstatus_pre_trap,
	input  logic [63:0] csr_mie_irq_q,
	input  logic [63:0] csr_mip_irq_q,
	input  logic [63:0] csr_mepc,
	input  logic [63:0] csr_mtvec,
	input  priv_mode_t  csr_mret_priv,
	input  logic        swint,
	input  logic        trint,
	input  logic        exint,
	input  logic        fetch_wait_q,
	input  logic        mem_wait_q,
	input  logic        system_event_ex,
	input  logic        system_event_mem,
	input  logic [7:0]  trap_code_in,
	output logic        commit_valid_wb,
	output logic        commit_fire_wb,
	output logic        reg_write_wb_fire,
	output logic        csr_write_wb_fire,
	output logic        system_wb_waiting,
	output logic        system_flush_front,
	output logic        system_redirect_fire_wb,
	output logic [63:0] system_redirect_target_wb,
	output logic        csr_trap_wen_wb,
	output logic        csr_mret_wen_wb,
	output logic [63:0] csr_trap_mepc_wb,
	output logic [63:0] csr_trap_mcause_wb,
	output logic [63:0] csr_trap_mtval_wb,
	output priv_mode_t  priv_mode_view,
	output logic        trap_valid_wb,
	output logic [7:0]  trap_code_wb,
	output logic        difftest_skip_wb
);
	logic        is_trap_wb;
	logic [63:0] hw_mip, interrupt_pending_mask_wb, interrupt_cause_wb;
	logic        interrupt_enabled_wb, interrupt_pending_wb, mstatus_mie_effective_wb;
	logic        interrupt_request_wb, system_redirect_ready_wb;
	logic        exception_commit_wb, ecall_commit_wb, mret_commit_wb;
	logic        interrupt_commit_wb, trap_commit_wb, system_pending_wb;

	assign is_trap_wb = inst_valid_wb && (instr_wb == TRAP_INST);
	assign commit_valid_wb = inst_valid_wb && !wb_fired;
	assign hw_mip = (swint ? MIP_MSIP : 64'b0) |
		(trint ? MIP_MTIP : 64'b0) |
		(exint ? MIP_MEIP : 64'b0);
	assign interrupt_pending_mask_wb = (csr_mip_irq_q | hw_mip) & csr_mie_irq_q &
		(MIP_MSIP | MIP_MTIP | MIP_MEIP);
	assign interrupt_pending_wb = interrupt_pending_mask_wb != 64'b0;
	assign mstatus_mie_effective_wb = mstatus_mie_after_wb(
		csr_mstatus_pre_trap,
		commit_valid_wb && csr_write_enable_wb && !exception_valid_wb && !is_ecall_wb && !is_mret_wb,
		csr_op_wb,
		csr_addr_wb,
		csr_write_data_wb
	);
	assign interrupt_enabled_wb = (priv_mode_q != PRIV_M) || mstatus_mie_effective_wb;
	always_comb begin
		if (interrupt_pending_mask_wb[11])
			interrupt_cause_wb = CAUSE_IRQ_EXTERNAL;
		else if (interrupt_pending_mask_wb[7])
			interrupt_cause_wb = CAUSE_IRQ_TIMER;
		else
			interrupt_cause_wb = CAUSE_IRQ_SW;
	end
	assign interrupt_request_wb = commit_valid_wb && !exception_valid_wb &&
		!is_ecall_wb && !is_mret_wb && interrupt_enabled_wb && interrupt_pending_wb;
	assign system_pending_wb = commit_valid_wb &&
		(exception_valid_wb || is_ecall_wb || is_mret_wb || interrupt_request_wb);
	assign system_redirect_ready_wb = !fetch_wait_q && !mem_wait_q;
	assign system_wb_waiting = system_pending_wb && !system_redirect_ready_wb;
	assign commit_fire_wb = commit_valid_wb && !system_wb_waiting;
	assign exception_commit_wb = exception_valid_wb && commit_fire_wb;
	assign ecall_commit_wb = is_ecall_wb && commit_fire_wb;
	assign mret_commit_wb = is_mret_wb && commit_fire_wb;
	assign interrupt_commit_wb = interrupt_request_wb && commit_fire_wb;
	assign trap_commit_wb = exception_commit_wb || ecall_commit_wb || interrupt_commit_wb;
	assign system_flush_front = system_event_ex || system_event_mem || system_pending_wb;
	assign reg_write_wb_fire = reg_write_wb && commit_fire_wb && !exception_commit_wb &&
		!ecall_commit_wb && !mret_commit_wb && (rd_wb != 5'b0);
	assign csr_write_wb_fire = csr_write_enable_wb && commit_fire_wb &&
		!exception_commit_wb && !ecall_commit_wb && !mret_commit_wb;
	assign system_redirect_fire_wb = trap_commit_wb || mret_commit_wb;
	assign system_redirect_target_wb = mret_commit_wb ? csr_mepc : csr_mtvec;
	assign csr_trap_wen_wb = trap_commit_wb;
	assign csr_mret_wen_wb = mret_commit_wb;
	assign csr_trap_mepc_wb = interrupt_commit_wb ? (pc_wb + 64'd4) : pc_wb;
	assign csr_trap_mcause_wb = interrupt_commit_wb ? interrupt_cause_wb :
		(exception_commit_wb ? exception_cause_wb : ecall_cause(priv_mode_q));
	assign csr_trap_mtval_wb = exception_commit_wb ? exception_tval_wb : 64'b0;
	assign priv_mode_view = trap_commit_wb ? PRIV_M :
		(mret_commit_wb ? csr_mret_priv : priv_mode_q);
	assign trap_valid_wb = is_trap_wb && commit_fire_wb;
	assign trap_code_wb = trap_code_in;
	assign difftest_skip_wb = ((mem_read_wb || mem_write_wb) && (alu_result_wb[31] == 1'b0)) ||
		(is_csr_wb && (csr_addr_wb == 12'h3a0 || csr_addr_wb == 12'h3b0));
endmodule

`endif
