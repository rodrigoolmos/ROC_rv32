module register_bank(
    input logic         clk,
    input logic         rst_n,
    input logic [4:0]   rs1,
    input logic [4:0]   rs2,
    input logic [4:0]   rd,
    input logic [31:0]  di,
    input logic         we,
    output logic [31:0] do1,
    output logic [31:0] do2

);

    // 32 registers of 32 bits each
    logic [31:0] registers [31:0];

    // Read operations (combinational)
    // Register x0 is always 0
    always_comb begin
        do1 = (rs1 != 0) ? registers[rs1] : 32'b0;
        do2 = (rs2 != 0) ? registers[rs2] : 32'b0;
    end

    // Write operation (sequential)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < 32; i++) begin
                registers[i] <= 32'b0;
            end
        end else if (we && (rd != 0)) begin
            registers[rd] <= di;
        end
    end
    
endmodule