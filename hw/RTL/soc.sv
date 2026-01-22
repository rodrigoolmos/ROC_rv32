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
    logic [(DATA_WIDTH/8)-1:0]         store_strb;
    logic [ADDR_WIDTH-1:0]             dmem_addr_cpu;
    logic [DATA_WIDTH-1:0]             store_wdata;
    logic [DATA_WIDTH-1:0]             data_dmem_o;
    logic [ADDR_WIDTH-1:0]             dmem_addr_boot;
    logic [DATA_WIDTH-1:0]             data_dmem_boot_o;

    // LSU interconnect signals
    logic                    rready_lsu;
    logic                    rvalid_lsu;
    logic                    wready_lsu;
    logic                    wvalid_lsu;
    logic [3:0]              strb_lsu;
    logic [31:0]             addr_lsu;
    logic [31:0]             data_lsu_i;
    logic [31:0]             data_lsu_o;

    // AXI4-Lite MASTER INTERFACE signals
    logic [31:0]              awaddr;
    logic [2:0]               awprot;
    logic                     awvalid;
    logic                     awready;
    logic [31:0]              wdata;
    logic [3:0]               wstrb;
    logic                     wvalid;
    logic                     wready;
    logic [1:0]               bresp;
    logic                     bvalid;
    logic                     bready;
    logic [31:0]              araddr;
    logic [2:0]               arprot;
    logic                     arvalid;
    logic                     arready;
    logic [31:0]              rdata;
    logic [1:0]               rresp;
    logic                     rvalid;
    logic                     rready;

    // Core CPU
    ROC_RV32 #(
        .ADDR_WIDTH_I(ADDR_WIDTH),
        .DATA_WIDTH_I(DATA_WIDTH),
        .ADDR_WIDTH_D(ADDR_WIDTH),
        .DATA_WIDTH_D(DATA_WIDTH)
    ) cpu_core (
        .clk(clk),
        .rst_n(rst_n),
        // instruction memory
        .data_imem(data_imem_o),
        .imem_addr(imem_addr_cpu),
        // lsu
        .rready_cpu(rready_lsu),
        .rvalid_cpu(rvalid_lsu),
        .wready_cpu(wready_lsu),
        .wvalid_cpu(wvalid_lsu),
        .strb_cpu(strb_lsu),
        .addr_cpu(addr_lsu),
        .data_cpu_o(data_lsu_i),
        .data_cpu_i(data_lsu_o)
    );

    // AXI4-Lite example peripheral
    axi_lite_template #(
        .C_ADDR_WIDTH(9),
        .C_DATA_WIDTH(32)
    ) example_peripheral (
        .clk(clk),
        .nrst(rst_n),

        // AXI4-Lite SLAVE
        .awaddr(awaddr),
        .awprot(awprot),
        .awvalid(awvalid),
        .awready(awready),

        .wdata(wdata),
        .wstrb(wstrb),
        .wvalid(wvalid),
        .wready(wready),

        .bresp(bresp),
        .bvalid(bvalid),
        .bready(bready),

        .araddr(araddr),
        .arprot(arprot),
        .arvalid(arvalid),
        .arready(arready),

        .rdata(rdata),
        .rresp(rresp),
        .rvalid(rvalid),
        .rready(rready)
    );

    // LSU Interconnect
    lsu_interconnect #(
        .ADDR_DMEM_WIDTH(ADDR_WIDTH),
        .DMEM_BASE(DMEM_BASE)
    ) lsu_ic (
        .clk(clk),
        .nrst(rst_n),

        // DMEM INTERFACE
        .we_dmem(wena_mem_d),
        .wstrb_dmem(store_strb),
        .addr_dmem(dmem_addr_cpu),
        .din_dmem(store_wdata),
        .dout_dmem(data_dmem_o),

        // AXI4-Lite MASTER INTERFACE
        .awaddr(awaddr),
        .awprot(awprot),
        .awvalid(awvalid),
        .awready(awready),

        .wdata(wdata),
        .wstrb(wstrb),
        .wvalid(wvalid),
        .wready(wready),

        .bresp(bresp),
        .bvalid(bvalid),
        .bready(bready),

        .araddr(araddr),
        .arprot(arprot),
        .arvalid(arvalid),
        .arready(arready),

        .rdata(rdata),
        .rresp(rresp),
        .rvalid(rvalid),
        .rready(rready),

        // CPU INTERFACE
        .rready_lsu(rready_lsu),
        .rvalid_lsu(rvalid_lsu),
        .wready_lsu(wready_lsu),
        .wvalid_lsu(wvalid_lsu),
        .strb_lsu(strb_lsu),
        .addr_lsu(addr_lsu),
        .data_lsu_i(data_lsu_i),
        .data_lsu_o(data_lsu_o)
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
