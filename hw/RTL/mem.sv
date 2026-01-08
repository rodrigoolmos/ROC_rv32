module bram #(
    parameter int ADDR_WIDTH = 10,
    parameter int DATA_WIDTH = 32
)(
    input  logic                     clk,

    // Port A
    input  logic                     en_a,
    input  logic                     we_a,
    input  logic [(DATA_WIDTH/8)-1:0] wstrb_a,
    input  logic [ADDR_WIDTH-1:0]    addr_a,
    input  logic [DATA_WIDTH-1:0]    din_a,
    output logic [DATA_WIDTH-1:0]    dout_a,

    // Port B (true dual-port)
    input  logic                     en_b,
    input  logic                     we_b,
    input  logic [(DATA_WIDTH/8)-1:0] wstrb_b,
    input  logic [ADDR_WIDTH-1:0]    addr_b,
    input  logic [DATA_WIDTH-1:0]    din_b,
    output logic [DATA_WIDTH-1:0]    dout_b
);

    // True dual-port RAM model with byte write enables on both ports.
    // If both ports write the same address/byte in the same cycle, Port B wins.
    (* ram_style = "block" *) logic [DATA_WIDTH-1:0] mem [0:(1<<ADDR_WIDTH)-1];

    always_ff @(posedge clk) begin
        // Writes
        if (en_a && we_a) begin
            for (int i = 0; i < (DATA_WIDTH/8); i++) begin
                if (wstrb_a[i]) begin
                    mem[addr_a][8*i +: 8] <= din_a[8*i +: 8];
                end
            end
        end

        if (en_b && we_b) begin
            for (int i = 0; i < (DATA_WIDTH/8); i++) begin
                if (wstrb_b[i]) begin
                    mem[addr_b][8*i +: 8] <= din_b[8*i +: 8];
                end
            end
        end

        // Synchronous reads (read-old on write due to nonblocking semantics)
        if (en_a) begin
            dout_a <= mem[addr_a];
        end
        if (en_b) begin
            dout_b <= mem[addr_b];
        end
    end

endmodule
