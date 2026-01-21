module bram #(
  parameter int ADDR_WIDTH = 10,
  parameter int DATA_WIDTH = 32
)(
  input  logic                      clk,

  input  logic                      en_a,
  input  logic                      we_a,
  input  logic [(DATA_WIDTH/8)-1:0] wstrb_a,
  input  logic [ADDR_WIDTH-1:0]     addr_a,
  input  logic [DATA_WIDTH-1:0]     din_a,
  output logic [DATA_WIDTH-1:0]     dout_a,

  input  logic                      en_b,
  input  logic                      we_b,
  input  logic [(DATA_WIDTH/8)-1:0] wstrb_b,
  input  logic [ADDR_WIDTH-1:0]     addr_b,
  input  logic [DATA_WIDTH-1:0]     din_b,
  output logic [DATA_WIDTH-1:0]     dout_b
);

  (* ram_style="block" *) logic [DATA_WIDTH-1:0] mem [0:(1<<ADDR_WIDTH)-1];

  // Port A
  always_ff @(posedge clk) begin
    if (en_a) begin
      if (we_a) begin
        for (int i = 0; i < DATA_WIDTH/8; i++)
          if (wstrb_a[i]) mem[addr_a][8*i +: 8] <= din_a[8*i +: 8];
      end
      dout_a <= mem[addr_a]; // 1-cycle sync read
    end
  end

  // Port B
  always_ff @(posedge clk) begin
    if (en_b) begin
      if (we_b) begin
        for (int i = 0; i < DATA_WIDTH/8; i++)
          if (wstrb_b[i]) mem[addr_b][8*i +: 8] <= din_b[8*i +: 8];
      end
      dout_b <= mem[addr_b];
    end
  end

endmodule
