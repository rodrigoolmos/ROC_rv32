import rv32_opcodes_pkg::*;

module pc(
    input  logic        clk,
    input  logic        rst_n,
    input  logic [2:0]  cpu_state,
    input  logic [6:0]  opcode,
    input  logic [31:0] result,
    input  logic        branch_invert,
    input  logic        take_trap,
    input  logic [31:0] trap_pc,
    input  logic        take_return,
    input  logic [31:0] return_pc,
    input  logic [31:0] pc_ir,
    input  logic [31:0] imm_ext,
    input  logic [31:0] do1,
    output logic [31:0] pc_output
);

    logic [31:0] pc_reg;
    logic        pc_we;
    logic        branch_taken;
    logic [31:0] pc_next;

    // Trap/return redirection has priority over normal flow.
    always_comb begin
        branch_taken = 0;
        if (take_trap) begin
            pc_next = trap_pc;
        end else if (take_return) begin
            pc_next = return_pc;
        end else begin
            pc_next = pc_ir + 32'd4;
            unique case (opcode)
                // if branch taken, pc_next = pc_ir + imm_ext else pc_ir + 4
                // if(condition) pc = target else pc = pc + 4
                OPC_BRANCH: begin
                    branch_taken = (result[0] ^ branch_invert);
                    pc_next = branch_taken ? (pc_ir + imm_ext)
                                           : (pc_ir + 32'd4);
                end
                // Jump and link
                OPC_JAL:  pc_next = pc_ir + imm_ext;
                OPC_JALR: pc_next = (do1 + imm_ext) & 32'hFFFF_FFFE;
                default:  pc_next = pc_ir + 32'd4;
            endcase
        end
    end

    // PC normally updates in EXEC, and also on trap/return redirects.
    assign pc_we = (cpu_state == 3'd2) | take_trap | take_return;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            pc_reg <= 0;
        else if (pc_we)
            pc_reg <= pc_next;
    end

    assign pc_output = pc_reg;

endmodule
