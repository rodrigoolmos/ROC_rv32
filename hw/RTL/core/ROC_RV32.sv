import alu_ops_pkg::*;
import rv32_opcodes_pkg::*;

module ROC_RV32 #(
    parameter int ADDR_WIDTH_I = 10,
    parameter int DATA_WIDTH_I = 32,
    parameter int ADDR_WIDTH_D = 10,
    parameter int DATA_WIDTH_D = 32,
    parameter int N_EXT_IRQ = 8,
    parameter logic [31:0] RESET_MTVEC = 32'h0000_1000
) (
    input  logic                               clk,
    input  logic                               rst_n,
    // instruction memory
    input  logic [DATA_WIDTH_I-1:0]            data_imem,
    output logic [ADDR_WIDTH_I-1:0]            imem_addr,

    // LSU
    output  logic                    rready_cpu,
    input   logic                    rvalid_cpu,
    input   logic                    wready_cpu,
    output  logic                    wvalid_cpu,
    output  logic [3:0]              strb_cpu,
    output  logic [31:0]             addr_cpu,
    output  logic [31:0]             data_cpu_o,
    input   logic [31:0]             data_cpu_i,
    input   logic                    timer_irq
);

    localparam logic [31:0] INSN_MRET = 32'h3020_0073;

    logic [31:0] ir;
    

    logic [31:0] op1;
    logic [31:0] op2;
    alu_ops_pkg::alu_op_t op_type;
    logic [31:0] result;

    logic [4:0]  rs1;
    logic [4:0]  rs2;
    logic [4:0]  rd;
    logic [6:0]  opcode;
    logic [2:0]  funct3;
    logic [6:0]  funct7;
    logic [11:0] imm_i;
    logic [11:0] imm_s;
    logic [12:0] imm_b;
    logic [19:0] imm_u;
    logic [20:0] imm_j;

    logic [31:0] pc_output;
    logic [31:0] pc_ir;
    logic [31:0] pc_ir_plus4;

    logic        wena_reg;
    logic        csr_wena;
    logic [11:0] csr_addr;
    logic [31:0] csr_wdata;
    logic        mret_commit;
    logic [31:0] imm_ext;
    logic        alu_src1;
    logic        alu_src2;
    logic [1:0]  data_2_reg;
    logic        branch_invert;

    logic [2:0]  cpu_state;

    logic [31:0] alu_out;

    logic [31:0] load_ext;

    logic [31:0] reg_di;
    logic [31:0] do1;
    logic [31:0] do2;

    logic [31:0] alu_op1;
    logic [31:0] csr_rdata;
    logic        take_trap;
    logic [31:0] trap_pc;
    logic        take_return;
    logic [31:0] return_pc;

    // Word-addressed memories (PC/result are byte addresses)
    assign imem_addr = pc_output[ADDR_WIDTH_I+1:2];
    assign addr_cpu = alu_out;

    //////////////// ALU ////////////////
    // MUX for ALU operand 2 immediate or register
    assign op2 = alu_src2 ? imm_ext : do2;
    // MUX for ALU operand 1 PC (for AUIPC) or register
    assign op1 = alu_src1 ? pc_ir : do1;
    alu alu_ins(
        .op1(op1),
        .op2(op2),
        .op_type(op_type),
        .result(result)
    );

    // control unit
    control_unit control_unit_ins(
        .clk(clk),
        .rst_n(rst_n),
        // From decoder
        .opcode(opcode),
        .funct3(funct3),
        .funct7(funct7),
        .imm_i(imm_i),
        .imm_s(imm_s),
        .imm_b(imm_b),
        .imm_u(imm_u),
        .imm_j(imm_j),

        // From datapath/memory (for load/store formatting)
        .alu_out(alu_out),
        .rs2_data(do2),
        .data_cpu_o(data_cpu_o),

        .cpu_state(cpu_state),
        // control signals
        .wena_reg(wena_reg),            // Write enable for register bank
        .op_type(op_type),              // ALU operation type
        .imm_ext(imm_ext),              // Extended immediate value
        .alu_src1(alu_src1),            // 0: operand A = rs1, 1: operand A = pc
        .alu_src2(alu_src2),            // 0: operand B = rs2, 1: operand B = immediate
        .rready_cpu(rready_cpu),        // Read enable for LSU
        .rvalid_cpu(rvalid_cpu),        // Read valid from LSU
        .wready_cpu(wready_cpu),        // Write ready from LSU
        .wvalid_cpu(wvalid_cpu),        // Write enable for LSU
        .data_2_reg(data_2_reg),        // Data to register from ALU 00 Memory 01 PC 10 IMM 11 
        .branch_invert(branch_invert),  // Branch taken signal MUX control

        .load_ext(load_ext),            // Data sign extended
        .data_cpu_i(data_cpu_i),        // Data to store after formatting
        .strb_cpu(strb_cpu)             // Byte write strobe for store
    );

    // Decode minimal SYSTEM support needed by the machine-trap CSR block.
    // SYSTEM instructions are retired in WB in this core.
    always_comb begin
        csr_wena = 1'b0;
        csr_addr = imm_i;
        csr_wdata = 32'b0;
        mret_commit = 1'b0;

        if (cpu_state == 3'd4 && opcode == OPC_SYSTEM) begin
            unique case (funct3)
                3'b001: begin // CSRRW
                    csr_wena = 1'b1;
                    csr_wdata = do1;
                end
                3'b010: begin // CSRRS
                    if (rs1 != 5'b0) begin
                        csr_wena = 1'b1;
                        csr_wdata = csr_rdata | do1;
                    end
                end
                3'b011: begin // CSRRC
                    if (rs1 != 5'b0) begin
                        csr_wena = 1'b1;
                        csr_wdata = csr_rdata & ~do1;
                    end
                end
                3'b101: begin // CSRRWI
                    csr_wena = 1'b1;
                    csr_wdata = {27'b0, rs1};
                end
                3'b110: begin // CSRRSI
                    if (rs1 != 5'b0) begin
                        csr_wena = 1'b1;
                        csr_wdata = csr_rdata | {27'b0, rs1};
                    end
                end
                3'b111: begin // CSRRCI
                    if (rs1 != 5'b0) begin
                        csr_wena = 1'b1;
                        csr_wdata = csr_rdata & ~{27'b0, rs1};
                    end
                end
                3'b000: begin
                    if (ir == INSN_MRET) begin
                        mret_commit = 1'b1;
                    end
                end
                default: ;
            endcase
        end
    end

    // mtrap and CSR unit
    rv32_mtrap_csr #(
        .N_EXT_IRQ(N_EXT_IRQ),
        .RESET_MTVEC(RESET_MTVEC)
    ) mtrap_csr_ins (
        .clk(clk),
        .rst_n(rst_n),

        // Interrupt lines from peripherals
        .irq_software(1'b0),
        .irq_timer(timer_irq),
        .irq_external('0),

        .mret_commit(mret_commit),

        .csr_wena(csr_wena),
        .csr_addr(csr_addr),
        .csr_wdata(csr_wdata),
        .csr_rdata(csr_rdata),

        // Trap decision point (commit point)
        .instr_commit(cpu_state == 3'd4),
        .actual_pc(pc_output),

        // Trap control outputs to CPU
        .take_trap(take_trap),
        .trap_pc(trap_pc),
        .take_return(take_return),
        .return_pc(return_pc)
    );

    // decoder
    decoder decoder_ins(
        .instruction(ir),
        .rs1(rs1),
        .rs2(rs2),
        .rd(rd),
        .opcode(opcode),
        .funct3(funct3),
        .funct7(funct7),
        .imm_i(imm_i),
        .imm_s(imm_s),
        .imm_b(imm_b),
        .imm_u(imm_u),
        .imm_j(imm_j)
    );

    // program counter
    assign pc_ir_plus4 = pc_ir + 32'd4;
    pc program_counter (
        .clk(clk),
        .rst_n(rst_n),
        .cpu_state(cpu_state),
        .opcode(opcode),
        .result(result),
        .branch_invert(branch_invert),
        .take_trap(take_trap),
        .trap_pc(trap_pc),
        .take_return(take_return),
        .return_pc(return_pc),
        .pc_ir(pc_ir),
        .imm_ext(imm_ext),
        .do1(do1),
        .pc_output(pc_output)
    );

    // IR and ALUOut registers (multi-cycle)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ir     <= 32'b0;
            pc_ir  <= 32'b0;
            alu_out <= 32'b0;
        end else begin
            // Latch instruction/PC during DECODE (imem dout is stable during FETCH)
            if (cpu_state == 3'd1) begin // S_DECODE
                ir    <= data_imem;
                pc_ir <= pc_output;
            end

            // Latch ALU result during EXEC
            if (cpu_state == 3'd2) begin // S_EXEC
                alu_out <= result;
            end
        end
    end

    // register bank
    always_comb begin
        if (opcode == OPC_SYSTEM && funct3 != 3'b000) begin
            reg_di = csr_rdata;               // CSR* writes old CSR value to rd
        end else begin
            case (data_2_reg)
                2'b00: reg_di = alu_out;      // From ALUOut
                2'b01: reg_di = load_ext;     // From Memory (extended)
                2'b10: reg_di = pc_ir_plus4;  // From instr PC + 4
                2'b11: reg_di = imm_ext;      // From IMM
                default: reg_di = 32'b0;
            endcase
        end
    end
    register_bank register_bank_ins(
        .clk(clk),
        .rst_n(rst_n),
        .rs1(rs1),
        .rs2(rs2),
        .rd(rd),
        .di(reg_di),
        .we(wena_reg),
        .do1(do1),
        .do2(do2)
    );

endmodule
