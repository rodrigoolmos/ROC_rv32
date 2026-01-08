module soc #(
    parameter int ADDR_WIDTH_I = 10,
    parameter int DATA_WIDTH_I = 32,
    parameter int ADDR_WIDTH_D = 10,
    parameter int DATA_WIDTH_D = 32,
    // Base address for data memory (Harvard mapping).
    // All LOAD/STORE addresses are expected to be in [DMEM_BASE, DMEM_BASE + 4*2**ADDR_WIDTH_D).
    parameter logic [31:0] DMEM_BASE = 32'h1000_0000
) (
    input  logic                               clk,
    input  logic                               rst_n,

    // Debug/DMA Port B access to IMEM
    input  logic                               imem_b_en,
    input  logic                               imem_b_we,
    input  logic [(DATA_WIDTH_I/8)-1:0]         imem_b_wstrb,
    input  logic [ADDR_WIDTH_I-1:0]             imem_b_addr,
    input  logic [DATA_WIDTH_I-1:0]             imem_b_wdata,
    output logic [DATA_WIDTH_I-1:0]             imem_b_rdata,

    // Debug/DMA Port B access to DMEM
    input  logic                               dmem_b_en,
    input  logic                               dmem_b_we,
    input  logic [(DATA_WIDTH_D/8)-1:0]         dmem_b_wstrb,
    input  logic [ADDR_WIDTH_D-1:0]             dmem_b_addr,
    input  logic [DATA_WIDTH_D-1:0]             dmem_b_wdata,
    output logic [DATA_WIDTH_D-1:0]             dmem_b_rdata
);

    // instruction memory
    logic [DATA_WIDTH_I-1:0]            data_imem;
    logic [ADDR_WIDTH_I-1:0]            imem_addr;

    // data memory
    logic                                wena_mem;
    logic [(DATA_WIDTH_D/8)-1:0]         store_strb;
    logic [ADDR_WIDTH_D-1:0]             dmem_addr;
    logic [DATA_WIDTH_D-1:0]             store_wdata;
    logic [DATA_WIDTH_D-1:0]             data_dmem_o;

    // Core CPU
    ROC_RV32 #(
        .ADDR_WIDTH_I(ADDR_WIDTH_I),
        .DATA_WIDTH_I(DATA_WIDTH_I),
        .ADDR_WIDTH_D(ADDR_WIDTH_D),
        .DATA_WIDTH_D(DATA_WIDTH_D),
        .DMEM_BASE(DMEM_BASE)
    ) cpu_core (
        .clk(clk),
        .rst_n(rst_n),
        // instruction memory
        .data_imem(data_imem),
        .imem_addr(imem_addr),
        // data memory
        .wena_mem(wena_mem),
        .store_strb(store_strb),
        .dmem_addr(dmem_addr),
        .store_wdata(store_wdata),
        .data_dmem_o(data_dmem_o)
    );

    // Instruction Memory (sync read)
    imem #(
        .ADDR_WIDTH(ADDR_WIDTH_I),
        .DATA_WIDTH(DATA_WIDTH_I)
    ) instruction_memory (
        .clk(clk),

        // Port A CORE
        .en_a(1'b1),
        .we_a(1'b0),              // Not used for instruction memory ROM
        .addr_a(imem_addr),
        .din_a(32'b0),            // Not used for instruction memory ROM
        .dout_a(data_imem),

        // Port B DEBUG/DMA
        .en_b(imem_b_en),
        .we_b(imem_b_we),
        .wstrb_b(imem_b_wstrb),
        .addr_b(imem_b_addr),
        .din_b(imem_b_wdata),
        .dout_b(imem_b_rdata)
    );

    // Data Memory
    dmem #(
        .ADDR_WIDTH(ADDR_WIDTH_D),
        .DATA_WIDTH(DATA_WIDTH_D)
    ) data_memory (
        .clk(clk),

        // Port A CORE
        .en_a(1'b1),
        .we_a(wena_mem),
        .wstrb_a(store_strb),
        .addr_a(dmem_addr),
        .din_a(store_wdata),
        .dout_a(data_dmem_o),

        // Port B DEBUG/DMA
        .en_b(dmem_b_en),
        .we_b(dmem_b_we),
        .wstrb_b(dmem_b_wstrb),
        .addr_b(dmem_b_addr),
        .din_b(dmem_b_wdata),
        .dout_b(dmem_b_rdata)
    );

endmodule