`ifndef __CORE_DECODE_SV
`define __CORE_DECODE_SV

module core_decode import common::*;(
    input  logic [31:0] instr,
    output decode_out_t decode_out
);
    logic [6:0] opcode;

    always_comb begin
        opcode = instr[6:0];

        decode_out        = '0;
        decode_out.rd     = instr[11:7];
        decode_out.rs1    = instr[19:15];
        decode_out.rs2    = instr[24:20];
        decode_out.funct3 = instr[14:12];
        decode_out.funct7 = instr[31:25];
        decode_out.alu_op = ALU_ADD;
        decode_out.wb_sel = WB_ALU;
        decode_out.csr_op = CSR_OP_WRITE;
        decode_out.amo_op = AMO_NONE;

        case (opcode)
            7'b0010011, 7'b0000011, 7'b1100111, 7'b0011011: begin
                decode_out.imm = {{52{instr[31]}}, instr[31:20]};
            end
            7'b0100011: begin
                decode_out.imm = {{52{instr[31]}}, instr[31:25], instr[11:7]};
            end
            7'b1100011: begin
                decode_out.imm = {{52{instr[31]}}, instr[7], instr[30:25], instr[11:8], 1'b0};
            end
            7'b0110111, 7'b0010111: begin
                decode_out.imm = {{32{instr[31]}}, instr[31:12], 12'b0};
            end
            7'b1101111: begin
                decode_out.imm = {{44{instr[31]}}, instr[19:12], instr[20], instr[30:21], 1'b0};
            end
            default: begin
                decode_out.imm = 64'b0;
            end
        endcase

        case (opcode)
            7'b0010011: begin
                decode_out.reg_write = 1'b1;
                decode_out.alu_src   = 1'b1;
                case (decode_out.funct3)
                    3'b000: decode_out.alu_op = ALU_ADD;
                    3'b001: decode_out.alu_op = ALU_SLL;
                    3'b010: decode_out.alu_op = ALU_SLT;
                    3'b011: decode_out.alu_op = ALU_SLTU;
                    3'b100: decode_out.alu_op = ALU_XOR;
                    3'b101: decode_out.alu_op = decode_out.funct7[5] ? ALU_SRA : ALU_SRL;
                    3'b110: decode_out.alu_op = ALU_OR;
                    3'b111: decode_out.alu_op = ALU_AND;
                    default: ;
                endcase
            end
            7'b0011011: begin
                decode_out.reg_write = 1'b1;
                decode_out.alu_src   = 1'b1;
                case (decode_out.funct3)
                    3'b000: decode_out.alu_op = ALU_ADDW;
                    3'b001: decode_out.alu_op = ALU_SLLW;
                    3'b101: decode_out.alu_op = decode_out.funct7[5] ? ALU_SRAW : ALU_SRLW;
                    default: ;
                endcase
            end
            7'b0000011: begin
                decode_out.reg_write = 1'b1;
                decode_out.alu_src   = 1'b1;
                decode_out.mem_read  = 1'b1;
                decode_out.wb_sel    = WB_MEM;
                decode_out.alu_op    = ALU_ADD;
            end
            7'b0100011: begin
                decode_out.alu_src   = 1'b1;
                decode_out.mem_write = 1'b1;
                decode_out.alu_op    = ALU_ADD;
            end
            7'b0101111: begin
                decode_out.is_illegal = 1'b1;
                if (decode_out.funct3 == 3'b010) begin
                    decode_out.reg_write = 1'b1;
                    decode_out.alu_src   = 1'b1;
                    decode_out.mem_read  = 1'b1;
                    decode_out.wb_sel    = WB_MEM;
                    decode_out.alu_op    = ALU_ADD;
                    decode_out.is_amo    = 1'b1;
                    decode_out.is_illegal = 1'b0;
                    case (instr[31:27])
                        5'b00000: begin
                            decode_out.mem_write = 1'b1;
                            decode_out.amo_op    = AMO_ADD;
                        end
                        5'b00001: begin
                            decode_out.mem_write = 1'b1;
                            decode_out.amo_op    = AMO_SWAP;
                        end
                        5'b00010: begin
                            decode_out.is_lr = 1'b1;
                            decode_out.amo_op = AMO_LR;
                            decode_out.is_illegal = (decode_out.rs2 != 5'b0);
                        end
                        5'b00011: begin
                            decode_out.mem_write = 1'b1;
                            decode_out.is_sc     = 1'b1;
                            decode_out.amo_op    = AMO_SC;
                        end
                        5'b00100: begin
                            decode_out.mem_write = 1'b1;
                            decode_out.amo_op    = AMO_XOR;
                        end
                        5'b01000: begin
                            decode_out.mem_write = 1'b1;
                            decode_out.amo_op    = AMO_OR;
                        end
                        5'b01100: begin
                            decode_out.mem_write = 1'b1;
                            decode_out.amo_op    = AMO_AND;
                        end
                        5'b10000: begin
                            decode_out.mem_write = 1'b1;
                            decode_out.amo_op    = AMO_MIN;
                        end
                        5'b10100: begin
                            decode_out.mem_write = 1'b1;
                            decode_out.amo_op    = AMO_MAX;
                        end
                        5'b11000: begin
                            decode_out.mem_write = 1'b1;
                            decode_out.amo_op    = AMO_MINU;
                        end
                        5'b11100: begin
                            decode_out.mem_write = 1'b1;
                            decode_out.amo_op    = AMO_MAXU;
                        end
                        default: begin
                            decode_out.reg_write = 1'b0;
                            decode_out.mem_read  = 1'b0;
                            decode_out.mem_write = 1'b0;
                            decode_out.is_amo    = 1'b0;
                            decode_out.amo_op    = AMO_NONE;
                            decode_out.wb_sel    = WB_ALU;
                            decode_out.is_illegal = 1'b1;
                        end
                    endcase
                end
            end
            7'b0110011: begin
                decode_out.reg_write = 1'b1;
                if (decode_out.funct7 == 7'b0000001) begin
                    case (decode_out.funct3)
                        3'b000: decode_out.alu_op = ALU_MUL;
                        3'b001: decode_out.alu_op = ALU_MULH;
                        3'b010: decode_out.alu_op = ALU_MULHSU;
                        3'b011: decode_out.alu_op = ALU_MULHU;
                        3'b100: decode_out.alu_op = ALU_DIV;
                        3'b101: decode_out.alu_op = ALU_DIVU;
                        3'b110: decode_out.alu_op = ALU_REM;
                        3'b111: decode_out.alu_op = ALU_REMU;
                        default: ;
                    endcase
                end else begin
                    case (decode_out.funct3)
                        3'b000: decode_out.alu_op = decode_out.funct7[5] ? ALU_SUB : ALU_ADD;
                        3'b001: decode_out.alu_op = ALU_SLL;
                        3'b010: decode_out.alu_op = ALU_SLT;
                        3'b011: decode_out.alu_op = ALU_SLTU;
                        3'b100: decode_out.alu_op = ALU_XOR;
                        3'b101: decode_out.alu_op = decode_out.funct7[5] ? ALU_SRA : ALU_SRL;
                        3'b110: decode_out.alu_op = ALU_OR;
                        3'b111: decode_out.alu_op = ALU_AND;
                        default: ;
                    endcase
                end
            end
            7'b0111011: begin
                decode_out.reg_write = 1'b1;
                if (decode_out.funct7 == 7'b0000001) begin
                    case (decode_out.funct3)
                        3'b000: decode_out.alu_op = ALU_MULW;
                        3'b100: decode_out.alu_op = ALU_DIVW;
                        3'b101: decode_out.alu_op = ALU_DIVUW;
                        3'b110: decode_out.alu_op = ALU_REMW;
                        3'b111: decode_out.alu_op = ALU_REMUW;
                        default: ;
                    endcase
                end else begin
                    case (decode_out.funct3)
                        3'b000: decode_out.alu_op = decode_out.funct7[5] ? ALU_SUBW : ALU_ADDW;
                        3'b001: decode_out.alu_op = ALU_SLLW;
                        3'b101: decode_out.alu_op = decode_out.funct7[5] ? ALU_SRAW : ALU_SRLW;
                        default: ;
                    endcase
                end
            end
            7'b0110111: begin
                decode_out.reg_write = 1'b1;
                decode_out.rs1       = 5'b0;
                decode_out.alu_src   = 1'b1;
                decode_out.alu_op    = ALU_ADD;
            end
            7'b0010111: begin
                decode_out.reg_write = 1'b1;
                decode_out.use_pc    = 1'b1;
                decode_out.alu_src   = 1'b1;
                decode_out.alu_op    = ALU_ADD;
            end
            7'b1100011: begin
                decode_out.is_branch = 1'b1;
            end
            7'b1101111: begin
                decode_out.reg_write = 1'b1;
                decode_out.is_jump   = 1'b1;
                decode_out.wb_sel    = WB_PC4;
            end
            7'b1100111: begin
                decode_out.reg_write = 1'b1;
                decode_out.is_jump   = 1'b1;
                decode_out.is_jalr   = 1'b1;
                decode_out.wb_sel    = WB_PC4;
            end
            7'b1110011: begin
                if (instr == 32'h00000073) begin
                    decode_out.is_ecall = 1'b1;
                end else if (instr == 32'h30200073) begin
                    decode_out.is_mret = 1'b1;
                end else if (instr == 32'h10200073) begin
                    decode_out.is_sret = 1'b1;
                end else if (instr == 32'h12000073) begin
                    // sfence.vma is a no-op for this simple in-order MMU model.
                end else begin
                    decode_out.is_csr       = (decode_out.funct3 != 3'b000);
                    decode_out.reg_write    = (decode_out.funct3 != 3'b000);
                    decode_out.wb_sel       = WB_CSR;
                    decode_out.csr_addr     = instr[31:20];
                    decode_out.csr_uses_imm = decode_out.funct3[2];
                    decode_out.csr_zimm     = {59'b0, instr[19:15]};
                    case (decode_out.funct3[1:0])
                        2'b01: decode_out.csr_op = CSR_OP_WRITE;
                        2'b10: decode_out.csr_op = CSR_OP_SET;
                        2'b11: decode_out.csr_op = CSR_OP_CLEAR;
                    default: begin
                        decode_out.is_csr    = 1'b0;
                        decode_out.reg_write = 1'b0;
                        decode_out.wb_sel    = WB_ALU;
                    end
                    endcase
                end
            end
            default: ;
        endcase

        if ((opcode == 7'b1110011) && (decode_out.funct3 == 3'b000) &&
            !decode_out.is_ecall && !decode_out.is_mret && !decode_out.is_sret &&
            (instr != 32'h12000073)) begin
            decode_out.is_illegal = 1'b1;
        end
        if (instr == 32'b0) begin
            decode_out.is_illegal = 1'b1;
        end
    end
endmodule

`endif
