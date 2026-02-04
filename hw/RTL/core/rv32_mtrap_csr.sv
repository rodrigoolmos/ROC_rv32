module rv32_mtrap_csr #(
    parameter int N_EXT_IRQ = 8,
    parameter logic [31:0] RESET_MTVEC = 32'h0000_1000
) (
    input  logic                    clk,
    input  logic                    rst_n,

    // Interrupt lines from peripherals
    input  logic                    irq_software,
    input  logic                    irq_timer,
    input  logic [N_EXT_IRQ-1:0]    irq_external,

    // "mret executed" event from CPU (commit stage)
    input  logic                    mret_commit,

    // CSR access from CPU (simple full write)
    input  logic                    csr_wena,
    input  logic [11:0]             csr_addr,
    input  logic [31:0]             csr_wdata,
    output logic [31:0]             csr_rdata,

    // Trap decision point (commit point)
    input  logic                    instr_commit,
    input  logic [31:0]             actual_pc,

    // Trap control outputs to CPU
    output logic                    take_trap,
    output logic [31:0]             trap_pc,
    output logic                    take_return,
    output logic [31:0]             return_pc
);

    localparam logic [11:0] CSR_MSTATUS = 12'h300;
    localparam logic [11:0] CSR_MIE     = 12'h304;
    localparam logic [11:0] CSR_MTVEC   = 12'h305;
    localparam logic [11:0] CSR_MEPC    = 12'h341;
    localparam logic [11:0] CSR_MCAUSE  = 12'h342;
    localparam logic [11:0] CSR_MIP     = 12'h344;

    localparam int MSTATUS_MIE_BIT = 3;
    localparam int MSTATUS_MPIE_BIT = 7;
    localparam int MIE_MSIE_BIT = 3;
    localparam int MIE_MTIE_BIT = 7;
    localparam int MIE_MEIE_BIT = 11;

    localparam logic [31:0] MCAUSE_MSI = 32'h8000_0003;
    localparam logic [31:0] MCAUSE_MTI = 32'h8000_0007;
    localparam logic [31:0] MCAUSE_MEI = 32'h8000_000B;

    logic [31:0] mstatus;
    logic [31:0] mie;
    logic [31:0] mtvec;
    logic [31:0] mepc;
    logic [31:0] mcause;
    logic [31:0] mip;

    logic global_ie;
    logic pend_swi;
    logic pend_tim;
    logic pend_ext;
    logic irq_take;
    logic [31:0] irq_mcause;

    always_comb begin
        mip = 32'b0;
        mip[MIE_MSIE_BIT] = irq_software;
        mip[MIE_MTIE_BIT] = irq_timer;
        mip[MIE_MEIE_BIT] = |irq_external;
    end

    assign trap_pc = mtvec;
    assign return_pc = mepc;

    always_comb begin
        global_ie = mstatus[MSTATUS_MIE_BIT];

        pend_swi = global_ie & mie[MIE_MSIE_BIT] & mip[MIE_MSIE_BIT];
        pend_tim = global_ie & mie[MIE_MTIE_BIT] & mip[MIE_MTIE_BIT];
        pend_ext = global_ie & mie[MIE_MEIE_BIT] & mip[MIE_MEIE_BIT];
    end

    // Interrupt priority: external > timer > software.
    always_comb begin
        irq_take = 1'b0;
        irq_mcause = 32'b0;

        if (pend_ext) begin
            irq_take = 1'b1;
            irq_mcause = MCAUSE_MEI;
        end else if (pend_tim) begin
            irq_take = 1'b1;
            irq_mcause = MCAUSE_MTI;
        end else if (pend_swi) begin
            irq_take = 1'b1;
            irq_mcause = MCAUSE_MSI;
        end
    end

    // Traps are accepted only at instruction commit boundaries.
    assign take_trap = instr_commit & irq_take;
    assign take_return = instr_commit & mret_commit;

    always_comb begin
        csr_rdata = 32'b0;
        unique case (csr_addr)
            CSR_MSTATUS: csr_rdata = mstatus;
            CSR_MIE:     csr_rdata = mie;
            CSR_MTVEC:   csr_rdata = mtvec;
            CSR_MEPC:    csr_rdata = mepc;
            CSR_MCAUSE:  csr_rdata = mcause;
            CSR_MIP:     csr_rdata = mip;
            default:     csr_rdata = 32'b0;
        endcase
    end

    // Priority: trap > mret > software CSR write.
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mstatus <= 32'b0;
            mie <= 32'b0;
            mtvec <= {RESET_MTVEC[31:2], 2'b00};
            mepc <= 32'b0;
            mcause <= 32'b0;
        end else begin
            if (take_trap) begin
                mepc <= {actual_pc[31:1], 1'b0};
                mcause <= irq_mcause;

                mstatus[MSTATUS_MPIE_BIT] <= mstatus[MSTATUS_MIE_BIT];
                mstatus[MSTATUS_MIE_BIT] <= 1'b0;
            end else if (take_return) begin
                mstatus[MSTATUS_MIE_BIT] <= mstatus[MSTATUS_MPIE_BIT];
                mstatus[MSTATUS_MPIE_BIT] <= 1'b1;
            end else if (csr_wena) begin
                unique case (csr_addr)
                    CSR_MSTATUS: begin
                        mstatus[MSTATUS_MIE_BIT] <= csr_wdata[MSTATUS_MIE_BIT];
                        mstatus[MSTATUS_MPIE_BIT] <= csr_wdata[MSTATUS_MPIE_BIT];
                    end
                    CSR_MIE: begin
                        mie[MIE_MSIE_BIT] <= csr_wdata[MIE_MSIE_BIT];
                        mie[MIE_MTIE_BIT] <= csr_wdata[MIE_MTIE_BIT];
                        mie[MIE_MEIE_BIT] <= csr_wdata[MIE_MEIE_BIT];
                    end
                    CSR_MTVEC: mtvec <= {csr_wdata[31:2], 2'b00};
                    CSR_MEPC: mepc <= {csr_wdata[31:1], 1'b0};
                    CSR_MCAUSE: mcause <= csr_wdata;
                    default: ;
                endcase
            end
        end
    end

endmodule
