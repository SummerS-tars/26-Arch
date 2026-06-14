`ifndef __CORE_ALU_SV
`define __CORE_ALU_SV

module core_alu import common::*;(
    input  alu_op_t     alu_op,
    input  logic [63:0] op_a,
    input  logic [63:0] op_b,
    output logic [63:0] result
);
    logic [31:0] result_32;
    logic signed [127:0] product_ss, product_su;
    logic [127:0] product_uu;
    logic [63:0] product_w;

    localparam logic [63:0] INT64_MIN = 64'h8000_0000_0000_0000;
    localparam logic [31:0] INT32_MIN = 32'h8000_0000;

    assign product_ss = $signed({{64{op_a[63]}}, op_a}) * $signed({{64{op_b[63]}}, op_b});
    assign product_su = $signed({{64{op_a[63]}}, op_a}) * $signed({64'b0, op_b});
    assign product_uu = {64'b0, op_a} * {64'b0, op_b};
    assign product_w  = {32'b0, op_a[31:0]} * {32'b0, op_b[31:0]};

    function automatic logic [63:0] sext32(input logic [31:0] value);
        sext32 = {{32{value[31]}}, value};
    endfunction

    function automatic logic [63:0] div_signed64(
        input logic [63:0] lhs,
        input logic [63:0] rhs
    );
        begin
            if (rhs == 64'b0)
                div_signed64 = 64'hffff_ffff_ffff_ffff;
            else if ((lhs == INT64_MIN) && (rhs == 64'hffff_ffff_ffff_ffff))
                div_signed64 = INT64_MIN;
            else
                div_signed64 = $signed(lhs) / $signed(rhs);
        end
    endfunction

    function automatic logic [63:0] div_unsigned64(
        input logic [63:0] lhs,
        input logic [63:0] rhs
    );
        begin
            div_unsigned64 = (rhs == 64'b0) ? 64'hffff_ffff_ffff_ffff : (lhs / rhs);
        end
    endfunction

    function automatic logic [63:0] rem_signed64(
        input logic [63:0] lhs,
        input logic [63:0] rhs
    );
        begin
            if (rhs == 64'b0)
                rem_signed64 = lhs;
            else if ((lhs == INT64_MIN) && (rhs == 64'hffff_ffff_ffff_ffff))
                rem_signed64 = 64'b0;
            else
                rem_signed64 = $signed(lhs) % $signed(rhs);
        end
    endfunction

    function automatic logic [63:0] rem_unsigned64(
        input logic [63:0] lhs,
        input logic [63:0] rhs
    );
        begin
            rem_unsigned64 = (rhs == 64'b0) ? lhs : (lhs % rhs);
        end
    endfunction

    function automatic logic [63:0] div_signed32(
        input logic [31:0] lhs,
        input logic [31:0] rhs
    );
        logic signed [31:0] lhs_s, rhs_s, quotient;
        begin
            lhs_s = lhs;
            rhs_s = rhs;
            if (rhs == 32'b0)
                div_signed32 = 64'hffff_ffff_ffff_ffff;
            else if ((lhs == INT32_MIN) && (rhs == 32'hffff_ffff))
                div_signed32 = sext32(INT32_MIN);
            else begin
                quotient = lhs_s / rhs_s;
                div_signed32 = sext32(quotient);
            end
        end
    endfunction

    function automatic logic [63:0] div_unsigned32(
        input logic [31:0] lhs,
        input logic [31:0] rhs
    );
        logic [31:0] quotient;
        begin
            quotient = (rhs == 32'b0) ? 32'hffff_ffff : (lhs / rhs);
            div_unsigned32 = sext32(quotient);
        end
    endfunction

    function automatic logic [63:0] rem_signed32(
        input logic [31:0] lhs,
        input logic [31:0] rhs
    );
        logic signed [31:0] lhs_s, rhs_s, remainder;
        begin
            lhs_s = lhs;
            rhs_s = rhs;
            if (rhs == 32'b0)
                rem_signed32 = sext32(lhs);
            else if ((lhs == INT32_MIN) && (rhs == 32'hffff_ffff))
                rem_signed32 = 64'b0;
            else begin
                remainder = lhs_s % rhs_s;
                rem_signed32 = sext32(remainder);
            end
        end
    endfunction

    function automatic logic [63:0] rem_unsigned32(
        input logic [31:0] lhs,
        input logic [31:0] rhs
    );
        logic [31:0] remainder;
        begin
            remainder = (rhs == 32'b0) ? lhs : (lhs % rhs);
            rem_unsigned32 = sext32(remainder);
        end
    endfunction

    always_comb begin
        result    = op_a;
        result_32 = 32'b0;

        case (alu_op)
            ALU_ADD:  result = op_a + op_b;
            ALU_SUB:  result = op_a - op_b;
            ALU_AND:  result = op_a & op_b;
            ALU_OR:   result = op_a | op_b;
            ALU_XOR:  result = op_a ^ op_b;
            ALU_SLL:  result = op_a << op_b[5:0];
            ALU_SRL:  result = op_a >> op_b[5:0];
            ALU_SRA:  result = $signed(op_a) >>> op_b[5:0];
            ALU_SLT:  result = {{63{1'b0}}, ($signed(op_a) < $signed(op_b))};
            ALU_SLTU: result = {{63{1'b0}}, (op_a < op_b)};
            ALU_MUL:  result = product_uu[63:0];
            ALU_MULH: result = product_ss[127:64];
            ALU_MULHSU: result = product_su[127:64];
            ALU_MULHU:  result = product_uu[127:64];
            ALU_DIV:    result = div_signed64(op_a, op_b);
            ALU_DIVU:   result = div_unsigned64(op_a, op_b);
            ALU_REM:    result = rem_signed64(op_a, op_b);
            ALU_REMU:   result = rem_unsigned64(op_a, op_b);
            ALU_ADDW: begin
                result_32 = op_a[31:0] + op_b[31:0];
                result    = {{32{result_32[31]}}, result_32};
            end
            ALU_SUBW: begin
                result_32 = op_a[31:0] - op_b[31:0];
                result    = {{32{result_32[31]}}, result_32};
            end
            ALU_SLLW: begin
                result_32 = op_a[31:0] << op_b[4:0];
                result    = {{32{result_32[31]}}, result_32};
            end
            ALU_SRLW: begin
                result_32 = op_a[31:0] >> op_b[4:0];
                result    = {{32{result_32[31]}}, result_32};
            end
            ALU_SRAW: begin
                result_32 = $signed(op_a[31:0]) >>> op_b[4:0];
                result    = {{32{result_32[31]}}, result_32};
            end
            ALU_MULW:  result = sext32(product_w[31:0]);
            ALU_DIVW:  result = div_signed32(op_a[31:0], op_b[31:0]);
            ALU_DIVUW: result = div_unsigned32(op_a[31:0], op_b[31:0]);
            ALU_REMW:  result = rem_signed32(op_a[31:0], op_b[31:0]);
            ALU_REMUW: result = rem_unsigned32(op_a[31:0], op_b[31:0]);
            default: ;
        endcase
    end
endmodule

`endif
