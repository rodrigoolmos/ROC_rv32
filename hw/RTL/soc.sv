module soc #(
    parameter CLK_FREQ = 100_000_000,
    parameter BAUD_RATE = 115200,
    parameter int ADDR_WIDTH = 10,
    parameter int DATA_WIDTH = 32,
    // Base address for data memory (Harvard mapping).
    // All LOAD/STORE addresses are expected to be in [DMEM_BASE, DMEM_BASE + 4*2**ADDR_WIDTH_D).
    parameter logic [31:0] DMEM_BASE = 32'h1000_0000
) (
    input  logic                               clk,
    input  logic                               rst_n,
    output  logic                              led_status,

    input  logic rx,                        // Receive data line bootloader
    output logic tx                         // Transmit data line bootloader

);


    // instruction memory
    logic [DATA_WIDTH-1:0]            data_imem_o;
    (* MARK_DEBUG = "TRUE" *) logic [DATA_WIDTH-1:0] data_imem_i;
    logic [ADDR_WIDTH-1:0]            imem_addr_cpu;
    (* MARK_DEBUG = "TRUE" *) logic [ADDR_WIDTH-1:0] imem_addr_boot;
    (* MARK_DEBUG = "TRUE" *) logic we_i;

    // data memory
    logic                              wena_mem_d;
    logic [ADDR_WIDTH-1:0]             dmem_addr_cpu;
    (* MARK_DEBUG = "TRUE" *) logic [ADDR_WIDTH-1:0] dmem_addr_boot;
    logic [DATA_WIDTH-1:0]             store_wdata;
    logic [DATA_WIDTH-1:0]             data_dmem_o;
    (* MARK_DEBUG = "TRUE" *) logic [DATA_WIDTH-1:0] data_dmem_boot_o;
    logic [(DATA_WIDTH/8)-1:0]         store_strb;

    // Core CPU
    ROC_RV32 #(
        .ADDR_WIDTH_I(ADDR_WIDTH),
        .DATA_WIDTH_I(DATA_WIDTH),
        .ADDR_WIDTH_D(ADDR_WIDTH),
        .DATA_WIDTH_D(DATA_WIDTH),
        .DMEM_BASE(DMEM_BASE)
    ) cpu_core (
        .clk(clk),
        .rst_n(rst_n),
        // instruction memory
        .data_imem(data_imem_o),
        .imem_addr(imem_addr_cpu),
        // data memory
        .wena_mem(wena_mem_d),
        .store_strb(store_strb),
        .dmem_addr(dmem_addr_cpu),
        .store_wdata(store_wdata),
        .data_dmem_o(data_dmem_o)
    );

    // Instruction Memory (sync read)
    imem #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) instruction_memory (
        .clk(clk),

        // Port A CORE
        .en_a(1),
        .we_a(0),                 // Not used for instruction memory ROM
        .addr_a(imem_addr_cpu),
        .din_a(32'b0),            // Not used for instruction memory ROM
        .dout_a(data_imem_o),

        // Port B DEBUG/DMA
        .en_b(1),
        .we_b(we_i),
        .wstrb_b(4'b1111),
        .addr_b(imem_addr_boot),
        .din_b(data_imem_i),
        .dout_b()                // Not used
    );

    // Data Memory
    dmem #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) data_memory (
        .clk(clk),

        // Port A CORE
        .en_a(1),
        .we_a(wena_mem_d),
        .wstrb_a(store_strb),
        .addr_a(dmem_addr_cpu),
        .din_a(store_wdata),
        .dout_a(data_dmem_o),

        // Port B DEBUG/DMA
        .en_b(1),
        .we_b(0),
        .wstrb_b(),
        .addr_b(dmem_addr_boot),
        .din_b(),         // Not used
        .dout_b(data_dmem_boot_o)
    );

    // Bootloader Load/Store Controller
    load_store_controller #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE),
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) loader (
        .clk(clk),
        .nrst(rst_n),

        .rx(rx),
        .tx(tx),

        // DMEM Interface
        .addr_d(dmem_addr_boot),
        .dout_d(data_dmem_boot_o),

        // IMEM Interface
        .we_i(we_i),
        .addr_i(imem_addr_boot),
        .din_i(data_imem_i)
    );

    assign led_status = ~rst_n;

endmodule