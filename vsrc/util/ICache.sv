`ifndef __ICACHE_SV
`define __ICACHE_SV

`ifdef VERILATOR
`include "include/common.sv"
`endif

module ICache
    import common::*;
#(
    parameter int LINES = 128,
    localparam int INDEX_BITS = $clog2(LINES),
    localparam int TAG_BITS = 64 - 3 - INDEX_BITS
) (
    input  logic      clk,
    input  logic      reset,
    input  logic      flush,

    input  cbus_req_t  ireq,
    output cbus_resp_t iresp,
    output cbus_req_t  oreq,
    input  cbus_resp_t oresp
);
    typedef enum logic {
        STATE_IDLE,
        STATE_MISS
    } state_t;

    state_t state_q;
    cbus_req_t miss_req_q;
    logic flush_pending_q;

    logic [LINES-1:0]       valid_q;
    logic [TAG_BITS-1:0]    tag_q  [LINES];
    word_t                  data_q [LINES];

    logic [INDEX_BITS-1:0] req_index, miss_index;
    logic [TAG_BITS-1:0] req_tag, miss_tag;
    logic req_cacheable, req_hit, miss_done;

    assign req_index = ireq.addr[3 +: INDEX_BITS];
    assign req_tag = ireq.addr[63 -: TAG_BITS];
    assign miss_index = miss_req_q.addr[3 +: INDEX_BITS];
    assign miss_tag = miss_req_q.addr[63 -: TAG_BITS];
    assign req_cacheable = ireq.valid && !ireq.is_write &&
        (ireq.access == MEM_ACCESS_FETCH) && ireq.addr[31];
    assign req_hit = req_cacheable && valid_q[req_index] &&
        (tag_q[req_index] == req_tag);
    assign miss_done = oresp.ready && oresp.last;

    always_comb begin
        oreq = '0;
        iresp = '0;

        case (state_q)
            STATE_IDLE: begin
                if (req_hit) begin
                    iresp.ready = 1'b1;
                    iresp.last = 1'b1;
                    iresp.data = data_q[req_index];
                    iresp.page_fault = 1'b0;
                end else begin
                    oreq = ireq;
                    iresp = oresp;
                end
            end
            STATE_MISS: begin
                oreq = miss_req_q;
                iresp = oresp;
            end
        endcase
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            state_q <= STATE_IDLE;
            miss_req_q <= '0;
            flush_pending_q <= 1'b0;
            valid_q <= '0;
        end else begin
            if (flush) begin
                if (state_q == STATE_IDLE)
                    valid_q <= '0;
                else
                    flush_pending_q <= 1'b1;
            end

            case (state_q)
                STATE_IDLE: begin
                    if (req_cacheable && !req_hit) begin
                        if (miss_done) begin
                            if (!flush) begin
                                valid_q[req_index] <= 1'b1;
                                tag_q[req_index] <= req_tag;
                                data_q[req_index] <= oresp.data;
                            end
                        end else begin
                            miss_req_q <= ireq;
                            state_q <= STATE_MISS;
                        end
                    end
                end
                STATE_MISS: begin
                    if (miss_done) begin
                        state_q <= STATE_IDLE;
                        if (flush_pending_q || flush) begin
                            valid_q <= '0;
                            flush_pending_q <= 1'b0;
                        end else begin
                            valid_q[miss_index] <= 1'b1;
                            tag_q[miss_index] <= miss_tag;
                            data_q[miss_index] <= oresp.data;
                        end
                    end
                end
            endcase
        end
    end
endmodule

`endif
