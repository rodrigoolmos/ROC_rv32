module tb_bootloader;

    timeunit      1ns;
    timeprecision 1ps;

    parameter int CLK_FREQ = 50_000_000;
    parameter int NANOS_PER_SEC = 1_000_000_000;
    parameter int BAUD_RATE = 115200;

    // Signals
    logic clk;
    logic nrst;
    logic tx;
    logic rx;
    // DMEM bus signals
    logic [9:0]             dmem_b_addr;
    logic [31:0]            dmem_rdata;
    // IMEM bus signals
    logic                   imem_b_we;
    logic [9:0]             imem_b_addr;
    logic [31:0]            imem_b_wdata;

    // IMEM buffer
    logic [31:0] imem_buffer[$];
    logic [31:0] dmem_buffer[$];

    localparam time BIT_TIME = NANOS_PER_SEC / BAUD_RATE;
    localparam int  DMEM_DEPTH = 1024;

    // Instantiate bootloader DUT
    load_store_controller #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE),
        .ADDR_WIDTH(10),
        .DATA_WIDTH(32)
    ) dut (
        .clk(clk),
        .nrst(nrst),
        .tx(tx),
        .rx(rx),
        // DMEM Interface
        .addr_d(dmem_b_addr),
        .dout_d(dmem_rdata),
        // IMEM Interface
        .we_i(imem_b_we),
        .addr_i(imem_b_addr),
        .din_i(imem_b_wdata)
    );

    // Instantiate DMEM model
    mem #(
        .ADDR_WIDTH(10),
        .DATA_WIDTH(32)
    ) dmem_inst (
        .clk(clk),
        .en_a(1),           // Always enabled
        .we_a(0),           // Unused
        .wstrb_a(0),        // Unused
        .addr_a(dmem_b_addr),
        .din_a(0),          // Unused
        .dout_a(dmem_rdata)
    );

    // Instantiate IMEM model
    mem #(
        .ADDR_WIDTH(10),
        .DATA_WIDTH(32)
    ) imem_inst (
        .clk(clk),
        .en_a(1),       // Always enabled
        .we_a(imem_b_we),
        .wstrb_a(4'b1111),
        .addr_a(imem_b_addr),
        .din_a(imem_b_wdata),
        .dout_a()    // Unused
    );

    // UART Send byte task
    task automatic uart_send_byte(input logic [7:0] data);
        @(posedge clk);
        rx = 0; // Start bit
        #(NANOS_PER_SEC / BAUD_RATE); // Wait for 1 bit duration at 115200 baud

        // Send data bits (LSB first)
        for (int i = 0; i < 8; i++) begin
            rx = data[i];
            #(NANOS_PER_SEC / BAUD_RATE); // Wait for 1 bit duration
        end

        rx = 1; // Stop bit
        #(NANOS_PER_SEC / BAUD_RATE); // Wait for stop bit duration
    endtask

    // UART write word32
    task automatic uart_write_word32(input logic [31:0] data);
        for (int i = 0; i < 4; i++) begin
            uart_send_byte(data[i*8 +: 8]);
        end
    endtask

    // UART write to IMEM task
    task automatic uart_write_imem_verify(input logic [14:0] addr, 
                                            input logic [15:0] ndata,
                                            input logic [31:0] data[$]);
        logic [31:0] data_word;
        logic [31:0] header = {1'b1, addr, ndata};
        logic [31:0] sended[$];
        logic [31:0] expected;
        // Send header
        uart_write_word32(header);

        // Send data words
        for (int i = 0; i < ndata; i++) begin
            data_word = data.pop_front();
            sended.push_back(data_word);
            uart_write_word32(data_word);
        end
        // Verify IMEM contents
        for (int i = 0; i < ndata; i++) begin
            expected = sended.pop_front();
            if (imem_inst.mem[addr + i] !== expected) begin
                $error("IMEM verification failed at address %0h: expected %0h, got %0h",
                       addr + i, expected, imem_inst.mem[addr + i]);
            end
        end
    endtask

    task automatic uart_write_imem_no_verify(input logic [14:0] addr,
                                             input logic [15:0] ndata);
        logic [31:0] header = {1'b1, addr, ndata};
        // Send header
        uart_write_word32(header);
        // Send dummy data words without checking memory
        for (int i = 0; i < ndata; i++) begin
            uart_write_word32($urandom);
        end
    endtask

    task automatic wait_dmem_words(input int count, input time timeout);
        time start_time;
        start_time = $time;
        while (dmem_buffer.size() < count) begin
            if (($time - start_time) > timeout) begin
                $fatal(1, "Timeout waiting for %0d DMEM words, got %0d", count, dmem_buffer.size());
            end
            #BIT_TIME;
        end
    endtask

    // UART read from DMEM task
    task automatic uart_read_dmem_verify(input logic [14:0] addr, 
                                  input logic [15:0] ndata);
        logic [31:0] header = {1'b0, addr, ndata};
        logic [31:0] expected;
        logic [31:0] got;
        int prev_size;
        // Send header
        uart_write_word32(header);
        prev_size = dmem_buffer.size();
        if (ndata != 0) begin
            wait_dmem_words(prev_size + ndata, BIT_TIME * (ndata * 40 + 200));
        end else begin
            #(BIT_TIME * 200);
        end
        
        // verify received data
        for (int i = 0; i < ndata; i++) begin
            expected = dmem_inst.mem[addr + i];
            got = dmem_buffer.pop_front();
            if (got !== expected) begin
                $error("DMEM verification failed at address %0h: expected %0h, got %0h",
                       addr + i, expected, got);
            end
        end
    endtask

    // Monitor tx output
    initial begin
        integer i, j;
        logic [7:0]  rx_byte;
        logic [31:0] rx_word;

        forever begin
            rx_word = '0;

            for (j = 0; j < 4; j++) begin
                
                @(negedge tx); // start bit
                #(NANOS_PER_SEC / (2 * BAUD_RATE)); // half bit
                for (i = 0; i < 8; i++) begin
                    #(NANOS_PER_SEC / BAUD_RATE); // 1 bit
                    rx_byte[i] = tx;
                end
                #(NANOS_PER_SEC / (BAUD_RATE)); // stop bit

                rx_word = {rx_byte, rx_word[31:8]};
            end
            dmem_buffer.push_back(rx_word);
        end
    end


    // load DMEM random values
    initial begin
        for (int i = 0; i < 1024; i++) begin
            dmem_inst.mem[i] = i;
        end
    end

    // Clock generation
    initial begin
        clk = 0;
        forever #10 clk = ~clk; // 50 MHz clock
    end

    // Test sequence
    initial begin
        logic [14:0] random_addr;
        logic [14:0] random_ndata;
        logic [31:0] before_word;
        int prev_size;
        nrst = 0;
        rx = 1; // Idle state
        @(posedge clk);
        nrst = 1;
        @(posedge clk);

        // Prepare IMEM data
        for (int i = 0; i < 128; i++) begin
            imem_buffer.push_back(i);
        end

        // Directed tests: boundaries and ndata=0
        uart_write_imem_verify(0, 1, imem_buffer);
        uart_write_imem_verify(DMEM_DEPTH-1, 1, imem_buffer);
        uart_read_dmem_verify(0, 1);
        uart_read_dmem_verify(DMEM_DEPTH-1, 1);

        prev_size = dmem_buffer.size();
        uart_read_dmem_verify(16, 0);
        if (dmem_buffer.size() != prev_size) begin
            $error("DMEM read with ndata=0 should not return data");
        end

        // Out-of-range write should not modify memory
        before_word = imem_inst.mem[DMEM_DEPTH-1];
        uart_write_imem_no_verify(DMEM_DEPTH-1, 2);
        #(BIT_TIME * 200);
        if (imem_inst.mem[DMEM_DEPTH-1] !== before_word) begin
            $error("IMEM out-of-range write modified memory");
        end

        // generate random imem write data (in-range)
        for (int i = 0; i < 16; i++) begin
            random_ndata = $urandom_range(1, 64);
            random_addr = $urandom_range(0, DMEM_DEPTH - random_ndata);
            uart_write_imem_verify(random_addr, random_ndata, imem_buffer);
        end

        // generate random dmem read data (in-range)
        for (int i = 0; i < 16; i++) begin
            random_ndata = $urandom_range(1, 64);
            random_addr = $urandom_range(0, DMEM_DEPTH - random_ndata);
            uart_read_dmem_verify(random_addr, random_ndata);
        end

        for (int i = 0; i < 16; i++) begin
            if ($urandom_range(0, 1)) begin
                random_ndata = $urandom_range(1, 64);
                random_addr = $urandom_range(0, DMEM_DEPTH - random_ndata);
                uart_write_imem_verify(random_addr, random_ndata, imem_buffer);
            end else begin
                random_ndata = $urandom_range(1, 64);
                random_addr = $urandom_range(0, DMEM_DEPTH - random_ndata);
                uart_read_dmem_verify(random_addr, random_ndata);
            end
        end

        $finish;
    end

endmodule
