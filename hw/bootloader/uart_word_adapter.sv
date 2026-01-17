module uart_word_adapter #(
    parameter CLK_FREQ = 50_000_000,
    parameter BAUD_RATE = 115200
) (
    input  logic clk,                       // System clock
    input  logic nrst,                      // Active low reset
    input  logic rx,                        // Receive data line
    output logic tx,                        // Transmit data line

    input  logic [31:0] data_send_word,     // 32-bit Data to be transmitted
    output logic [31:0] data_recv_word,     // 32-bit Data received
    input  logic ena_tx_word,               // Enable transmission for word
    output logic tx_done_word,              // Indicates transmission complete for word
    output logic new_rx_word                // Indicates new data received for word

);

    // Internal signals for byte-level UART
    logic [7:0] data_send_byte;
    logic [7:0] data_recv_byte;
    logic ena_tx_byte;
    logic tx_done_byte;
    logic new_rx_byte;

    // Auxiliary signals
    logic [1:0]  byte_count_rx;
    logic [31:0] word_data_rx;
    logic [1:0]  byte_count_tx;
    logic [31:0] word_data_tx;

    logic [1:0] cnt_ram;

    typedef enum logic [1:0] {
        IDLE,
        SENDING,
        DONE
    } state_t;
    state_t state;

    // Instantiate the byte-level UART
    uart #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) uart_inst (
        .clk(clk),
        .nrst(nrst),
        .rx(rx),
        .tx(tx),
        .data_send(data_send_byte),
        .data_recv(data_recv_byte),
        .ena_tx(ena_tx_byte),
        .tx_done(tx_done_byte),
        .error_rx(),            // Unused
        .new_rx(new_rx_byte)
    );

    // Receive logic: Convert 32-bit word to 4 bytes
    always_ff @(posedge clk or negedge nrst) begin
        if (!nrst) begin
            byte_count_rx <= 0;
            word_data_rx <= 0;
            new_rx_word <= 0;
        end else begin
            if (new_rx_byte) begin
                byte_count_rx <= byte_count_rx + 1;
                word_data_rx <= {data_recv_byte, word_data_rx[31:8]};
                if (byte_count_rx == 3 ) begin
                    new_rx_word <= 1;
                end
            end else begin
                new_rx_word <= 0;
            end
        end
    end
    always_comb data_recv_word = word_data_rx;
    
    
    // Transmit logic: Convert 32-bit word to 4 bytes
    always_ff @(posedge clk or negedge nrst) begin
        if (!nrst) begin
            cnt_ram <= 0;
        end else begin
            if (ena_tx_word && state == IDLE) begin
                cnt_ram <= cnt_ram + 1;
            end else begin
                cnt_ram <= 0;
            end
        end
    end
    
    always_ff @(posedge clk or negedge nrst) begin
        if (!nrst) begin
            byte_count_tx <= 0;
            word_data_tx <= 0;
            state <= IDLE;
            ena_tx_byte <= 0;
            data_send_byte <= 0;
            tx_done_word <= 0;
        end else begin
            case (state)
                IDLE: begin
                    tx_done_word <= 0;
                    if (cnt_ram == 2) begin
                        word_data_tx <= data_send_word;
                        byte_count_tx <= 0;
                        state <= SENDING;
                    end
                end
                SENDING: begin
                    ena_tx_byte <= 1;
                    data_send_byte <= word_data_tx[7:0];
                    if (tx_done_byte) begin
                        byte_count_tx <= byte_count_tx + 1;
                        word_data_tx <= {8'b0, word_data_tx[31:8]};
                        if (byte_count_tx == 3) begin
                            state <= DONE;
                        end
                    end
                end
                DONE: begin
                    ena_tx_byte <= 0;
                    tx_done_word <= 1;
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule