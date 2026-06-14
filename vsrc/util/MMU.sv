`ifndef __MMU_SV
`define __MMU_SV

`ifdef VERILATOR
`include "include/common.sv"
`endif

module MMU
    import common::*;
(
    input  logic       clk,
    input  logic       reset,

    input  cbus_req_t  ireq,
    output cbus_resp_t iresp,
    output cbus_req_t  oreq,
    input  cbus_resp_t oresp,

    input  priv_mode_t priv_mode,
    input  u64         satp
);
    typedef enum logic [2:0] {
        STATE_IDLE,
        STATE_WALK,
        STATE_ISSUE,
        STATE_FAULT,
        STATE_WAIT_CLEAR
    } state_t;

    state_t state_q;
    state_t resume_state_q;
    cbus_req_t saved_req_q;
    u64 vaddr_q;
    u64 pte_addr_q;
    logic [1:0] level_q;
    u64 translated_addr_q;
    u64 satp_ctx_q;
    priv_mode_t priv_mode_ctx_q;
    logic context_change;

    logic translate_en;
    logic pte_done;
    logic leaf_pte;
    logic resp_done;
    u64 pte_data;
    u64 next_pte_addr;
    u64 leaf_paddr;
    cbus_req_t walk_req, final_req;
    cbus_resp_t fault_resp;

    function automatic u64 vpn_index(input u64 vaddr, input logic [1:0] level);
        begin
            case (level)
                2'd2: vpn_index = {55'b0, vaddr[38:30]};
                2'd1: vpn_index = {55'b0, vaddr[29:21]};
                default: vpn_index = {55'b0, vaddr[20:12]};
            endcase
        end
    endfunction

    function automatic u64 leaf_addr(
        input u64 pte,
        input u64 vaddr,
        input logic [1:0] level
    );
        begin
            case (level)
                2'd2: leaf_addr = {8'b0, pte[53:28], vaddr[29:0]};
                2'd1: leaf_addr = {8'b0, pte[53:19], vaddr[20:0]};
                default: leaf_addr = {8'b0, pte[53:10], vaddr[11:0]};
            endcase
        end
    endfunction

    function automatic logic sv39_canonical(input u64 vaddr);
        begin
            sv39_canonical = (vaddr[63:39] == {25{vaddr[38]}});
        end
    endfunction

    function automatic logic pte_invalid(input u64 pte);
        begin
            pte_invalid = !pte[0] || (pte[2] && !pte[1]);
        end
    endfunction

    function automatic logic pte_leaf(input u64 pte);
        begin
            pte_leaf = |pte[3:1];
        end
    endfunction

    function automatic logic superpage_misaligned(input u64 pte, input logic [1:0] level);
        begin
            case (level)
                2'd2: superpage_misaligned = |pte[27:10];
                2'd1: superpage_misaligned = |pte[18:10];
                default: superpage_misaligned = 1'b0;
            endcase
        end
    endfunction

    function automatic logic pte_permission_fault(
        input u64 pte,
        input mem_access_t access,
        input priv_mode_t priv
    );
        logic need_r, need_w, need_x;
        begin
            need_r = (access == MEM_ACCESS_LOAD);
            need_w = (access == MEM_ACCESS_STORE);
            need_x = (access == MEM_ACCESS_FETCH);
            pte_permission_fault = !pte[6] ||
                (need_r && !pte[1]) ||
                (need_w && (!pte[2] || !pte[7])) ||
                (need_x && !pte[3]) ||
                ((priv == PRIV_U) && !pte[4]);
        end
    endfunction

    assign translate_en = (priv_mode != PRIV_M) && (satp[63:60] == 4'd8);
    assign resp_done = oresp.ready && oresp.last;
    assign pte_done = resp_done;
    assign pte_data = oresp.data;
    assign leaf_pte = pte_leaf(pte_data);
    assign next_pte_addr = ({8'b0, pte_data[53:10], 12'b0}) +
        (vpn_index(vaddr_q, level_q - 2'd1) << 3);
    assign leaf_paddr = leaf_addr(pte_data, vaddr_q, level_q);
    assign context_change = (satp != satp_ctx_q) || (priv_mode != priv_mode_ctx_q);

    always_comb begin
        walk_req          = '0;
        walk_req.valid    = 1'b1;
        walk_req.is_write = 1'b0;
        walk_req.size     = MSIZE8;
        walk_req.addr     = pte_addr_q;
        walk_req.strobe   = 8'b0;
        walk_req.data     = 64'b0;
        walk_req.len      = MLEN1;
        walk_req.burst    = AXI_BURST_FIXED;
        walk_req.access   = MEM_ACCESS_LOAD;

        final_req      = saved_req_q;
        final_req.addr = translated_addr_q;

        fault_resp            = '0;
        fault_resp.ready      = 1'b1;
        fault_resp.last       = 1'b1;
        fault_resp.page_fault = 1'b1;
    end

    always_comb begin
        oreq  = '0;
        iresp = '0;

        case (state_q)
            STATE_IDLE: begin
                if (ireq.valid && !translate_en) begin
                    oreq  = ireq;
                    iresp = oresp;
                end
            end
            STATE_WALK: begin
                oreq = walk_req;
            end
            STATE_ISSUE: begin
                oreq  = final_req;
                iresp = oresp;
            end
            STATE_FAULT: begin
                iresp = fault_resp;
            end
            STATE_WAIT_CLEAR: begin
                oreq  = '0;
                iresp = '0;
            end
            default: ;
        endcase
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            state_q           <= STATE_IDLE;
            resume_state_q    <= STATE_IDLE;
            saved_req_q       <= '0;
            vaddr_q           <= 64'b0;
            pte_addr_q        <= 64'b0;
            level_q           <= 2'd0;
            translated_addr_q <= 64'b0;
            satp_ctx_q        <= 64'b0;
            priv_mode_ctx_q   <= PRIV_M;
        end else begin
            satp_ctx_q      <= satp;
            priv_mode_ctx_q <= priv_mode;

            if (context_change && state_q != STATE_IDLE) begin
                state_q        <= STATE_IDLE;
                resume_state_q <= STATE_IDLE;
            end else begin
                case (state_q)
                    STATE_IDLE: begin
                        if (ireq.valid && translate_en) begin
                            saved_req_q <= ireq;
                            vaddr_q     <= ireq.addr;
                            level_q     <= 2'd2;
                            pte_addr_q  <= ({8'b0, satp[43:0], 12'b0}) +
                                (vpn_index(ireq.addr, 2'd2) << 3);
                            state_q     <= sv39_canonical(ireq.addr) ? STATE_WALK : STATE_FAULT;
                            resume_state_q <= STATE_IDLE;
                        end
                    end
                    STATE_WALK: begin
                        if (pte_done) begin
                            if (pte_invalid(pte_data)) begin
                                state_q <= STATE_FAULT;
                            end else if (leaf_pte) begin
                                if (superpage_misaligned(pte_data, level_q) ||
                                    pte_permission_fault(pte_data, saved_req_q.access, priv_mode_ctx_q)) begin
                                    state_q <= STATE_FAULT;
                                end else begin
                                    translated_addr_q <= leaf_paddr;
                                    resume_state_q    <= STATE_ISSUE;
                                    state_q           <= STATE_WAIT_CLEAR;
                                end
                            end else if (level_q == 2'd0) begin
                                state_q <= STATE_FAULT;
                            end else begin
                                level_q    <= level_q - 2'd1;
                                pte_addr_q <= next_pte_addr;
                                resume_state_q <= STATE_WALK;
                                state_q    <= STATE_WAIT_CLEAR;
                            end
                        end
                    end
                    STATE_ISSUE: begin
                        if (resp_done) begin
                            resume_state_q <= STATE_IDLE;
                            state_q        <= STATE_WAIT_CLEAR;
                        end
                    end
                    STATE_FAULT: begin
                        resume_state_q <= STATE_IDLE;
                        state_q        <= STATE_WAIT_CLEAR;
                    end
                    STATE_WAIT_CLEAR: begin
                        state_q <= resume_state_q;
                    end
                    default: state_q <= STATE_IDLE;
                endcase
            end
        end
    end
endmodule

`endif
