
module tb_ROC_RV32_program;
	timeunit 1ns;
	timeprecision 1ps;

	logic clk;
	logic rst_n;
	logic rx;
	logic tx;
	logic uart_rx;
	logic uart_tx;
	logic led_status;
	tri [31:0] pin_gpio;

	parameter int CLK_FREQ = 50_000_000;
	parameter int BAUD_RATE = 115200;
	parameter int NANOS_PER_SEC = 1_000_000_000;
	localparam time BIT_TIME = NANOS_PER_SEC / BAUD_RATE;

	soc #(
		.CLK_FREQ(CLK_FREQ),
		.BAUD_RATE(BAUD_RATE)
	) dut (
		.clk(clk),
		.rst(~rst_n),
		.led_status(led_status),
		.rx(rx),
		.tx(tx),
		.uart_rx(uart_rx),
		.uart_tx(uart_tx),
		.pin_gpio(pin_gpio)
	);

	initial clk = 1'b0;
	always #10 clk = ~clk;

	task automatic reset_dut();
		rst_n = 1'b0;
		repeat (5) @(posedge clk);
		rst_n = 1'b1;
		repeat (2) @(posedge clk);
	endtask

	int unsigned cycles;
	int unsigned store_count;
	logic        saw_store_to_word0;
	logic        saw_fail_signature;
	logic [31:0] last_word0_wdata;
	int unsigned stop_addr_word;
	int unsigned max_cycles;
	logic [31:0] stop_wdata;
	bit          use_stop_wdata;
	string imem_path;
	integer fd;
	logic [31:0] imem_image[$];
	string line;
	logic [31:0] dmem_buffer[$];

	task automatic uart_send_byte(input logic [7:0] data);
		@(posedge clk);
		rx = 0;
		#BIT_TIME;
		for (int i = 0; i < 8; i++) begin
			rx = data[i];
			#BIT_TIME;
		end
		rx = 1;
		#BIT_TIME;
	endtask

	task automatic uart_write_word32(input logic [31:0] data);
		for (int i = 0; i < 4; i++) begin
			uart_send_byte(data[i*8 +: 8]);
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

	task automatic bootloader_read_dmem(input logic [14:0] addr,
	                                    input logic [15:0] ndata,
	                                    output logic [31:0] out[$]);
		logic [31:0] header = {1'b0, addr, ndata};
		int prev_size;
		uart_write_word32(header);
		prev_size = dmem_buffer.size();
		if (ndata != 0) begin
			wait_dmem_words(prev_size + ndata, BIT_TIME * (ndata * 40 + 200));
		end
		out.delete();
		for (int i = 0; i < ndata; i++) begin
			out.push_back(dmem_buffer.pop_front());
		end
	endtask

	task automatic bootloader_write_imem(input logic [14:0] addr,
	                                     input logic [15:0] ndata,
	                                     input logic [31:0] data[$]);
		logic [31:0] header = {1'b1, addr, ndata};
		uart_write_word32(header);
		for (int i = 0; i < ndata; i++) begin
			uart_write_word32(data.pop_front());
		end
	endtask

	task automatic load_imem_via_uart();
		int r;
		logic [31:0] word;
		int idx;
		int chunk_len;
		int remaining;
		logic [31:0] chunk[$];

		imem_image.delete();
		fd = $fopen(imem_path, "r");
		if (fd == 0) begin
			$fatal(1, "Failed to open %s", imem_path);
		end
		while (!$feof(fd)) begin
			r = $fscanf(fd, "%h", word);
			if (r == 1) begin
				imem_image.push_back(word);
			end else begin
				void'($fgets(line, fd));
			end
		end
		$fclose(fd);

		if (imem_image.size() == 0) begin
			$fatal(1, "IMEM image is empty");
		end
		if (imem_image.size() > (1<<10)) begin
			$fatal(1, "IMEM image too large: %0d words", imem_image.size());
		end

		idx = 0;
		remaining = imem_image.size();
		while (remaining > 0) begin
			chunk_len = (remaining > 128) ? 128 : remaining;
			chunk.delete();
			for (int i = 0; i < chunk_len; i++) begin
				chunk.push_back(imem_image[idx + i]);
			end
			bootloader_write_imem(idx[14:0], chunk_len[15:0], chunk);
			idx += chunk_len;
			remaining -= chunk_len;
		end
	endtask

	task automatic dump_dmem(input int count);
		logic [31:0] words[$];
		$display("---- DMEM DUMP (word-addressed) ----");
		bootloader_read_dmem(0, count, words);
		for (int i = 0; i < words.size(); i++) begin
			$display("dmem[%0d]=0x%08x", i, words[i]);
		end
		$display("----------------------------------");
	endtask

	// print handler for UART TX
	initial begin
		integer i;
		logic [7:0] tx_byte;

		forever begin
			// esperar línea en idle
			wait (uart_tx == 1'b1);
			// detectar start bit real
			@(negedge uart_tx);
			// muestrear en el centro del start bit
			#(BIT_TIME / 2);

			// muestrear 8 bits de datos
			for (i = 0; i < 8; i++) begin
				#BIT_TIME;
				tx_byte[i] = uart_tx;
			end

			// esperar stop bit
			#BIT_TIME;
			$write("%c", tx_byte);
		end
	end


	// Monitor bootloader UART TX -> capture DMEM words
	initial begin
		integer i, j;
		logic [7:0]  rx_byte;
		logic [31:0] rx_word;

		forever begin
			rx_word = '0;
			for (j = 0; j < 4; j++) begin
				@(negedge tx);
				#(BIT_TIME / 2);
				for (i = 0; i < 8; i++) begin
					#BIT_TIME;
					rx_byte[i] = tx;
				end
				#BIT_TIME;
				rx_word = {rx_byte, rx_word[31:8]};
			end
			dmem_buffer.push_back(rx_word);
		end
	end

	initial begin
		reset_dut();
		rx = 1'b1;
		uart_rx = 1'b1;

		// Stop condition configuration:
		// - default: stop on an exact store of 0xDEADBEEF to dmem[word 0]
		// - optional: stop on an exact store value with +STOP_WDATA=<hex>
		// - optional: change stop address with +STOP_ADDR=<decimal word index>
		// - optional: change timeout with +MAX_CYCLES=<decimal>
		stop_addr_word = 0;
		max_cycles = 5_000_000;
		stop_wdata = 32'hDEAD_BEEF;
		use_stop_wdata = 1'b1;
		void'($value$plusargs("STOP_ADDR=%d", stop_addr_word));
		void'($value$plusargs("MAX_CYCLES=%d", max_cycles));
		if ($value$plusargs("STOP_WDATA=%h", stop_wdata)) begin
			use_stop_wdata = 1'b1;
		end

		// Clear dmem
		for (int i = 0; i < 18; i++) begin
			dut.data_memory.data_memory.mem[i] = 32'h0000_0000;
		end

		// Load program into IMEM through bootloader UART.
		// Note: Questa runs from ./questasim (see run_sim.tcl), so we try paths relative to that.
		imem_path = "sw/imem.dat";
		fd = $fopen(imem_path, "r");
		if (fd == 0) begin
			imem_path = "../sw/imem.dat";
			fd = $fopen(imem_path, "r");
		end
		if (fd == 0) begin
			$fatal(1, "Failed to open sw/imem.dat (tried sw/imem.dat and ../sw/imem.dat)");
		end
		$fclose(fd);
		$display("[TB] Loading IMEM via bootloader from: %s", imem_path);

		load_imem_via_uart();
		#(BIT_TIME * 200);

		reset_dut();


		cycles = 0;
		store_count = 0;
		saw_store_to_word0 = 1'b0;
		saw_fail_signature = 1'b0;
		last_word0_wdata = 32'h0000_0000;

		// Stop when the program signals completion by writing the signature.
		// Override with +STOP_WDATA=... and/or +STOP_ADDR=... if needed.
		while (!saw_store_to_word0 && cycles < max_cycles) begin
			@(posedge clk);
			cycles++;

			if (rst_n && dut.cpu_core.cpu_state == 3'd4) begin
				$display("[WB] pc=0x%08x ir=0x%08x opcode=0x%02x rd=%0d rs1=%0d rs2=%0d", dut.cpu_core.pc_ir, dut.cpu_core.ir, dut.cpu_core.opcode, dut.cpu_core.rd, dut.cpu_core.rs1, dut.cpu_core.rs2);
			end

			if (rst_n && dut.wena_mem_d) begin
				store_count++;
				$display("[STORE] cycle=%0d addr_word=%0d wstrb=0x%0x wdata=0x%08x", cycles, dut.dmem_addr_cpu, dut.store_strb, dut.store_wdata);
				if (dut.dmem_addr_cpu == stop_addr_word) begin
					last_word0_wdata = dut.store_wdata;
					// PASS: exact match of stop_wdata (default 0xDEADBEEF)
					if (use_stop_wdata && (dut.store_strb == 4'hF) && (dut.store_wdata == stop_wdata)) begin
						saw_store_to_word0 = 1'b1;
					end
					// FAIL: 0xBAD0xxxx (code in low 16 bits)
					else if ((dut.store_strb == 4'hF) && ((dut.store_wdata & 32'hFFFF_0000) == 32'hBAD0_0000)) begin
						saw_store_to_word0 = 1'b1;
						saw_fail_signature = 1'b1;
					end
					// Legacy behavior if someone explicitly disables STOP_WDATA handling.
					else if (!use_stop_wdata && (dut.store_wdata != 32'h0000_0000)) begin
						saw_store_to_word0 = 1'b1;
					end
				end
			end
		end

		if (!saw_store_to_word0) begin
			$fatal(1, "Timeout: no stop store observed within %0d cycles. Default is store 0x%08x to dmem[word %0d]. Optional: +STOP_WDATA=<hex>, +STOP_ADDR=<word>, +MAX_CYCLES=<n>.", max_cycles, stop_wdata, stop_addr_word);
		end
		if (saw_fail_signature) begin
			$fatal(1, "FAIL signature observed at dmem[word %0d]: wdata=0x%08x (code=0x%04x)", stop_addr_word, last_word0_wdata, last_word0_wdata[15:0]);
		end else begin
			$display("PASS: SUCCESS signature observed at dmem[word %0d]: wdata=0x%08x", stop_addr_word, last_word0_wdata);
		end

		// dmem is synchronous; allow the write to commit before reading mem[]
		@(posedge clk);

		$display("---- FINAL SNAPSHOT ----");
		$display("cycles=%0d pc_output=0x%08x cpu_state=%0d ir=0x%08x", cycles, dut.cpu_core.pc_output, dut.cpu_core.cpu_state, dut.cpu_core.ir);
		$display("------------------------");

		dump_dmem(10);
		#(2000000);
		dump_dmem(10);

		load_imem_via_uart();
		#(BIT_TIME * 200);

		reset_dut();
		dump_dmem(10);

		$finish;
	end

endmodule
