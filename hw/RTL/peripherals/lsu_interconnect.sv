typedef struct packed {
    logic [31:0] base;
    logic [31:0] length;
} addr_region_t;

module lsu_interconnect #(
    parameter int unsigned ADDR_DMEM_WIDTH = 10,
    // Base address for data memory (Harvard mapping).
    // All LOAD/STORE addresses are expected to be in [DMEM_BASE, DMEM_BASE + 4*2**ADDR_WIDTH_LSU).
    parameter logic [31:0] DMEM_BASE = 32'h1000_0000,

    // DMEM length in bytes (word-addressed depth is 2**ADDR_DMEM_WIDTH).
    parameter logic [31:0] DMEM_LENGTH = (32'h1 << (ADDR_DMEM_WIDTH + 2)),
    parameter addr_region_t DMEM_MAP = '{base: DMEM_BASE, length: DMEM_LENGTH}
) (

    input  logic                     clk,
    input  logic                     nrst,

    // DMEM INTERFACE
    output logic                        we_dmem,
    output logic [3:0]                  wstrb_dmem,
    output logic [ADDR_DMEM_WIDTH-1:0]  addr_dmem,
    output logic [31:0]                 din_dmem,
    input  logic [31:0]                 dout_dmem,

    // CPU INTERFACE
    input  logic                    rready_lsu,
    output logic                    rvalid_lsu,
    output logic                    wready_lsu,
    input  logic                    wvalid_lsu,
    input  logic [3:0]              strb_lsu,
    input  logic [31:0]             addr_lsu,
    input  logic [31:0]             data_lsu_i,
    output logic [31:0]             data_lsu_o
);

    logic [31:0] lsu_byte_addr;
    
    always_comb begin
        lsu_byte_addr = addr_lsu - DMEM_BASE;
        // ADDR IN DMEM RANGE
        if ( (addr_lsu >= DMEM_MAP.base) && (addr_lsu < (DMEM_MAP.base + DMEM_MAP.length)) ) begin
            // CONNECT TO DMEM INTERFACE
            we_dmem      = wvalid_lsu;
            wstrb_dmem   = strb_lsu;
            addr_dmem    = lsu_byte_addr[ADDR_DMEM_WIDTH+1:2];
            din_dmem     = data_lsu_i;
            data_lsu_o   = dout_dmem;
            // DMEM dont implement ready/valid handshake
            rvalid_lsu   = 1'b1;
            wready_lsu   = 1'b1;
        end else begin
            // INVALID ADDRESS
            we_dmem      = 1'b0;
            wstrb_dmem   = '0;
            addr_dmem    = '0;
            din_dmem     = '0;
            data_lsu_o   = 32'hDEAD_BEEF;
            rvalid_lsu   = 1'b0;
            wready_lsu   = 1'b0;
        end
    end

    
endmodule



    // AXI4-Lite MASTER INTERFACE
    // output logic [31:0]              awaddr,
    // output logic [3:0]               awprot,
    // output logic                     awvalid,
    // input  logic                     awready,

    // output logic [31:0]              wdata,
    // output logic [3:0]               wstrb,
    // output logic                     wvalid,
    // input  logic                     wready,

    // input  logic [1:0]               bresp,
    // input  logic                     bvalid,
    // output logic                     bready,

    // output logic [31:0]              araddr,
    // output logic [3:0]               arprot,
    // output logic                     arvalid,
    // input  logic                     arready,

    // input  logic [31:0]              rdata,
    // input  logic [1:0]               rresp,
    // input  logic                     rvalid,
    // output logic                     rready,
