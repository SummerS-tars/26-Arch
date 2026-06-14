`ifndef __CORE_CSR_SV
`define __CORE_CSR_SV

`ifdef VERILATOR
`include "include/common.sv"
`include "include/csr.sv"
`endif

module core_csr
    import common::*;
    import csr_pkg::*;
(
    input  logic      clk,
    input  logic      reset,

    input  csr_addr_t raddr,
    output u64        rdata,

    input  logic      wen,
    input  csr_op_t   wop,
    input  csr_addr_t waddr,
    input  u64        wdata,

    input  logic       trap_wen,
    input  u64         trap_mepc,
    input  u64         trap_mcause,
    input  u64         trap_mtval,
    input  priv_mode_t trap_prev_priv,
    input  logic       trap_to_s,
    input  logic       mret_wen,
    output priv_mode_t mret_priv,
    input  logic       sret_wen,
    output priv_mode_t sret_priv,

    output u64        mstatus,
    output u64        mstatus_pre_trap,
    output u64        sstatus,
    output u64        mepc,
    output u64        sepc,
    output u64        mtval,
    output u64        stval,
    output u64        mtvec,
    output u64        stvec,
    output u64        mcause,
    output u64        scause,
    output u64        satp,
    output u64        mip,
    output u64        mie,
    output u64        mscratch,
    output u64        sscratch,
    output u64        mideleg,
    output u64        medeleg,
    output u64        pmpaddr0,
    output u64        pmpcfg0,
    output u64        mcycle,
    output u64        mhartid
);
    localparam u64 SIE_MASK = 64'h222;
    localparam u64 SIP_MASK = 64'h222;
    localparam u64 SSTATUS_WRITABLE_MASK = SSTATUS_MASK & MSTATUS_MASK;

    // ----- registered CSR state -----
    u64 mstatus_q, mepc_q, sepc_q, mtval_q, stval_q;
    u64 mtvec_q, stvec_q, mcause_q, scause_q, satp_q;
    u64 mip_q, mie_q, mscratch_q, sscratch_q;
    u64 mideleg_q, medeleg_q, mcycle_q;
    u64 pmpaddr0_q, pmpcfg0_q;

    // ----- trap / mret state update helpers -----
    function automatic u64 mstatus_on_trap(
        input u64 status,
        input priv_mode_t prev_priv
    );
        begin
            mstatus_on_trap = status;
            mstatus_on_trap[7]     = status[3];   // MPIE <- MIE
            mstatus_on_trap[3]     = 1'b0;        // MIE <- 0
            mstatus_on_trap[12:11] = prev_priv;   // MPP <- previous privilege
            mstatus_on_trap = mstatus_on_trap & MSTATUS_MASK;
        end
    endfunction

    function automatic u64 mstatus_on_s_trap(
        input u64 status,
        input priv_mode_t prev_priv
    );
        begin
            mstatus_on_s_trap = status;
            mstatus_on_s_trap[5] = status[1];          // SPIE <- SIE
            mstatus_on_s_trap[1] = 1'b0;               // SIE <- 0
            mstatus_on_s_trap[8] = (prev_priv == PRIV_S); // SPP <- previous privilege
            mstatus_on_s_trap = mstatus_on_s_trap & MSTATUS_MASK;
        end
    endfunction

    function automatic u64 mstatus_on_mret(input u64 status);
        priv_mode_t old_mpp;
        begin
            old_mpp = priv_mode_t'(status[12:11]);
            mstatus_on_mret = status;
            mstatus_on_mret[3]     = status[7];   // MIE <- MPIE
            mstatus_on_mret[7]     = 1'b1;        // MPIE <- 1
            mstatus_on_mret[12:11] = PRIV_U;      // MPP <- least privileged mode
            if (old_mpp != PRIV_M)
                mstatus_on_mret[17] = 1'b0;       // MPRV <- 0 when returning below M
            mstatus_on_mret = mstatus_on_mret & MSTATUS_MASK;
        end
    endfunction

    function automatic u64 mstatus_on_sret(input u64 status);
        begin
            mstatus_on_sret = status;
            mstatus_on_sret[1]  = status[5]; // SIE <- SPIE
            mstatus_on_sret[5]  = 1'b1;      // SPIE <- 1
            mstatus_on_sret[8]  = 1'b0;      // SPP <- U
            mstatus_on_sret[17] = 1'b0;      // MPRV <- 0 when returning below M
            mstatus_on_sret = mstatus_on_sret & MSTATUS_MASK;
        end
    endfunction

    function automatic u64 mstatus_after_write(
        input u64        status,
        input logic      write_en,
        input csr_addr_t addr,
        input u64        data
    );
        begin
            mstatus_after_write = status;
            if (write_en) begin
                case (addr)
                    CSR_MSTATUS: mstatus_after_write = data & MSTATUS_MASK;
                    CSR_SSTATUS: mstatus_after_write = (status & ~SSTATUS_WRITABLE_MASK) |
                                                       (data & SSTATUS_WRITABLE_MASK);
                    default: ;
                endcase
            end
        end
    endfunction

    // ----- CSR read decode -----
    function automatic u64 csr_value(input csr_addr_t addr);
        begin
            case (addr)
                CSR_MSTATUS:  csr_value = mstatus_q;
                CSR_SSTATUS:  csr_value = mstatus_q & SSTATUS_MASK;
                CSR_MEPC:     csr_value = mepc_q;
                CSR_SEPC:     csr_value = sepc_q;
                CSR_MTVAL:    csr_value = mtval_q;
                CSR_STVAL:    csr_value = stval_q;
                CSR_MTVEC:    csr_value = mtvec_q;
                CSR_STVEC:    csr_value = stvec_q;
                CSR_MCAUSE:   csr_value = mcause_q;
                CSR_SCAUSE:   csr_value = scause_q;
                CSR_SATP:     csr_value = satp_q;
                CSR_MIP:      csr_value = mip_q;
                CSR_SIP:      csr_value = mip_q & SIP_MASK;
                CSR_MIE:      csr_value = mie_q;
                CSR_SIE:      csr_value = mie_q & SIE_MASK;
                CSR_MSCRATCH: csr_value = mscratch_q;
                CSR_SSCRATCH: csr_value = sscratch_q;
                CSR_MIDELEG:  csr_value = mideleg_q;
                CSR_MEDELEG:  csr_value = medeleg_q;
                CSR_MCYCLE:   csr_value = mcycle_q;
                CSR_MHARTID:  csr_value = 64'b0;
                CSR_PMPADDR0: csr_value = pmpaddr0_q;
                CSR_PMPCFG0:  csr_value = pmpcfg0_q;
                default:      csr_value = 64'b0;
            endcase
        end
    endfunction

    // ----- CSR write decode -----
    u64 write_old, write_next;

    assign write_old = csr_value(waddr);

    always_comb begin
        case (wop)
            CSR_OP_SET:   write_next = write_old | wdata;
            CSR_OP_CLEAR: write_next = write_old & ~wdata;
            default:      write_next = wdata;
        endcase
    end

    assign rdata = csr_value(raddr);

    // ----- write / trap / mret combinational view -----
    // mip/mie outputs reflect the post-write or post-trap view for Difftest.
    // core samples csr_mip_irq_q from the registered mip_q one cycle earlier for
    // interrupt pending arbitration, keeping hardware pending separate from the
    // architecturally visible value exported here.
    u64 mstatus_view, mepc_view, sepc_view, mtval_view, stval_view;
    u64 mtvec_view, stvec_view, mcause_view, scause_view, satp_view;
    u64 mip_view, mie_view, mscratch_view, sscratch_view;
    u64 mideleg_view, medeleg_view;

    always_comb begin
        mstatus_view  = mstatus_q;
        mepc_view     = mepc_q;
        sepc_view     = sepc_q;
        mtval_view    = mtval_q;
        stval_view    = stval_q;
        mtvec_view    = mtvec_q;
        stvec_view    = stvec_q;
        mcause_view   = mcause_q;
        scause_view   = scause_q;
        satp_view     = satp_q;
        mip_view      = mip_q;
        mie_view      = mie_q;
        mscratch_view = mscratch_q;
        sscratch_view = sscratch_q;
        mideleg_view  = mideleg_q;
        medeleg_view  = medeleg_q;

        if (wen) begin
            case (waddr)
                CSR_MSTATUS: begin
                    mstatus_view = write_next & MSTATUS_MASK;
                end
                CSR_SSTATUS: begin
                    mstatus_view = (mstatus_q & ~SSTATUS_WRITABLE_MASK) |
                                   (write_next & SSTATUS_WRITABLE_MASK);
                end
                CSR_MEPC:     mepc_view     = write_next;
                CSR_SEPC:     sepc_view     = write_next;
                CSR_MTVAL:    mtval_view    = write_next;
                CSR_STVAL:    stval_view    = write_next;
                CSR_MTVEC:    mtvec_view    = write_next & MTVEC_MASK;
                CSR_STVEC:    stvec_view    = write_next;
                CSR_MCAUSE:   mcause_view   = write_next;
                CSR_SCAUSE:   scause_view   = write_next;
                CSR_SATP:     satp_view     = write_next;
                CSR_MIP:      mip_view      = write_next & MIP_MASK;
                CSR_SIP:      mip_view      = (mip_q & ~SIP_MASK) | (write_next & SIP_MASK);
                CSR_MIE:      mie_view      = write_next;
                CSR_SIE:      mie_view      = (mie_q & ~SIE_MASK) | (write_next & SIE_MASK);
                CSR_MSCRATCH: mscratch_view = write_next;
                CSR_SSCRATCH: sscratch_view = write_next;
                CSR_MIDELEG:  mideleg_view  = write_next & MIDELEG_MASK;
                CSR_MEDELEG:  medeleg_view  = write_next & MEDELEG_MASK;
                default: ;
            endcase
        end

        if (trap_wen) begin
            if (trap_to_s) begin
                mstatus_view = mstatus_on_s_trap(
                    mstatus_after_write(mstatus_q, wen, waddr, write_next),
                    trap_prev_priv
                );
                sepc_view    = trap_mepc;
                scause_view  = trap_mcause;
                stval_view   = trap_mtval;
            end else begin
                mstatus_view = mstatus_on_trap(
                    mstatus_after_write(mstatus_q, wen, waddr, write_next),
                    trap_prev_priv
                );
                mepc_view    = trap_mepc;
                mcause_view  = trap_mcause;
                mtval_view   = trap_mtval;
            end
        end else if (mret_wen) begin
            mstatus_view = mstatus_on_mret(mstatus_q);
        end else if (sret_wen) begin
            mstatus_view = mstatus_on_sret(mstatus_q);
        end
    end

    // ----- registered CSR update -----
    always_ff @(posedge clk) begin
        if (reset) begin
            mstatus_q  <= 64'b0;
            mepc_q     <= 64'b0;
            sepc_q     <= 64'b0;
            mtval_q    <= 64'b0;
            stval_q    <= 64'b0;
            mtvec_q    <= 64'b0;
            stvec_q    <= 64'b0;
            mcause_q   <= 64'b0;
            scause_q   <= 64'b0;
            satp_q     <= 64'b0;
            mip_q      <= 64'b0;
            mie_q      <= 64'b0;
            mscratch_q <= 64'b0;
            sscratch_q <= 64'b0;
            mideleg_q  <= 64'b0;
            medeleg_q  <= 64'b0;
            mcycle_q   <= 64'b0;
            pmpaddr0_q <= 64'b0;
            pmpcfg0_q  <= 64'b0;
        end else begin
            mcycle_q <= mcycle_q + 64'd1;

            if (wen) begin
                case (waddr)
                    CSR_MSTATUS:  mstatus_q  <= write_next & MSTATUS_MASK;
                    CSR_SSTATUS:  mstatus_q  <= (mstatus_q & ~SSTATUS_WRITABLE_MASK) |
                                                (write_next & SSTATUS_WRITABLE_MASK);
                    CSR_MEPC:     mepc_q     <= write_next;
                    CSR_SEPC:     sepc_q     <= write_next;
                    CSR_MTVAL:    mtval_q    <= write_next;
                    CSR_STVAL:    stval_q    <= write_next;
                    CSR_MTVEC:    mtvec_q    <= write_next & MTVEC_MASK;
                    CSR_STVEC:    stvec_q    <= write_next;
                    CSR_MCAUSE:   mcause_q   <= write_next;
                    CSR_SCAUSE:   scause_q   <= write_next;
                    CSR_SATP:     satp_q     <= write_next;
                    CSR_MIP:      mip_q      <= write_next & MIP_MASK;
                    CSR_SIP:      mip_q      <= (mip_q & ~SIP_MASK) | (write_next & SIP_MASK);
                    CSR_MIE:      mie_q      <= write_next;
                    CSR_SIE:      mie_q      <= (mie_q & ~SIE_MASK) | (write_next & SIE_MASK);
                    CSR_MSCRATCH: mscratch_q <= write_next;
                    CSR_SSCRATCH: sscratch_q <= write_next;
                    CSR_MIDELEG:  mideleg_q  <= write_next & MIDELEG_MASK;
                    CSR_MEDELEG:  medeleg_q  <= write_next & MEDELEG_MASK;
                    CSR_MCYCLE:   mcycle_q   <= write_next;
                    CSR_PMPADDR0: pmpaddr0_q <= write_next;
                    CSR_PMPCFG0:  pmpcfg0_q  <= write_next;
                    default: ;
                endcase
            end

            if (trap_wen) begin
                if (trap_to_s) begin
                    mstatus_q <= mstatus_on_s_trap(
                        mstatus_after_write(mstatus_q, wen, waddr, write_next),
                        trap_prev_priv
                    );
                    sepc_q    <= trap_mepc;
                    scause_q  <= trap_mcause;
                    stval_q   <= trap_mtval;
                end else begin
                    mstatus_q <= mstatus_on_trap(
                        mstatus_after_write(mstatus_q, wen, waddr, write_next),
                        trap_prev_priv
                    );
                    mepc_q    <= trap_mepc;
                    mcause_q  <= trap_mcause;
                    mtval_q   <= trap_mtval;
                end
            end else if (mret_wen) begin
                mstatus_q <= mstatus_on_mret(mstatus_q);
            end else if (sret_wen) begin
                mstatus_q <= mstatus_on_sret(mstatus_q);
            end
        end
    end

    // ----- architectural outputs -----
    assign mret_priv = priv_mode_t'(mstatus_q[12:11]);
    assign sret_priv = mstatus_q[8] ? PRIV_S : PRIV_U;
    assign mstatus  = mstatus_view;
    assign mstatus_pre_trap = mstatus_q;
    assign sstatus  = mstatus_view & SSTATUS_MASK;
    assign mepc     = mepc_view;
    assign sepc     = sepc_view;
    assign mtval    = mtval_view;
    assign stval    = stval_view;
    assign mtvec    = mtvec_view;
    assign stvec    = stvec_view;
    assign mcause   = mcause_view;
    assign scause   = scause_view;
    assign satp     = satp_view;
    assign mip      = mip_view;
    assign mie      = mie_view;
    assign mscratch = mscratch_view;
    assign sscratch = sscratch_view;
    assign mideleg  = mideleg_view;
    assign medeleg  = medeleg_view;
    assign pmpaddr0 = pmpaddr0_q;
    assign pmpcfg0  = pmpcfg0_q;
    assign mcycle   = mcycle_q;
    assign mhartid  = 64'b0;
endmodule

`endif
