import alu_ops_pkg::*;
import rv32_opcodes_pkg::*;

module control_unit(
    input logic        clk,
    input logic        rst_n,
    // From decoder
    input logic [6:0]  opcode,
    input logic [2:0]  funct3,
    input logic [6:0]  funct7,
    input logic [11:0] imm_i,
    input logic [11:0] imm_s,
    input logic [12:0] imm_b,
    input logic [19:0] imm_u,
    input logic [20:0] imm_j,

    // From datapath/memory (for load/store formatting)
    input logic [31:0] alu_out,
    input logic [31:0] rs2_data,
    input logic [31:0] data_cpu_i,

    output logic [2:0]  cpu_state,

    output logic        wena_reg,   // Write enable for register bank
    output alu_ops_pkg::alu_op_t op_type,    // ALU operation type
    output logic [31:0] imm_ext,    // Extended immediate value
    // 0: operand A = rs1, 1: operand A = pc
    output logic        alu_src1,
    // 0: operand B = rs2, 1: operand B = immediate
    output logic        alu_src2,
    output  logic       rready_cpu,   // Read ready for lsu
    input   logic       rvalid_cpu,   // Read valid from lsu
    input   logic       wready_cpu,   // Write ready from lsu
    output logic        wvalid_cpu,   // Write enable for lsu
    // Data to register from ALU 00 Memory 01 PC 10 IMM 11 
    output logic [1:0]  data_2_reg,
    // select if branch is taken or not since we only have in ALU
    // SEQ o SLT/SLTU take_branch = (alu_result[0] ^ branch_invert);
    output logic        branch_invert,

    // To datapath/memory
    output logic [31:0] load_ext,
    output logic [31:0] data_cpu_o,
    output logic [3:0]  strb_cpu
);

    localparam logic [2:0]
        S_FETCH  = 3'd0,
        S_DECODE = 3'd1,
        S_EXEC   = 3'd2,
        S_MEM    = 3'd3,
        S_WB     = 3'd4;

    // Fully sequential FSM (multi-cycle, no pipeline)
    // Note: opcode/funct* are stable because the top-level latches IR.
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cpu_state <= S_FETCH;
            rready_cpu <= 0;
            wvalid_cpu <= 0;
        end else begin
            // Default deassertions each cycle; asserted only in S_MEM.
            rready_cpu <= 1'b0;
            wvalid_cpu <= 1'b0;

            unique case (cpu_state)
                // Wait 1 cycle so synchronous imem presents the instruction for current PC.
                S_FETCH:  cpu_state <= S_DECODE;

                // In DECODE, the top-level latches IR <= imem_dout.
                S_DECODE: cpu_state <= S_EXEC;

                // Execute: compute ALU/compare and decide if memory/WB is needed.
                S_EXEC: begin
                    unique case (opcode)
                        OPC_LOAD:   cpu_state <= S_MEM;   // LOAD
                        OPC_STORE:  cpu_state <= S_MEM;   // STORE
                        OPC_BRANCH: cpu_state <= S_FETCH; // BRANCH (no WB)
                        default:    cpu_state <= S_WB;    // ALU/JAL/JALR/LUI/AUIPC
                    endcase
                end

                // Memory access: for LOAD we need a WB cycle; for STORE we're done.
                S_MEM: begin
                    if (opcode == OPC_LOAD) begin
                        rready_cpu <= 1'b1;
                        if (rvalid_cpu & rready_cpu) begin
                            rready_cpu <= 1'b0;
                            cpu_state <= S_WB;
                        end
                    end else if (opcode == OPC_STORE) begin
                        wvalid_cpu <= 1'b1;
                        if (wready_cpu & wvalid_cpu) begin
                            wvalid_cpu <= 1'b0;
                            cpu_state <= S_FETCH;
                        end
                    end else begin
                        cpu_state <= S_FETCH;
                    end
                end

                // Writeback then fetch next.
                S_WB:    cpu_state <= S_FETCH;

                default: cpu_state <= S_FETCH;
            endcase
        end
    end

    // ALU control + operand mux selects
    // alu_src1: 0 => A=rs1, 1 => A=pc_ir (only AUIPC in this design)
    // alu_src2: 0 => B=rs2, 1 => B=imm_ext
    always_comb begin
        op_type = ADD;
        alu_src2 = 1'b0; // 0: B=rs2, 1: B=imm_ext
        alu_src1 = 1'b0; // 0: A=rs1, 1: A=pc

        unique case (opcode)
            // R-type
            OPC_OP: begin
                alu_src1 = 1'b0;
                alu_src2 = 1'b0;
                unique case ({funct7, funct3})
                    10'b0000000_000: op_type = ADD;
                    10'b0100000_000: op_type = SUB;
                    10'b0000000_111: op_type = AND;
                    10'b0000000_110: op_type = OR;
                    10'b0000000_100: op_type = XOR;
                    10'b0000000_001: op_type = SLL;
                    10'b0000000_101: op_type = SRL;
                    10'b0100000_101: op_type = SRA;
                    10'b0000000_010: op_type = SLT;
                    10'b0000000_011: op_type = SLTU;
                    default:         op_type = ADD;
                endcase
            end

            // I-type ALU
            OPC_OP_IMM: begin
                alu_src1 = 1'b0;
                alu_src2 = 1'b1;
                unique case (funct3)
                    3'b000: op_type = ADD;   // ADDI
                    3'b111: op_type = AND;   // ANDI
                    3'b110: op_type = OR;    // ORI
                    3'b100: op_type = XOR;   // XORI
                    3'b010: op_type = SLT;   // SLTI
                    3'b011: op_type = SLTU;  // SLTIU
                    3'b001: op_type = SLL;   // SLLI
                    3'b101: begin
                        // SRLI/SRAI distinguished by funct7
                        if (funct7 == 7'b0100000)
                            op_type = SRA;
                        else
                            op_type = SRL;
                    end
                    default: op_type = ADD;
                endcase
            end

            // Address/rs1+imm math
            OPC_LOAD,
            OPC_STORE,
            OPC_JALR: begin
                alu_src1 = 1'b0;
                alu_src2 = 1'b1;
                op_type  = ADD;
            end

            // AUIPC: rd = PC + imm_u
            OPC_AUIPC: begin
                alu_src1 = 1'b1;
                alu_src2 = 1'b1;
                op_type  = ADD;
            end

            // BRANCH: compare rs1 vs rs2 using ALU as comparator
            OPC_BRANCH: begin
                alu_src1 = 1'b0;
                alu_src2 = 1'b0;
                unique case (funct3)
                    3'b000: op_type = SEQ;   // BEQ
                    3'b001: op_type = SEQ;   // BNE (invert outside)
                    3'b100: op_type = SLT;   // BLT
                    3'b101: op_type = SLT;   // BGE (invert outside)
                    3'b110: op_type = SLTU;  // BLTU
                    3'b111: op_type = SLTU;  // BGEU (invert outside)
                    default: op_type = SEQ;
                endcase
            end

            default: begin
                alu_src1  = 1'b0;
                alu_src2  = 1'b0;
                op_type = ADD;
            end
        endcase
    end


    // select if data comes from ALU, Memory, PC+4 or IMM
    always_comb begin
        data_2_reg = 2'b00; // default: ALU

        if (cpu_state == S_WB) begin
            unique case (opcode)
                OPC_LOAD: data_2_reg = 2'b01; // LOAD -> Memory
                OPC_JAL,
                OPC_JALR: data_2_reg = 2'b10; // JAL/JALR -> PC+4
                OPC_LUI:  data_2_reg = 2'b11; // LUI -> IMM
                // AUIPC writes PC+imm (typically computed by ALU) -> ALU (00)
                OPC_OP,
                OPC_OP_IMM,
                OPC_AUIPC: data_2_reg = 2'b00; // R/I/AUIPC -> ALU
                default:    data_2_reg = 2'b00; // don't care / safe default
            endcase
        end
    end

    // select if we are writing to register file
    always_comb begin
        wena_reg = 1'b0;
        if (cpu_state == S_WB) begin
            unique case (opcode)
                OPC_OP:     wena_reg = 1'b1; // R-type
                OPC_OP_IMM: wena_reg = 1'b1; // I-type ALU
                OPC_LOAD:   wena_reg = 1'b1; // LOAD
                OPC_JAL:    wena_reg = 1'b1; // JAL
                OPC_JALR:   wena_reg = 1'b1; // JALR
                OPC_LUI:    wena_reg = 1'b1; // LUI
                OPC_AUIPC:  wena_reg = 1'b1; // AUIPC
                default:    wena_reg = 1'b0;
            endcase
        end
    end

    // extend immediate value based on instruction type
    always_comb begin
        unique case (opcode)
            OPC_OP_IMM, // I-type ALU
            OPC_LOAD,   // LOAD
            OPC_JALR:   // JALR
                imm_ext = {{20{imm_i[11]}}, imm_i}; // I-type (12->32)

            OPC_STORE: // STORE
                imm_ext = {{20{imm_s[11]}}, imm_s}; // S-type (12->32)

            OPC_BRANCH: // BRANCH
                imm_ext = {{19{imm_b[12]}}, imm_b}; // B-type (13->32)

            OPC_LUI,   // LUI
            OPC_AUIPC: // AUIPC
                imm_ext = {imm_u, 12'b0}; // U-type (20<<12)

            OPC_JAL: // JAL
                imm_ext = {{11{imm_j[20]}}, imm_j}; // J-type (21->32)

            default:
                imm_ext = 32'b0;
        endcase
    end

    // select if branch is taken or not since we only have in ALU
    // SEQ o SLT/SLTU take_branch = (alu_result[0] ^ branch_invert);
    always_comb begin
        branch_invert = 1'b0;

        if (cpu_state == S_EXEC && opcode == OPC_BRANCH) begin
            unique case (funct3)
                3'b000: branch_invert = 1'b0; // BEQ  -> take =  alu_result
                3'b001: branch_invert = 1'b1; // BNE  -> take = ~alu_result
                3'b100: branch_invert = 1'b0; // BLT  -> take =  alu_result (SLT)
                3'b101: branch_invert = 1'b1; // BGE  -> take = ~alu_result (SLT)
                3'b110: branch_invert = 1'b0; // BLTU -> take =  alu_result (SLTU)
                3'b111: branch_invert = 1'b1; // BGEU -> take = ~alu_result (SLTU)
                default: branch_invert = 1'b0;
            endcase
        end
    end

    // Load sign/zero extension based on funct3 and byte offset (alu_out is byte address)
    always_comb begin
        load_ext = data_cpu_i;
        if (opcode == OPC_LOAD) begin
            unique case (funct3)
                3'b000: begin // LB
                    unique case (alu_out[1:0])
                        2'b00: load_ext = {{24{data_cpu_i[7]}},  data_cpu_i[7:0]};
                        2'b01: load_ext = {{24{data_cpu_i[15]}}, data_cpu_i[15:8]};
                        2'b10: load_ext = {{24{data_cpu_i[23]}}, data_cpu_i[23:16]};
                        2'b11: load_ext = {{24{data_cpu_i[31]}}, data_cpu_i[31:24]};
                        default: load_ext = 32'b0;
                    endcase
                end
                3'b001: begin // LH
                    if (alu_out[1] == 1'b0)
                        load_ext = {{16{data_cpu_i[15]}}, data_cpu_i[15:0]};
                    else
                        load_ext = {{16{data_cpu_i[31]}}, data_cpu_i[31:16]};
                end
                3'b010: load_ext = data_cpu_i; // LW
                3'b100: begin // LBU
                    unique case (alu_out[1:0])
                        2'b00: load_ext = {24'b0, data_cpu_i[7:0]};
                        2'b01: load_ext = {24'b0, data_cpu_i[15:8]};
                        2'b10: load_ext = {24'b0, data_cpu_i[23:16]};
                        2'b11: load_ext = {24'b0, data_cpu_i[31:24]};
                        default: load_ext = 32'b0;
                    endcase
                end
                3'b101: begin // LHU
                    if (alu_out[1] == 1'b0)
                        load_ext = {16'b0, data_cpu_i[15:0]};
                    else
                        load_ext = {16'b0, data_cpu_i[31:16]};
                end
                default: load_ext = data_cpu_i;
            endcase
        end
    end

    // Store data + byte strobes (SW/SB/SH)
    // Memory performs byte-masked merge using wstrb.
    always_comb begin
        data_cpu_o = rs2_data;
        strb_cpu  = 4'b0000;

        if (opcode == OPC_STORE) begin
            unique case (funct3)
                3'b010: begin // SW
                    data_cpu_o = rs2_data;
                    strb_cpu  = 4'b1111;
                end
                3'b000: begin // SB
                    data_cpu_o = {4{rs2_data[7:0]}} << (alu_out[1:0] * 8);
                    strb_cpu  = 4'b0001 << alu_out[1:0];
                end
                3'b001: begin // SH
                    data_cpu_o = {16'b0, rs2_data[15:0]} << (alu_out[1] * 16);
                    strb_cpu  = (alu_out[1] == 1'b0) ? 4'b0011 : 4'b1100;
                end
                default: begin
                    data_cpu_o = rs2_data;
                    strb_cpu  = 4'b0000;
                end
            endcase
        end
    end


endmodule
