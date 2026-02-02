typedef struct packed {
    logic [31:0] base;
    logic [31:0] length;
} addr_region_t;

module lsu_interconnect #(
    parameter int unsigned ADDR_DMEM_WIDTH = 10,
    // Base address for data memory (Harvard mapping).
    // All LOAD/STORE addresses are expected to be in [DMEM_BASE, DMEM_BASE + 4*2**ADDR_WIDTH_LSU).
    parameter logic [31:0] DMEM_BASE = 32'h1000_0000,
    // Base address for instruction memory (read-only data window).
    parameter logic [31:0] IMEM_BASE = 32'h2000_0000,

    // DMEM length in bytes (word-addressed depth is 2**ADDR_DMEM_WIDTH).
    parameter logic [31:0] DMEM_LENGTH = (32'h1 << (ADDR_DMEM_WIDTH + 2)),
    // IMEM length in bytes (assume same depth as DMEM unless overridden).
    parameter logic [31:0] IMEM_LENGTH = (32'h1 << (ADDR_DMEM_WIDTH + 2)),
    parameter addr_region_t DMEM_MAP = '{base: DMEM_BASE, length: DMEM_LENGTH},
    parameter addr_region_t MMIO_MAP = '{base: 0, length: 32'h1000_0000}
) (

    input  logic                     clk,
    input  logic                     nrst,

    // DMEM INTERFACE
    output logic                        we_dmem,
    output logic [3:0]                  wstrb_dmem,
    output logic [ADDR_DMEM_WIDTH-1:0]  addr_dmem,
    output logic [31:0]                 din_dmem,
    input  logic [31:0]                 dout_dmem,

    // IMEM READ-ONLY INTERFACE
    output logic [ADDR_DMEM_WIDTH-1:0]  addr_imem,
    input  logic [31:0]                 dout_imem,

    // AXI4-Lite MASTER INTERFACE
    output logic [31:0]              awaddr,
    output logic [2:0]               awprot,
    output logic                     awvalid,
    input  logic                     awready,

    output logic [31:0]              wdata,
    output logic [3:0]               wstrb,
    output logic                     wvalid,
    input  logic                     wready,

    input  logic [1:0]               bresp,
    input  logic                     bvalid,
    output logic                     bready,

    output logic [31:0]              araddr,
    output logic [2:0]               arprot,
    output logic                     arvalid,
    input  logic                     arready,

    input  logic [31:0]              rdata,
    input  logic [1:0]               rresp,
    input  logic                     rvalid,
    output logic                     rready,

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

    typedef enum logic [1:0] {IDLE, SEND, WAIT_B, WAIT_END} state_t;
    state_t st_w, st_r;

    // WRITE CHANNEL SIGNALS
    logic [31:0] lat_waddr, lat_wdata;
    logic [3:0]  lat_wstrb;
    logic aw_done, w_done;

    // READ CHANNEL SIGNALS
    logic [31:0] lat_raddr, lat_rdata;
    logic ar_done, r_done;
    
    // AUXILIARY SIGNALS
    logic rvalid_axi;
    logic wready_axi;

    logic dmem_range, mmio_range;
    logic imem_range;
    logic [31:0] imem_byte_addr;

    assign dmem_range = (addr_lsu >= DMEM_MAP.base) && (addr_lsu < (DMEM_MAP.base + DMEM_MAP.length));
    assign imem_range = (addr_lsu >= IMEM_BASE) && (addr_lsu < (IMEM_BASE + IMEM_LENGTH));
    assign mmio_range = (addr_lsu >= MMIO_MAP.base) && (addr_lsu < (MMIO_MAP.base + MMIO_MAP.length));

    always_comb begin
        lsu_byte_addr = addr_lsu - DMEM_BASE;
        imem_byte_addr = addr_lsu - IMEM_BASE;
        // ADDR IN DMEM RANGE
        if (dmem_range) begin
            // CONNECT TO DMEM INTERFACE
            we_dmem      = wvalid_lsu;
            wstrb_dmem   = strb_lsu;
            addr_dmem    = lsu_byte_addr[ADDR_DMEM_WIDTH+1:2];
            din_dmem     = data_lsu_i;
            data_lsu_o   = dout_dmem;
            // DMEM dont implement ready/valid handshake
            rvalid_lsu   = 1;
            wready_lsu   = 1;
            addr_imem    = '0;
        // ADDR IN IMEM RANGE (READ-ONLY)
        end else if (imem_range) begin
            we_dmem      = 0;
            wstrb_dmem   = 0;
            addr_dmem    = 0;
            din_dmem     = 0;
            addr_imem    = imem_byte_addr[ADDR_DMEM_WIDTH+1:2];
            data_lsu_o   = dout_imem;
            rvalid_lsu   = 1;
            wready_lsu   = 0;
        // ADDR IN MMIO RANGE
        end else if (mmio_range) begin
            // CONNECT TO AXI INTERFACE
            we_dmem      = 0;
            wstrb_dmem   = 0;
            addr_dmem    = 0;
            din_dmem     = 0;
            addr_imem    = '0;
            data_lsu_o   = lat_rdata;
            rvalid_lsu   = rvalid_axi;
            wready_lsu   = wready_axi;
        // ADDR OUT OF RANGE
        end else begin
            // DISCONNECT DMEM INTERFACE
            we_dmem      = 0;
            wstrb_dmem   = 0;
            addr_dmem    = 0;
            din_dmem     = 0;
            addr_imem    = '0;
            data_lsu_o   = 32'hDEAD_BEEF;
            rvalid_lsu   = 0;
            wready_lsu   = 0;
        end
    end

    // AXI WRITE FSM
    always_ff @(posedge clk or negedge nrst) begin
        if (!nrst) begin
            st_w     <= IDLE;
            aw_done <= 0;
            w_done  <= 0;
            wready_axi <= 0;
            lat_waddr <= 0;
            lat_wdata <= 0;
            lat_wstrb <= 0;
        end else begin
            case (st_w)

            IDLE: begin
                aw_done <= 0;
                w_done  <= 0;
                wready_axi <= 0;

                if (wvalid_lsu & mmio_range) begin
                    lat_waddr  <= addr_lsu;
                    lat_wdata <= data_lsu_i;
                    lat_wstrb <= strb_lsu;
                    st_w        <= SEND;
                end
            end

            SEND: begin
                if (awvalid && awready) aw_done <= 1;
                if (wvalid  && wready)  w_done  <= 1;

                if (aw_done && w_done) begin
                    st_w <= WAIT_B;
                end
            end

            WAIT_B: begin
                if (bvalid && bready) begin
                    st_w <= WAIT_END;
                    wready_axi <= 1;
                end
            end

            WAIT_END: begin
                if (wready_lsu && wvalid_lsu) begin
                    st_w <= IDLE;
                end
            end

            endcase
        end
    end

    // AXI: WRITE ADDRESS & WRITE DATA CHANNELS
    assign awvalid = (st_w == SEND) && !aw_done;
    assign wvalid  = (st_w == SEND) && !w_done;
    assign awaddr  = lat_waddr;
    assign wdata   = lat_wdata;
    assign wstrb   = lat_wstrb;
    assign bready  = (st_w == WAIT_B);


    // AXI READ FSM
    always_ff @(posedge clk or negedge nrst) begin
        if (!nrst) begin
            st_r     <= IDLE;
            ar_done <= 0;
            r_done  <= 0;
            rvalid_axi <= 0;
            lat_rdata <= 0;
            lat_raddr <= 0;
        end else begin
            case (st_r)
            IDLE: begin
                ar_done <= 0;
                r_done  <= 0;
                rvalid_axi <= 0;

                if (rready_lsu & mmio_range) begin
                    lat_raddr  <= addr_lsu;
                    st_r        <= SEND;
                end
            end

            SEND: begin
                if (arvalid && arready) ar_done <= 1;
                if (rvalid  && rready) begin
                    lat_rdata <= rdata;
                    r_done  <= 1;
                end 

                if (ar_done && r_done) begin
                    st_r <= WAIT_END;
                    rvalid_axi <= 1;
                end
            end

            WAIT_END: begin
                if (rvalid_lsu && rready_lsu) begin
                    st_r <= IDLE;
                end
            end

            endcase
        end
    end

    // AXI: READ ADDRESS & READ DATA CHANNELS
    assign arvalid = (st_r == SEND) && !ar_done;
    assign rready  = (st_r == SEND) && !r_done;
    assign araddr  = lat_raddr;
    
    assign arprot  = 3'b000;
    assign awprot  = 3'b000;

endmodule
