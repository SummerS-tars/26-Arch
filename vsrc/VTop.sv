`ifndef __VTOP_SV
`define __VTOP_SV

`ifdef VERILATOR
`include "include/common.sv"
`include "include/trap.sv"
`include "include/mem_helpers.sv"
`include "src/core_csr.sv"
`include "src/core_trap_ctrl.sv"
`include "src/core.sv"
`include "util/IBusToCBus.sv"
`include "util/DBusToCBus.sv"
`include "util/CBusArbiter.sv"
`include "util/MMU.sv"

`endif
module VTop 
	import common::*;(
	input logic clk, reset,

	output cbus_req_t  oreq,
	input  cbus_resp_t oresp,
	input logic trint, swint, exint
);

    ibus_req_t  ireq;
    ibus_resp_t iresp;
    dbus_req_t  dreq;
    dbus_resp_t dresp;
    cbus_req_t  icreq,  dcreq;
    cbus_resp_t icresp, dcresp;
    cbus_req_t  mmu_ireq;
    cbus_resp_t mmu_iresp;
    priv_mode_t priv_mode_o;
    u64         satp_o;

    core core(.*);
    IBusToCBus icvt(
        .clk(clk), .reset(reset),
        .ireq(ireq), .iresp(iresp), .icreq(icreq), .icresp(icresp)
    );

    DBusToCBus dcvt(.*);


    CBusArbiter mux(
        .ireqs({icreq, dcreq}),
        .iresps({icresp, dcresp}),
        .oreq(mmu_ireq),
        .oresp(mmu_iresp),
        .*
    );

    MMU mmu(
        .clk(clk),
        .reset(reset),
        .ireq(mmu_ireq),
        .iresp(mmu_iresp),
        .oreq(oreq),
        .oresp(oresp),
        .priv_mode(priv_mode_o),
        .satp(satp_o)
    );

	always_ff @(posedge clk) begin
		if (~reset) begin
			// $display("icreq %x, %x", icreq.valid, icreq.addr);
			// if (oreq.valid || dcreq.addr == 64'h40600004) $display("dcreq %x, %x, oreq %x, %x, dcresp %x", dcreq.addr, dcreq.valid, oreq.valid, oreq.addr, dcresp.ready);
		end
	end
	

endmodule



`endif