module load_store_controller #(
    parameter CLK_FREQ = 50_000_000,
    parameter BAUD_RATE = 115200,
    parameter int ADDR_WIDTH = 10,
    parameter int DATA_WIDTH = 32
) (
    input  logic clk,                       // System clock
    input  logic nrst,                      // Active low reset
    input  logic rx,                        // Receive data line
    output logic tx,                        // Transmit data line

    // DMEM Interface
    output logic [ADDR_WIDTH-1:0]    addr_d,
    input  logic [DATA_WIDTH-1:0]    dout_d,

    // IMEM Interface
    output logic                     we_i,
    output logic [ADDR_WIDTH-1:0]    addr_i,
    output logic [DATA_WIDTH-1:0]    din_i
);

    parameter logic WRITE   = 1;
    parameter logic READ    = 0;
    parameter int POS_NDATA = 15;   // 15 down to 0 (16 bits total)
    parameter int POS_ADDR  = 30;   // 30 down to 16 (15 bits total)
    parameter int POS_TYPE  = 31;

    //Auxiliary signals
    logic ena_tx_word;
    logic tx_done_word;
    logic new_rx_word;
    logic [DATA_WIDTH-1:0] data_send_word;
    logic [DATA_WIDTH-1:0] data_recv_word;
    logic [15:0] cnt_data;
    logic [15:0] num_data;
    logic [14:0] addr_pos;
    logic [15:0] header_num_data;
    logic [16:0] final_addr;
    logic [14:0] header_addr;
    logic        header_addr_oob;

    typedef enum logic [2:0] {
        IDLE,
        HEADER,
        DATA_W,
        DATA_R,
        DROP
    } state_t;
    state_t state;    

    // Instantiate UART word adapter
    uart_word_adapter #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) uart_adapter_inst (
        .clk(clk),
        .nrst(nrst),
        .rx(rx),
        .tx(tx),
        .data_send_word(data_send_word),
        .data_recv_word(data_recv_word),
        .ena_tx_word(ena_tx_word),
        .tx_done_word(tx_done_word),
        .new_rx_word(new_rx_word)
    );

    assign header_num_data = data_recv_word[POS_NDATA : 0];
    assign header_addr = data_recv_word[POS_ADDR : POS_NDATA+1];
    assign final_addr = header_addr + header_num_data - 1;
    assign header_addr_oob = final_addr[16:ADDR_WIDTH] != '0;

    // State machine for load/store operations
    always_ff @(posedge clk or negedge nrst) begin
        if (!nrst) begin
            state <= IDLE;
            cnt_data <= 0;
            addr_pos <= 0;
            num_data <= 0;
            ena_tx_word <= 0;
        end else begin
            case (state)
                IDLE: begin
                    cnt_data <= 0;
                    addr_pos <= 0;
                    num_data <= 0;
                    ena_tx_word <= 0;
                    if (new_rx_word) begin
                        state <= HEADER;
                    end
                end
                HEADER: begin
                    addr_pos <= header_addr;
                    num_data <= header_num_data;
                    cnt_data <= 0;
                    // Not valid header, go to IDLE
                    if (header_num_data == 0) begin
                        state <= IDLE;
                    // Out of bounds address
                    end else if (header_addr_oob) begin
                        state <= DROP;
                    end else if (data_recv_word[POS_TYPE] == WRITE) begin
                        state <= DATA_W;
                    end else begin
                        state <= DATA_R;
                    end
                end

                // Read data from DMEM and send via UART
                DATA_R: begin
                    ena_tx_word <= 1;
                    if (tx_done_word) begin
                        cnt_data <= cnt_data + 1;
                        if (cnt_data == num_data - 1) begin
                            ena_tx_word <= 0;
                            state <= IDLE;
                        end
                    end
                end

                // Write data to IMEM received via UART (program core)
                DATA_W: begin
                    if (new_rx_word) begin
                        cnt_data <= cnt_data + 1;
                        if (cnt_data == num_data - 1) begin
                            state <= IDLE;
                        end
                    end
                end
                // Drop incoming data when out of bounds
                DROP: begin
                    if (new_rx_word) begin
                        cnt_data <= cnt_data + 1;
                        if (cnt_data == num_data - 1) begin
                            state <= IDLE;
                        end
                    end
                end

            endcase
        end
    end

    // Address calculation
    always_comb begin
        we_i = state == DATA_W ? new_rx_word : 1'b0; // Write enable for IMEM
        din_i = data_recv_word; // Data to write to IMEM
        data_send_word = dout_d; // Read data from DMEM
        addr_d = addr_pos + cnt_data;
        addr_i = addr_pos + cnt_data;
    end

    
endmodule
