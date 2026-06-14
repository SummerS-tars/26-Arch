`ifdef VERILATOR
`include "include/common.sv"
`include "include/trap.sv"
`include "include/mem_helpers.sv"
`include "src/core_regfile.sv"
`include "src/core_decode.sv"
`include "src/core_alu.sv"
`include "src/core_hazard_unit.sv"
`include "src/core_forwarding_unit.sv"
`include "src/core_csr.sv"
`include "src/core_trap_ctrl.sv"
`include "src/core_difftest_adapter.sv"
`include "src/core.sv"
`include "util/IBusToCBus.sv"
`include "util/DBusToCBus.sv"
`include "util/CBusArbiter.sv"
`include "util/MMU.sv"
`include "util/ICache.sv"

module SimTop import common::*;(
  input         clock,
  input         reset,
  input  [63:0] io_logCtrl_log_begin,
  input  [63:0] io_logCtrl_log_end,
  input  [63:0] io_logCtrl_log_level,
  input         io_perfInfo_clean,
  input         io_perfInfo_dump,
  output        io_uart_out_valid,
  output [7:0]  io_uart_out_ch,
  output        io_uart_in_valid,
  input  [7:0]  io_uart_in_ch
);

    cbus_req_t  oreq, icache_ireq;
    cbus_resp_t oresp, icache_iresp;
    logic trint, swint, exint;

    ibus_req_t  ireq;
    ibus_resp_t iresp;
    dbus_req_t  dreq;
    dbus_resp_t dresp;
    cbus_req_t  icreq,  dcreq;
    cbus_resp_t icresp, dcresp;
    cbus_req_t  mmu_ireq;
    cbus_resp_t mmu_iresp;
    priv_mode_t core_priv_mode;
    u64         core_satp;
    priv_mode_t core_priv_mode_q;
    u64         core_satp_q;
    logic       icache_flush;

    core core(
      .clk(clock), .reset, .ireq, .iresp, .dreq, .dresp, .trint, .swint, .exint,
      .priv_mode_o(core_priv_mode), .satp_o(core_satp)
    );

    IBusToCBus icvt(.*);
    DBusToCBus dcvt(.*);
    CBusArbiter mux(
        .clk(clock), .reset,
        .ireqs({icreq, dcreq}),
        .iresps({icresp, dcresp}),
        .oreq(mmu_ireq),
        .oresp(mmu_iresp)
    );

    MMU mmu(
        .clk(clock),
        .reset(reset),
        .ireq(mmu_ireq),
        .iresp(mmu_iresp),
        .oreq(icache_ireq),
        .oresp(icache_iresp),
        .priv_mode(core_priv_mode),
        .satp(core_satp)
    );

    always_ff @(posedge clock) begin
        if (reset) begin
            core_priv_mode_q <= PRIV_M;
            core_satp_q <= 64'b0;
        end else begin
            core_priv_mode_q <= core_priv_mode;
            core_satp_q <= core_satp;
        end
    end

    assign icache_flush = !reset &&
        ((core_priv_mode_q != core_priv_mode) || (core_satp_q != core_satp));

    ICache icache(
        .clk(clock),
        .reset(reset),
        .flush(icache_flush),
        .ireq(icache_ireq),
        .iresp(icache_iresp),
        .oreq(oreq),
        .oresp(oresp)
    );

    RAMHelper2 ram(
        .clk(clock), .reset, .oreq, .oresp, .trint, .swint, .exint
    );

    assign {io_uart_out_valid, io_uart_out_ch, io_uart_in_valid} = '0;

endmodule
`endif