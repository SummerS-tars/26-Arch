`ifndef __IBUSTOCBUS_SV
`define __IBUSTOCBUS_SV

`ifdef VERILATOR
`include "include/common.sv"
`else

`endif

module IBusToCBus 
    import common::*;(
    input  logic       clk,
    input  logic       reset,
    input  ibus_req_t  ireq,
    output ibus_resp_t iresp,
    output cbus_req_t  icreq,
    input  cbus_resp_t icresp
);
    // since IBus is a subset of DBus, we can reuse DBusToCBus.
    dbus_resp_t dresp;
    logic       addr_bit2_q;

    DBusToCBus inst(
        .dreq(`IREQ_TO_DREQ(ireq)),
        .dresp(dresp),
        .dcreq(icreq),
        .dcresp(icresp)
    );

    // Latch the fetch address half-select when the request is issued so a later
    // PC change cannot corrupt the instruction response mux.
    always_ff @(posedge clk) begin
        if (reset)
            addr_bit2_q <= 1'b0;
        else if (ireq.valid)
            addr_bit2_q <= ireq.addr[2];
    end

    assign iresp.addr_ok = dresp.addr_ok;
    assign iresp.data_ok = dresp.data_ok;
    assign iresp.data    = addr_bit2_q ? dresp.data[63:32] : dresp.data[31:0];
endmodule



`endif
