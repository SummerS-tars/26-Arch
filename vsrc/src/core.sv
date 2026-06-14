`ifndef __CORE_SV
`define __CORE_SV

`ifdef VERILATOR
`include "include/common.sv"
`include "include/trap.sv"
`include "include/mem_helpers.sv"
`endif

module core import common::*; import trap_pkg::*; import mem_helpers_pkg::*;(
	input  logic       clk, reset,
	output ibus_req_t  ireq,
	input  ibus_resp_t iresp,
	output dbus_req_t  dreq,
	input  dbus_resp_t dresp,
	input  logic       trint, swint, exint,
	output priv_mode_t priv_mode_o,
	output u64         satp_o
);
	// ========== 1. Register File ==========
	logic [63:0] wb_data;
	logic        reg_write_wb_fire, wb_fired;
	logic [63:0] rs1_data_id_r, rs2_data_id_r;
	logic [31:0][63:0] rf_dbg;
	logic [63:0] cycle_cnt, instr_cnt;
	logic        trap_valid_wb, is_trap_wb;
	logic [7:0]  trap_code_wb;
	logic        system_redirect_fire_wb;
	logic [63:0] system_redirect_target_wb;
	logic        commit_fire_wb, commit_valid_wb;
	logic        system_event_ex, system_event_mem, system_flush_front;
	logic        csr_trap_wen_wb, csr_mret_wen_wb;
	logic [63:0] csr_trap_mepc_wb, csr_trap_mcause_wb, csr_trap_mtval_wb;
	logic        csr_write_wb_fire;
	priv_mode_t  priv_mode_q, priv_mode_view, csr_mret_priv;

	id_ex_t  id_ex_q;
	ex_mem_t ex_mem_q;
	mem_wb_t mem_wb_q;

	// ========== 2. PC & IF ==========
	logic [63:0] pc, next_pc;
	logic        stall, fetch_wait, mem_wait, mem_access_mem;
	logic        fetch_wait_q, mem_wait_q;
	logic        redirect_valid_ex, redirect_fire_ex;
	logic [63:0] redirect_target_ex;

	assign next_pc = system_redirect_fire_wb ? system_redirect_target_wb :
		(redirect_fire_ex ? redirect_target_ex : (pc + 64'd4));

	always_ff @(posedge clk) begin
		if (reset)
			pc <= PCINIT;
		else if (system_redirect_fire_wb || redirect_fire_ex || !stall)
			pc <= next_pc;
	end

	assign ireq.valid = ~load_use_hazard && !mem_access_mem;
	assign ireq.addr  = pc;

	// ========== 3. IF_ID Reg ==========
	logic [63:0] pc_id;
	logic [31:0] instr_id;
	logic        inst_valid_id;

	always_ff @(posedge clk) begin
		if (reset || system_redirect_fire_wb || redirect_fire_ex) begin
			pc_id         <= 64'b0;
			instr_id      <= 32'b0;
			inst_valid_id <= 1'b0;
		end else if (!stall) begin
			pc_id         <= pc;
			instr_id      <= iresp.data;
			inst_valid_id <= iresp.data_ok;
		end
	end

	// ========== 4. ID Decode ==========
	decode_out_t decode_id;
	logic [4:0]  rd_id, rs1_id, rs2_id;
	logic [2:0]  funct3_id;
	logic [6:0]  funct7_id;
	logic [63:0] imm_id;
	alu_op_t     alu_op_id;
	logic        alu_src_id, use_pc_id, is_branch_id, is_jump_id, is_jalr_id;
	logic        is_csr_id, is_ecall_id, is_mret_id, csr_uses_imm_id;
	csr_op_t     csr_op_id;
	csr_addr_t   csr_addr_id;
	logic [63:0] csr_zimm_id;
	logic        mem_read_id, mem_write_id, reg_write_id, is_illegal_id;
	wb_sel_t     wb_sel_id;

	core_decode decode(
		.instr      (instr_id),
		.decode_out (decode_id)
	);

	assign rd_id        = decode_id.rd;
	assign rs1_id       = decode_id.rs1;
	assign rs2_id       = decode_id.rs2;
	assign funct3_id    = decode_id.funct3;
	assign funct7_id    = decode_id.funct7;
	assign imm_id       = decode_id.imm;
	assign alu_op_id    = decode_id.alu_op;
	assign alu_src_id   = decode_id.alu_src;
	assign use_pc_id    = decode_id.use_pc;
	assign mem_read_id  = decode_id.mem_read;
	assign mem_write_id = decode_id.mem_write;
	assign reg_write_id = decode_id.reg_write;
	assign is_branch_id = decode_id.is_branch;
	assign is_jump_id   = decode_id.is_jump;
	assign is_jalr_id   = decode_id.is_jalr;
	assign is_csr_id    = decode_id.is_csr;
	assign is_ecall_id  = decode_id.is_ecall;
	assign is_mret_id   = decode_id.is_mret;
	assign is_illegal_id = decode_id.is_illegal;
	assign csr_op_id    = decode_id.csr_op;
	assign csr_addr_id  = decode_id.csr_addr;
	assign csr_uses_imm_id = decode_id.csr_uses_imm;
	assign csr_zimm_id  = decode_id.csr_zimm;
	assign wb_sel_id    = decode_id.wb_sel;

	core_regfile regfile(
		.clk      (clk),
		.reset    (reset),
		.wen      (reg_write_wb_fire),
		.waddr    (mem_wb_q.rd),
		.wdata    (wb_data),
		.raddr1   (rs1_id),
		.raddr2   (rs2_id),
		.rdata1   (rs1_data_id_r),
		.rdata2   (rs2_data_id_r),
		.regs_dbg (rf_dbg)
	);

	// ========== 5. ID_EX Reg ==========
	always_ff @(posedge clk) begin
		if (reset || system_redirect_fire_wb || redirect_fire_ex) begin
			id_ex_q <= id_ex_bubble();
		end else if ((system_event_ex && !fetch_wait && !mem_wait) ||
			(system_event_mem && !fetch_wait && !mem_wait) ||
			(load_use_hazard && !mem_wait && !fetch_wait) ||
			(mem_access_mem && !mem_wait && !fetch_wait)) begin
			id_ex_q <= id_ex_bubble();
		end else if (!stall) begin
			id_ex_q.pc              <= pc_id;
			id_ex_q.instr           <= instr_id;
			id_ex_q.inst_valid      <= inst_valid_id;
			id_ex_q.rs1_data        <= rs1_data_id_r;
			id_ex_q.rs2_data        <= rs2_data_id_r;
			id_ex_q.rd              <= rd_id;
			id_ex_q.rs1             <= rs1_id;
			id_ex_q.rs2             <= rs2_id;
			id_ex_q.imm             <= imm_id;
			id_ex_q.csr_zimm        <= csr_zimm_id;
			id_ex_q.funct3          <= funct3_id;
			id_ex_q.funct7          <= funct7_id;
			id_ex_q.alu_op          <= alu_op_id;
			id_ex_q.alu_src         <= alu_src_id;
			id_ex_q.use_pc          <= use_pc_id;
			id_ex_q.mem_read        <= mem_read_id;
			id_ex_q.mem_write       <= mem_write_id;
			id_ex_q.reg_write       <= reg_write_id;
			id_ex_q.exception_valid <= inst_valid_id && is_illegal_id;
			id_ex_q.exception_cause <= CAUSE_ILLEGAL_INST;
			id_ex_q.exception_tval  <= 64'b0;
			id_ex_q.is_branch       <= is_branch_id;
			id_ex_q.is_jump         <= is_jump_id;
			id_ex_q.is_jalr         <= is_jalr_id;
			id_ex_q.is_csr          <= is_csr_id;
			id_ex_q.is_ecall        <= is_ecall_id;
			id_ex_q.is_mret         <= is_mret_id;
			id_ex_q.csr_op          <= csr_op_id;
			id_ex_q.csr_addr        <= csr_addr_id;
			id_ex_q.csr_uses_imm    <= csr_uses_imm_id;
			id_ex_q.wb_sel          <= wb_sel_id;
		end
	end

	// ========== Phase 3: Hazard Detection & Stall ==========
	logic load_use_hazard;

	core_hazard_unit hazard_unit(
		.mem_read_ex     (id_ex_q.mem_read),
		.rd_ex           (id_ex_q.rd),
		.rs1_id          (rs1_id),
		.rs2_id          (rs2_id),
		.load_use_hazard (load_use_hazard)
	);

	assign fetch_wait = ireq.valid && !iresp.data_ok;
	assign stall = load_use_hazard || fetch_wait || mem_access_mem || system_wb_waiting;

	always_ff @(posedge clk) begin
		if (reset) begin
			fetch_wait_q <= 1'b0;
			mem_wait_q   <= 1'b0;
		end else begin
			fetch_wait_q <= fetch_wait;
			mem_wait_q   <= mem_wait;
		end
	end

	// ========== 6. EX ALU (Phase 3: Forwarding) ==========
	logic [63:0] rs1_forwarded_ex, rs2_forwarded_ex, alu_in_a_ex, alu_in_b_ex;
	logic [63:0] forward_data_mem;
	logic [63:0] alu_result_ex;
	logic [63:0] redirect_target_raw_ex;
	logic        control_target_misaligned_ex, mem_misaligned_ex;
	logic        exception_valid_ex_eff;
	logic [63:0] exception_cause_ex_eff, exception_tval_ex_eff;
	logic        branch_taken_ex;
	logic [63:0] csr_read_data_ex, csr_write_data_ex;
	logic        csr_write_enable_ex;
	logic [63:0] csr_mstatus, csr_mstatus_pre_trap, csr_sstatus, csr_mepc, csr_sepc;
	logic [63:0] csr_mtval, csr_stval, csr_mtvec, csr_stvec;
	logic [63:0] csr_mcause, csr_scause, csr_satp, csr_mip, csr_mie;
	logic [63:0] csr_mscratch, csr_sscratch, csr_mideleg, csr_medeleg;
	logic [63:0] csr_mcycle, csr_mhartid;
	logic [63:0] csr_mip_irq_q, csr_mie_irq_q;
	logic        system_wb_waiting;

	core_csr csr_file(
		.clk       (clk),
		.reset     (reset),
		.raddr     (id_ex_q.csr_addr),
		.rdata     (csr_read_data_ex),
		.wen       (csr_write_wb_fire),
		.wop       (mem_wb_q.csr_op),
		.waddr     (mem_wb_q.csr_addr),
		.wdata     (mem_wb_q.csr_write_data),
		.trap_wen  (csr_trap_wen_wb),
		.trap_mepc (csr_trap_mepc_wb),
		.trap_mcause (csr_trap_mcause_wb),
		.trap_mtval (csr_trap_mtval_wb),
		.trap_prev_priv (priv_mode_q),
		.mret_wen  (csr_mret_wen_wb),
		.mret_priv (csr_mret_priv),
		.mstatus   (csr_mstatus),
		.mstatus_pre_trap (csr_mstatus_pre_trap),
		.sstatus   (csr_sstatus),
		.mepc      (csr_mepc),
		.sepc      (csr_sepc),
		.mtval     (csr_mtval),
		.stval     (csr_stval),
		.mtvec     (csr_mtvec),
		.stvec     (csr_stvec),
		.mcause    (csr_mcause),
		.scause    (csr_scause),
		.satp      (csr_satp),
		.mip       (csr_mip),
		.mie       (csr_mie),
		.mscratch  (csr_mscratch),
		.sscratch  (csr_sscratch),
		.mideleg   (csr_mideleg),
		.medeleg   (csr_medeleg),
		.mcycle    (csr_mcycle),
		.mhartid   (csr_mhartid)
	);

	always_ff @(posedge clk) begin
		if (reset) begin
			csr_mip_irq_q <= 64'b0;
			csr_mie_irq_q <= 64'b0;
		end else begin
			csr_mip_irq_q <= csr_mip;
			csr_mie_irq_q <= csr_mie;
		end
	end

	core_forwarding_unit forwarding_unit(
		.rs1_ex         (id_ex_q.rs1),
		.rs2_ex         (id_ex_q.rs2),
		.rs1_data_ex    (id_ex_q.rs1_data),
		.rs2_data_ex    (id_ex_q.rs2_data),
		.reg_write_mem  (ex_mem_q.reg_write),
		.rd_mem         (ex_mem_q.rd),
		.forward_data_mem (forward_data_mem),
		.reg_write_wb   (mem_wb_q.reg_write),
		.rd_wb          (mem_wb_q.rd),
		.wb_data        (wb_data),
		.op_a_forwarded (rs1_forwarded_ex),
		.rs2_forwarded  (rs2_forwarded_ex)
	);

	assign alu_in_a_ex = id_ex_q.use_pc ? id_ex_q.pc : rs1_forwarded_ex;
	assign alu_in_b_ex = id_ex_q.alu_src ? id_ex_q.imm : rs2_forwarded_ex;
	assign csr_write_data_ex = id_ex_q.csr_uses_imm ? id_ex_q.csr_zimm : rs1_forwarded_ex;
	assign csr_write_enable_ex = id_ex_q.is_csr &&
		((id_ex_q.csr_op == CSR_OP_WRITE) ||
		 (id_ex_q.csr_uses_imm ? (id_ex_q.csr_zimm[4:0] != 5'b0) : (id_ex_q.rs1 != 5'b0)));

	core_alu alu(
		.alu_op (id_ex_q.alu_op),
		.op_a   (alu_in_a_ex),
		.op_b   (alu_in_b_ex),
		.result (alu_result_ex)
	);

	always_comb begin
		branch_taken_ex = 1'b0;
		case (id_ex_q.funct3)
			3'b000:  branch_taken_ex = (rs1_forwarded_ex == rs2_forwarded_ex);
			3'b001:  branch_taken_ex = (rs1_forwarded_ex != rs2_forwarded_ex);
			3'b100:  branch_taken_ex = ($signed(rs1_forwarded_ex) < $signed(rs2_forwarded_ex));
			3'b101:  branch_taken_ex = ($signed(rs1_forwarded_ex) >= $signed(rs2_forwarded_ex));
			3'b110:  branch_taken_ex = (rs1_forwarded_ex < rs2_forwarded_ex);
			3'b111:  branch_taken_ex = (rs1_forwarded_ex >= rs2_forwarded_ex);
			default: ;
		endcase
	end

	assign redirect_target_raw_ex = id_ex_q.is_jalr ? (rs1_forwarded_ex + id_ex_q.imm) :
		(id_ex_q.pc + id_ex_q.imm);
	assign redirect_target_ex = id_ex_q.is_csr ? (id_ex_q.pc + 64'd4) :
		(id_ex_q.is_jalr ? (redirect_target_raw_ex & ~64'd1) : redirect_target_raw_ex);
	assign control_target_misaligned_ex = id_ex_q.inst_valid &&
		(id_ex_q.is_jump || (id_ex_q.is_branch && branch_taken_ex)) &&
		(redirect_target_raw_ex[1:0] != 2'b00);
	assign mem_misaligned_ex = id_ex_q.inst_valid && (id_ex_q.mem_read || id_ex_q.mem_write) &&
		mem_addr_misaligned(alu_result_ex, mem_size_from_funct3(id_ex_q.funct3));
	assign exception_valid_ex_eff = id_ex_q.exception_valid || control_target_misaligned_ex ||
		mem_misaligned_ex;
	assign exception_cause_ex_eff = control_target_misaligned_ex ? CAUSE_INST_MISALIGNED :
		(mem_misaligned_ex ? (id_ex_q.mem_read ? CAUSE_LOAD_MISALIGNED : CAUSE_STORE_MISALIGNED) :
		 id_ex_q.exception_cause);
	assign exception_tval_ex_eff = control_target_misaligned_ex ? redirect_target_raw_ex :
		(mem_misaligned_ex ? alu_result_ex : id_ex_q.exception_tval);
	assign system_event_ex = id_ex_q.inst_valid &&
		(exception_valid_ex_eff || id_ex_q.is_ecall || id_ex_q.is_mret);
	assign redirect_valid_ex = id_ex_q.inst_valid && !exception_valid_ex_eff &&
		(id_ex_q.is_csr || id_ex_q.is_jump || (id_ex_q.is_branch && branch_taken_ex));
	assign redirect_fire_ex = redirect_valid_ex && !fetch_wait && !mem_wait;

	// ========== 7. EX_MEM Reg ==========
	always_ff @(posedge clk) begin
		if (reset || system_redirect_fire_wb) begin
			ex_mem_q <= ex_mem_bubble();
		end else if (!fetch_wait && !mem_wait) begin
			ex_mem_q.pc              <= id_ex_q.pc;
			ex_mem_q.instr           <= id_ex_q.instr;
			ex_mem_q.inst_valid      <= id_ex_q.inst_valid;
			ex_mem_q.alu_result      <= alu_result_ex;
			ex_mem_q.rs2_data        <= rs2_forwarded_ex;
			ex_mem_q.csr_read_data   <= csr_read_data_ex;
			ex_mem_q.csr_write_data  <= csr_write_data_ex;
			ex_mem_q.rd              <= id_ex_q.rd;
			ex_mem_q.funct3          <= id_ex_q.funct3;
			ex_mem_q.mem_read        <= id_ex_q.mem_read;
			ex_mem_q.mem_write       <= id_ex_q.mem_write;
			ex_mem_q.reg_write       <= id_ex_q.reg_write;
			ex_mem_q.exception_valid <= exception_valid_ex_eff;
			ex_mem_q.exception_cause <= exception_cause_ex_eff;
			ex_mem_q.exception_tval  <= exception_tval_ex_eff;
			ex_mem_q.is_csr          <= id_ex_q.is_csr;
			ex_mem_q.is_ecall        <= id_ex_q.is_ecall;
			ex_mem_q.is_mret         <= id_ex_q.is_mret;
			ex_mem_q.csr_write_enable <= csr_write_enable_ex;
			ex_mem_q.csr_op          <= id_ex_q.csr_op;
			ex_mem_q.csr_addr        <= id_ex_q.csr_addr;
			ex_mem_q.wb_sel          <= id_ex_q.wb_sel;
		end
	end

	assign forward_data_mem = (ex_mem_q.wb_sel == WB_PC4) ? (ex_mem_q.pc + 64'd4) :
		((ex_mem_q.wb_sel == WB_CSR) ? ex_mem_q.csr_read_data : ex_mem_q.alu_result);

	// ========== 8. MEM ==========
	logic [63:0] load_data_mem, store_data_aligned_mem;
	strobe_t     store_strobe_mem;
	msize_t      mem_size_mem;

	assign mem_access_mem = ex_mem_q.inst_valid && !ex_mem_q.exception_valid &&
		(ex_mem_q.mem_read || ex_mem_q.mem_write);
	assign mem_wait = mem_access_mem && !dresp.data_ok;
	assign mem_size_mem = mem_size_from_funct3(ex_mem_q.funct3);
	assign store_strobe_mem = store_strobe_from_funct3(ex_mem_q.funct3, ex_mem_q.alu_result[2:0]);
	assign store_data_aligned_mem = align_store_data(ex_mem_q.rs2_data, ex_mem_q.alu_result[2:0]);
	assign load_data_mem = extend_load_data(dresp.data, ex_mem_q.alu_result[2:0], ex_mem_q.funct3);
	assign system_event_mem = ex_mem_q.inst_valid &&
		(ex_mem_q.exception_valid || ex_mem_q.is_ecall || ex_mem_q.is_mret);

	assign dreq.valid  = mem_access_mem && !ex_mem_q.exception_valid;
	assign dreq.addr   = ex_mem_q.alu_result;
	assign dreq.size   = mem_size_mem;
	assign dreq.strobe = ex_mem_q.mem_write ? store_strobe_mem : 8'b0;
	assign dreq.data   = store_data_aligned_mem;

	// ========== 9. MEM_WB Reg ==========
	always_ff @(posedge clk) begin
		if (reset || system_redirect_fire_wb) begin
			mem_wb_q <= mem_wb_bubble();
		end else if (!fetch_wait && !mem_wait) begin
			mem_wb_q.pc              <= ex_mem_q.pc;
			mem_wb_q.instr           <= ex_mem_q.instr;
			mem_wb_q.inst_valid      <= ex_mem_q.inst_valid;
			mem_wb_q.alu_result      <= ex_mem_q.alu_result;
			mem_wb_q.mem_data        <= load_data_mem;
			mem_wb_q.csr_read_data   <= ex_mem_q.csr_read_data;
			mem_wb_q.csr_write_data  <= ex_mem_q.csr_write_data;
			mem_wb_q.rd              <= ex_mem_q.rd;
			mem_wb_q.funct3          <= ex_mem_q.funct3;
			mem_wb_q.mem_read        <= ex_mem_q.mem_read;
			mem_wb_q.mem_write       <= ex_mem_q.mem_write;
			mem_wb_q.reg_write       <= ex_mem_q.reg_write;
			mem_wb_q.exception_valid <= ex_mem_q.exception_valid;
			mem_wb_q.exception_cause <= ex_mem_q.exception_cause;
			mem_wb_q.exception_tval  <= ex_mem_q.exception_tval;
			mem_wb_q.is_csr          <= ex_mem_q.is_csr;
			mem_wb_q.is_ecall        <= ex_mem_q.is_ecall;
			mem_wb_q.is_mret         <= ex_mem_q.is_mret;
			mem_wb_q.csr_write_enable <= ex_mem_q.csr_write_enable;
			mem_wb_q.csr_op          <= ex_mem_q.csr_op;
			mem_wb_q.csr_addr        <= ex_mem_q.csr_addr;
			mem_wb_q.wb_sel          <= ex_mem_q.wb_sel;
		end
	end

	// ========== 10. WB ==========
	always_comb begin
		case (mem_wb_q.wb_sel)
			WB_MEM: wb_data = mem_wb_q.mem_data;
			WB_PC4: wb_data = mem_wb_q.pc + 64'd4;
			WB_CSR: wb_data = mem_wb_q.csr_read_data;
			default: wb_data = mem_wb_q.alu_result;
		endcase
	end

	core_trap_ctrl trap_ctrl(
		.inst_valid_wb       (mem_wb_q.inst_valid),
		.pc_wb               (mem_wb_q.pc),
		.instr_wb            (mem_wb_q.instr),
		.exception_valid_wb  (mem_wb_q.exception_valid),
		.exception_cause_wb  (mem_wb_q.exception_cause),
		.exception_tval_wb   (mem_wb_q.exception_tval),
		.is_ecall_wb         (mem_wb_q.is_ecall),
		.is_mret_wb          (mem_wb_q.is_mret),
		.csr_write_enable_wb (mem_wb_q.csr_write_enable),
		.csr_op_wb           (mem_wb_q.csr_op),
		.csr_addr_wb         (mem_wb_q.csr_addr),
		.csr_write_data_wb   (mem_wb_q.csr_write_data),
		.reg_write_wb        (mem_wb_q.reg_write),
		.rd_wb               (mem_wb_q.rd),
		.wb_fired            (wb_fired),
		.priv_mode_q         (priv_mode_q),
		.csr_mstatus_pre_trap (csr_mstatus_pre_trap),
		.csr_mie_irq_q       (csr_mie_irq_q),
		.csr_mip_irq_q       (csr_mip_irq_q),
		.csr_mepc            (csr_mepc),
		.csr_mtvec           (csr_mtvec),
		.csr_mret_priv       (csr_mret_priv),
		.swint               (swint),
		.trint               (trint),
		.exint               (exint),
		.fetch_wait_q        (fetch_wait_q),
		.mem_wait_q          (mem_wait_q),
		.system_event_ex     (system_event_ex),
		.system_event_mem    (system_event_mem),
		.trap_code_in        (rf_dbg[10][7:0]),
		.commit_valid_wb     (commit_valid_wb),
		.commit_fire_wb      (commit_fire_wb),
		.reg_write_wb_fire   (reg_write_wb_fire),
		.csr_write_wb_fire   (csr_write_wb_fire),
		.system_wb_waiting   (system_wb_waiting),
		.system_flush_front  (system_flush_front),
		.system_redirect_fire_wb (system_redirect_fire_wb),
		.system_redirect_target_wb (system_redirect_target_wb),
		.csr_trap_wen_wb     (csr_trap_wen_wb),
		.csr_mret_wen_wb     (csr_mret_wen_wb),
		.csr_trap_mepc_wb    (csr_trap_mepc_wb),
		.csr_trap_mcause_wb  (csr_trap_mcause_wb),
		.csr_trap_mtval_wb   (csr_trap_mtval_wb),
		.priv_mode_view      (priv_mode_view),
		.trap_valid_wb       (trap_valid_wb),
		.trap_code_wb        (trap_code_wb)
	);

	assign priv_mode_o = priv_mode_view;
	assign satp_o = csr_satp;
	assign is_trap_wb = mem_wb_q.inst_valid && (mem_wb_q.instr == TRAP_INST);

	always_ff @(posedge clk) begin
		if (reset) begin
			wb_fired <= 1'b0;
		end else if (system_redirect_fire_wb) begin
			wb_fired <= 1'b0;
		end else if (!fetch_wait && !mem_wait) begin
			wb_fired <= 1'b0;
		end else if (commit_fire_wb) begin
			wb_fired <= 1'b1;
		end
	end

	always_ff @(posedge clk) begin
		if (reset) begin
			priv_mode_q <= PRIV_M;
		end else if (csr_trap_wen_wb) begin
			priv_mode_q <= PRIV_M;
		end else if (csr_mret_wen_wb) begin
			priv_mode_q <= csr_mret_priv;
		end
	end

	always_ff @(posedge clk) begin
		if (reset) begin
			cycle_cnt <= 64'b0;
			instr_cnt <= 64'b0;
		end else begin
			cycle_cnt <= cycle_cnt + 64'd1;
			if (commit_fire_wb && !is_trap_wb)
				instr_cnt <= instr_cnt + 64'd1;
		end
	end

`ifdef VERILATOR
	localparam logic [63:0] PERF_PRINT_PERIOD = 64'd10_000_000;
	logic [63:0] perf_print_cnt;
	logic [63:0] perf_branch_total, perf_branch_taken, perf_branch_nt_correct;
	logic [63:0] perf_jump_total, perf_jalr_total;
	logic [63:0] perf_ex_redirects, perf_system_redirects;
	logic [63:0] perf_load_use_stalls, perf_fetch_waits, perf_mem_waits;
	logic        perf_ex_fire;

	assign perf_ex_fire = id_ex_q.inst_valid && !fetch_wait && !mem_wait && !system_redirect_fire_wb;

	always_ff @(posedge clk) begin
		if (reset) begin
			perf_print_cnt        <= 64'b0;
			perf_branch_total     <= 64'b0;
			perf_branch_taken     <= 64'b0;
			perf_branch_nt_correct <= 64'b0;
			perf_jump_total       <= 64'b0;
			perf_jalr_total       <= 64'b0;
			perf_ex_redirects     <= 64'b0;
			perf_system_redirects <= 64'b0;
			perf_load_use_stalls  <= 64'b0;
			perf_fetch_waits      <= 64'b0;
			perf_mem_waits        <= 64'b0;
		end else begin
			if (perf_ex_fire && id_ex_q.is_branch && !exception_valid_ex_eff) begin
				perf_branch_total <= perf_branch_total + 64'd1;
				if (branch_taken_ex)
					perf_branch_taken <= perf_branch_taken + 64'd1;
				else
					perf_branch_nt_correct <= perf_branch_nt_correct + 64'd1;
			end

			if (perf_ex_fire && id_ex_q.is_jump && !exception_valid_ex_eff) begin
				perf_jump_total <= perf_jump_total + 64'd1;
				if (id_ex_q.is_jalr)
					perf_jalr_total <= perf_jalr_total + 64'd1;
			end

			if (redirect_fire_ex)
				perf_ex_redirects <= perf_ex_redirects + 64'd1;
			if (system_redirect_fire_wb)
				perf_system_redirects <= perf_system_redirects + 64'd1;
			if (load_use_hazard)
				perf_load_use_stalls <= perf_load_use_stalls + 64'd1;
			if (fetch_wait)
				perf_fetch_waits <= perf_fetch_waits + 64'd1;
			if (mem_wait)
				perf_mem_waits <= perf_mem_waits + 64'd1;

			if (`BENCHMARK) begin
				if (perf_print_cnt == PERF_PRINT_PERIOD - 64'd1) begin
					$display("[perf] cycles=%0d instr=%0d ipc_x1000=%0d branches=%0d taken=%0d nt_pred_ok=%0d jumps=%0d jalr=%0d ex_redirects=%0d system_redirects=%0d load_use_stalls=%0d fetch_waits=%0d mem_waits=%0d",
						cycle_cnt,
						instr_cnt,
						(cycle_cnt == 64'b0) ? 64'b0 : ((instr_cnt * 64'd1000) / cycle_cnt),
						perf_branch_total,
						perf_branch_taken,
						perf_branch_nt_correct,
						perf_jump_total,
						perf_jalr_total,
						perf_ex_redirects,
						perf_system_redirects,
						perf_load_use_stalls,
						perf_fetch_waits,
						perf_mem_waits);
					perf_print_cnt <= 64'b0;
				end else begin
					perf_print_cnt <= perf_print_cnt + 64'd1;
				end
			end
		end
	end

	core_difftest_adapter difftest_adapter(
		.clk            (clk),
		.coreid         (csr_mhartid[7:0]),
		.commit_valid   (commit_fire_wb),
		.pc             (mem_wb_q.pc),
		.instr          (mem_wb_q.instr),
		.reg_write_fire (reg_write_wb_fire),
		.rd             (mem_wb_q.rd),
		.wb_data        (wb_data),
		.mem_read_wb    (mem_wb_q.mem_read),
		.mem_write_wb   (mem_wb_q.mem_write),
		.alu_result_wb  (mem_wb_q.alu_result),
		.is_csr_wb      (mem_wb_q.is_csr),
		.csr_addr_wb    (mem_wb_q.csr_addr),
		.trap_valid     (trap_valid_wb),
		.trap_code      (trap_code_wb[2:0]),
		.cycle_cnt      (cycle_cnt),
		.instr_cnt      (instr_cnt),
		.priv_mode      (priv_mode_view),
		.gpr_dbg        (rf_dbg),
		.mstatus        (csr_mstatus),
		.sstatus        (csr_sstatus),
		.mepc           (csr_mepc),
		.sepc           (csr_sepc),
		.mtval          (csr_mtval),
		.stval          (csr_stval),
		.mtvec          (csr_mtvec),
		.stvec          (csr_stvec),
		.mcause         (csr_mcause),
		.scause         (csr_scause),
		.satp           (csr_satp),
		.mip            (csr_mip),
		.mie            (csr_mie),
		.mscratch       (csr_mscratch),
		.sscratch       (csr_sscratch),
		.mideleg        (csr_mideleg),
		.medeleg        (csr_medeleg)
	);
`endif
endmodule
`endif
