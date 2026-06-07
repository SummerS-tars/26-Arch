`ifndef TRAP_SV
`define TRAP_SV

`ifdef VERILATOR
`include "include/common.sv"
`endif

package trap_pkg;
  import common::*;

  parameter logic [31:0] TRAP_INST = 32'h0005006b;
  parameter logic [63:0] CAUSE_INST_MISALIGNED  = 64'd0;
  parameter logic [63:0] CAUSE_ILLEGAL_INST     = 64'd2;
  parameter logic [63:0] CAUSE_LOAD_MISALIGNED  = 64'd4;
  parameter logic [63:0] CAUSE_STORE_MISALIGNED = 64'd6;
  parameter logic [63:0] CAUSE_ECALL_U          = 64'd8;
  parameter logic [63:0] CAUSE_ECALL_S          = 64'd9;
  parameter logic [63:0] CAUSE_ECALL_M          = 64'd11;
  parameter logic [63:0] CAUSE_IRQ_SW           = 64'h8000_0000_0000_0003;
  parameter logic [63:0] CAUSE_IRQ_TIMER        = 64'h8000_0000_0000_0007;
  parameter logic [63:0] CAUSE_IRQ_EXTERNAL     = 64'h8000_0000_0000_000b;
  parameter logic [63:0] MIP_MSIP               = 64'h0000_0000_0000_0008;
  parameter logic [63:0] MIP_MTIP               = 64'h0000_0000_0000_0080;
  parameter logic [63:0] MIP_MEIP               = 64'h0000_0000_0000_0800;

  function automatic logic [63:0] ecall_cause(input priv_mode_t mode);
    begin
      case (mode)
        PRIV_U:  ecall_cause = CAUSE_ECALL_U;
        PRIV_S:  ecall_cause = CAUSE_ECALL_S;
        default: ecall_cause = CAUSE_ECALL_M;
      endcase
    end
  endfunction

  function automatic logic mstatus_mie_after_wb(
    input logic [63:0] status,
    input logic        write_en,
    input csr_op_t     op,
    input csr_addr_t   addr,
    input logic [63:0] data
  );
    logic [63:0] next_status;
    begin
      next_status = status;
      if (write_en && (addr == 12'h300)) begin
        case (op)
          CSR_OP_SET:   next_status = status | data;
          CSR_OP_CLEAR: next_status = status & ~data;
          default:      next_status = data;
        endcase
      end
      mstatus_mie_after_wb = next_status[3];
    end
  endfunction
endpackage

`endif
