import alu_ops_pkg::*;

module alu(
    input  logic [31:0] op1,
    input  logic [31:0] op2,
    input  alu_ops_pkg::alu_op_t op_type,
    output logic [31:0] result
);

    always_comb begin
        unique case (op_type)
            ADD:  result = op1 + op2;
            SUB:  result = op1 - op2;
            AND:  result = op1 & op2;
            OR:   result = op1 | op2;
            XOR:  result = op1 ^ op2;
            SLL:  result = op1 << op2[4:0];
            SRL:  result = op1 >> op2[4:0];
            SRA:  result = $signed(op1) >>> op2[4:0];
            SLT:  result = ($signed(op1) < $signed(op2)) ? 32'd1 : 32'd0;
            SLTU: result = (op1 < op2) ? 32'd1 : 32'd0;
            SEQ:  result = (op1 == op2) ? 32'd1 : 32'd0;
            default: result = 32'd0;
        endcase
    end

endmodule
