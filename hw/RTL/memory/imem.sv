module imem #(
    parameter int ADDR_WIDTH = 10,
    parameter int DATA_WIDTH = 32
)(
    input  logic                     clk,
    // Port A (core)
    input  logic                     en_a,
    input  logic                     we_a,
    input  logic [ADDR_WIDTH-1:0]    addr_a,
    input  logic [DATA_WIDTH-1:0]    din_a,
    output logic [DATA_WIDTH-1:0]    dout_a,

    // Port B (debug/DMA)
    input  logic                     en_b,
    input  logic                     we_b,
    input  logic [(DATA_WIDTH/8)-1:0] wstrb_b,
    input  logic [ADDR_WIDTH-1:0]    addr_b,
    input  logic [DATA_WIDTH-1:0]    din_b,
    output logic [DATA_WIDTH-1:0]    dout_b
);

    bram #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) data_memory (
        .clk(clk),
        .en_a(en_a),
        .we_a(we_a),
        .wstrb_a(0),
        .addr_a(addr_a),
        .din_a(din_a),
        .dout_a(dout_a),
        .en_b(en_b),
        .we_b(we_b),
        .wstrb_b(wstrb_b),
        .addr_b(addr_b),
        .din_b(din_b),
        .dout_b(dout_b)
    );

endmodule
