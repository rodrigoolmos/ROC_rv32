module decoder(
    input  logic [31:0] instruction,
    output logic [4:0]  rs1,
    output logic [4:0]  rs2,
    output logic [4:0]  rd,
    output logic [6:0]  opcode,
    output logic [2:0]  funct3,
    output logic [6:0]  funct7,
    output logic [11:0] imm_i,
    output logic [11:0] imm_s,
    output logic [12:0] imm_b,
    output logic [19:0] imm_u,
    output logic [20:0] imm_j
);

    assign opcode = instruction[6:0];
    assign rd     = instruction[11:7];
    assign funct3 = instruction[14:12];
    assign rs1    = instruction[19:15];
    assign rs2    = instruction[24:20];
    assign funct7 = instruction[31:25];

    // I-type
    assign imm_i = instruction[31:20];

    // S-type
    assign imm_s = {instruction[31:25], instruction[11:7]};

    // B-type (imm[0] = 0)
    assign imm_b = {instruction[31],
                    instruction[7],
                    instruction[30:25],
                    instruction[11:8],
                    1'b0};
    // U-type
    assign imm_u = instruction[31:12];

    // J-type
    assign imm_j = {instruction[31],
                    instruction[19:12],
                    instruction[20],
                    instruction[30:21],
                    1'b0}; // J-type


endmodule
