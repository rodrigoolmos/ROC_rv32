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
    input  logic                               rst,
    output  logic                              led_status,

    input  logic rx,                        // Receive data line bootloader
    output logic tx,                        // Transmit data line bootloader

    input  logic uart_rx,                   // Receive data line AXI UART
    output logic uart_tx,                   // Transmit data line AXI UART

    // GPIO
    inout  tri   [31:0] pin_gpio
);

    logic rst_n;

    assign rst_n = ~rst;

    // instruction memory
    logic [DATA_WIDTH-1:0]            data_imem_o;
    logic [DATA_WIDTH-1:0]            data_imem_i;
    logic [ADDR_WIDTH-1:0]            imem_addr_cpu;
    logic [ADDR_WIDTH-1:0]            imem_addr_boot;
    logic [ADDR_WIDTH-1:0]            imem_addr_lsu;
    logic [DATA_WIDTH-1:0]            data_imem_lsu;
    logic [ADDR_WIDTH-1:0]            imem_addr_b;
    logic [DATA_WIDTH-1:0]            imem_din_b;
    logic                             imem_we_b;
    logic                             we_i;

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

    localparam int AXI_ADDR_WIDTH = 32;
    localparam int AXI_NUM_SLAVES = 3;
    localparam logic [AXI_ADDR_WIDTH-1:0] GPIO_BASE = 32'h0000_0000;
    localparam logic [AXI_ADDR_WIDTH-1:0] GPIO_MASK = 32'h0000_0FFF;
    localparam logic [AXI_ADDR_WIDTH-1:0] REG_BASE  = 32'h0000_1000;
    localparam logic [AXI_ADDR_WIDTH-1:0] REG_MASK  = 32'h0000_0FFF;
    localparam logic [AXI_ADDR_WIDTH-1:0] UART_BASE = 32'h0000_2000;
    localparam logic [AXI_ADDR_WIDTH-1:0] UART_MASK = 32'h0000_0FFF;

    // AXI4-Lite SLAVE INTERFACE arrays (crossbar -> peripherals)
    logic [AXI_ADDR_WIDTH-1:0] awaddr_s [AXI_NUM_SLAVES-1:0];
    logic [2:0]                awprot_s [AXI_NUM_SLAVES-1:0];
    logic                      awvalid_s[AXI_NUM_SLAVES-1:0];
    logic                      awready_s[AXI_NUM_SLAVES-1:0];
    logic [DATA_WIDTH-1:0]     wdata_s  [AXI_NUM_SLAVES-1:0];
    logic [DATA_WIDTH/8-1:0]   wstrb_s  [AXI_NUM_SLAVES-1:0];
    logic                      wvalid_s [AXI_NUM_SLAVES-1:0];
    logic                      wready_s [AXI_NUM_SLAVES-1:0];
    logic [1:0]                bresp_s  [AXI_NUM_SLAVES-1:0];
    logic                      bvalid_s [AXI_NUM_SLAVES-1:0];
    logic                      bready_s [AXI_NUM_SLAVES-1:0];
    logic [AXI_ADDR_WIDTH-1:0] araddr_s [AXI_NUM_SLAVES-1:0];
    logic [2:0]                arprot_s [AXI_NUM_SLAVES-1:0];
    logic                      arvalid_s[AXI_NUM_SLAVES-1:0];
    logic                      arready_s[AXI_NUM_SLAVES-1:0];
    logic [DATA_WIDTH-1:0]     rdata_s  [AXI_NUM_SLAVES-1:0];
    logic [1:0]                rresp_s  [AXI_NUM_SLAVES-1:0];
    logic                      rvalid_s [AXI_NUM_SLAVES-1:0];
    logic                      rready_s [AXI_NUM_SLAVES-1:0];

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

    // LSU Interconnect
    lsu_interconnect #(
        .ADDR_DMEM_WIDTH(ADDR_WIDTH),
        .DMEM_BASE(DMEM_BASE),
        .IMEM_BASE(32'h2000_0000)
    ) lsu_ic (
        .clk(clk),
        .nrst(rst_n),

        // DMEM INTERFACE
        .we_dmem(wena_mem_d),
        .wstrb_dmem(store_strb),
        .addr_dmem(dmem_addr_cpu),
        .din_dmem(store_wdata),
        .dout_dmem(data_dmem_o),

        // IMEM READ-ONLY INTERFACE
        .addr_imem(imem_addr_lsu),
        .dout_imem(data_imem_lsu),

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

    // AXI4-Lite crossbar (master from LSU -> MMIO slaves)
    axi_lite_crossbar #(
        .ADDR_WIDTH(AXI_ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .NUM_SLAVES(AXI_NUM_SLAVES),
        .SLAVE_MAP('{
            '{base: GPIO_BASE, mask: GPIO_MASK},
            '{base: REG_BASE,  mask: REG_MASK},
            '{base: UART_BASE, mask: UART_MASK}
        })
    ) axi_xbar (
        .clk(clk),
        .nrst(rst_n),

        // Master Interface
        .awaddr_m(awaddr),
        .awprot_m(awprot),
        .awvalid_m(awvalid),
        .awready_m(awready),

        .wdata_m(wdata),
        .wstrb_m(wstrb),
        .wvalid_m(wvalid),
        .wready_m(wready),

        .bresp_m(bresp),
        .bvalid_m(bvalid),
        .bready_m(bready),

        .araddr_m(araddr),
        .arprot_m(arprot),
        .arvalid_m(arvalid),
        .arready_m(arready),

        .rdata_m(rdata),
        .rresp_m(rresp),
        .rvalid_m(rvalid),
        .rready_m(rready),

        // Slave Interfaces
        .awaddr_s(awaddr_s),
        .awprot_s(awprot_s),
        .awvalid_s(awvalid_s),
        .awready_s(awready_s),

        .wdata_s(wdata_s),
        .wstrb_s(wstrb_s),
        .wvalid_s(wvalid_s),
        .wready_s(wready_s),

        .bresp_s(bresp_s),
        .bvalid_s(bvalid_s),
        .bready_s(bready_s),

        .araddr_s(araddr_s),
        .arprot_s(arprot_s),
        .arvalid_s(arvalid_s),
        .arready_s(arready_s),

        .rdata_s(rdata_s),
        .rresp_s(rresp_s),
        .rvalid_s(rvalid_s),
        .rready_s(rready_s)
    );

    // AXI4-Lite GPIO peripheral
    axi_gpio #(
        .NGPIO(32),
        .ADDR_WIDTH(AXI_ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) axi_gpio_i (
        .clk(clk),
        .nrst(rst_n),

        // AXI4-Lite SLAVE (crossbar slave 0)
        .awaddr(awaddr_s[0]),
        .awprot(awprot_s[0]),
        .awvalid(awvalid_s[0]),
        .awready(awready_s[0]),

        .wdata(wdata_s[0]),
        .wstrb(wstrb_s[0]),
        .wvalid(wvalid_s[0]),
        .wready(wready_s[0]),

        .bresp(bresp_s[0]),
        .bvalid(bvalid_s[0]),
        .bready(bready_s[0]),

        .araddr(araddr_s[0]),
        .arprot(arprot_s[0]),
        .arvalid(arvalid_s[0]),
        .arready(arready_s[0]),

        .rdata(rdata_s[0]),
        .rresp(rresp_s[0]),
        .rvalid(rvalid_s[0]),
        .rready(rready_s[0]),
        // GPIO
        .pin_gpio(pin_gpio)
    );

    // AXI4-Lite REGs peripheral
    axi_lite_template #(
        .C_ADDR_WIDTH(6),
        .C_DATA_WIDTH(DATA_WIDTH)
    ) regs_peripheral_i (
        .clk(clk),
        .nrst(rst_n),

        // AXI4-Lite SLAVE (crossbar slave 1)
        .awaddr(awaddr_s[1]),
        .awprot(awprot_s[1]),
        .awvalid(awvalid_s[1]),
        .awready(awready_s[1]),

        .wdata(wdata_s[1]),
        .wstrb(wstrb_s[1]),
        .wvalid(wvalid_s[1]),
        .wready(wready_s[1]),

        .bresp(bresp_s[1]),
        .bvalid(bvalid_s[1]),
        .bready(bready_s[1]),

        .araddr(araddr_s[1]),
        .arprot(arprot_s[1]),
        .arvalid(arvalid_s[1]),
        .arready(arready_s[1]),

        .rdata(rdata_s[1]),
        .rresp(rresp_s[1]),
        .rvalid(rvalid_s[1]),
        .rready(rready_s[1])
    );

    // AXI4-Lite UART peripheral
    top_uart #(
        .C_DATA_WIDTH(DATA_WIDTH),
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) uart_peripheral_i (
        .clk(clk),
        .nrst(rst_n),

        // AXI4-Lite SLAVE (crossbar slave 2)
        .awaddr(awaddr_s[2]),
        .awprot({1'b0, awprot_s[2]}),
        .awvalid(awvalid_s[2]),
        .awready(awready_s[2]),

        .wdata(wdata_s[2]),
        .wstrb(wstrb_s[2]),
        .wvalid(wvalid_s[2]),
        .wready(wready_s[2]),

        .bresp(bresp_s[2]),
        .bvalid(bvalid_s[2]),
        .bready(bready_s[2]),

        .araddr(araddr_s[2]),
        .arprot({1'b0, arprot_s[2]}),
        .arvalid(arvalid_s[2]),
        .arready(arready_s[2]),

        .rdata(rdata_s[2]),
        .rresp(rresp_s[2]),
        .rvalid(rvalid_s[2]),
        .rready(rready_s[2]),

        // UART interface
        .rx(uart_rx),
        .tx(uart_tx)
    );

    // Instruction Memory (sync read)
    assign imem_addr_b = (imem_we_b) ? imem_addr_boot : imem_addr_lsu;
    assign imem_din_b  = data_imem_i;
    assign imem_we_b   = we_i;

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
        .we_b(imem_we_b),
        .wstrb_b(imem_we_b ? 4'b1111 : 4'b0000),
        .addr_b(imem_addr_b),
        .din_b(imem_din_b),
        .dout_b(data_imem_lsu)   // LSU read-only window
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
        .wstrb_b('0),
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
