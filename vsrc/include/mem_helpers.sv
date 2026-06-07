`ifndef MEM_HELPERS_SV
`define MEM_HELPERS_SV

`ifdef VERILATOR
`include "include/common.sv"
`endif

package mem_helpers_pkg;
  import common::*;

  function automatic msize_t mem_size_from_funct3(input logic [2:0] funct3);
    begin
      case (funct3)
        3'b000, 3'b100: mem_size_from_funct3 = MSIZE1;
        3'b001, 3'b101: mem_size_from_funct3 = MSIZE2;
        3'b010, 3'b110: mem_size_from_funct3 = MSIZE4;
        default:        mem_size_from_funct3 = MSIZE8;
      endcase
    end
  endfunction

  function automatic strobe_t store_strobe_from_funct3(
    input logic [2:0] funct3,
    input logic [2:0] addr_low
  );
    begin
      case (funct3)
        3'b000:  store_strobe_from_funct3 = 8'b0000_0001 << addr_low;
        3'b001:  store_strobe_from_funct3 = 8'b0000_0011 << addr_low;
        3'b010:  store_strobe_from_funct3 = 8'b0000_1111 << addr_low;
        default: store_strobe_from_funct3 = 8'b1111_1111;
      endcase
    end
  endfunction

  function automatic logic [63:0] align_store_data(
    input logic [63:0] store_data,
    input logic [2:0]  addr_low
  );
    begin
      align_store_data = store_data << {addr_low, 3'b0};
    end
  endfunction

  function automatic logic [63:0] extend_load_data(
    input logic [63:0] raw_data,
    input logic [2:0]  addr_low,
    input logic [2:0]  funct3
  );
    logic [63:0] shifted_data;
    begin
      shifted_data = raw_data >> {addr_low, 3'b0};
      case (funct3)
        3'b000:  extend_load_data = {{56{shifted_data[7]}}, shifted_data[7:0]};
        3'b001:  extend_load_data = {{48{shifted_data[15]}}, shifted_data[15:0]};
        3'b010:  extend_load_data = {{32{shifted_data[31]}}, shifted_data[31:0]};
        3'b011:  extend_load_data = shifted_data;
        3'b100:  extend_load_data = {56'b0, shifted_data[7:0]};
        3'b101:  extend_load_data = {48'b0, shifted_data[15:0]};
        3'b110:  extend_load_data = {32'b0, shifted_data[31:0]};
        default: extend_load_data = shifted_data;
      endcase
    end
  endfunction

  function automatic logic mem_addr_misaligned(
    input logic [63:0] addr,
    input msize_t      size
  );
    begin
      case (size)
        MSIZE2:  mem_addr_misaligned = addr[0];
        MSIZE4:  mem_addr_misaligned = |addr[1:0];
        MSIZE8:  mem_addr_misaligned = |addr[2:0];
        default: mem_addr_misaligned = 1'b0;
      endcase
    end
  endfunction
endpackage

`endif
