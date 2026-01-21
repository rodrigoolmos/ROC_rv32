onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -expand -group ls_cntr /tb_bootloader/dut/clk
add wave -noupdate -expand -group ls_cntr /tb_bootloader/dut/nrst
add wave -noupdate -expand -group ls_cntr /tb_bootloader/dut/rx
add wave -noupdate -expand -group ls_cntr /tb_bootloader/dut/tx
add wave -noupdate -expand -group ls_cntr /tb_bootloader/dut/en_d
add wave -noupdate -expand -group ls_cntr /tb_bootloader/dut/addr_d
add wave -noupdate -expand -group ls_cntr /tb_bootloader/dut/dout_d
add wave -noupdate -expand -group ls_cntr /tb_bootloader/dut/en_i
add wave -noupdate -expand -group ls_cntr /tb_bootloader/dut/we_i
add wave -noupdate -expand -group ls_cntr /tb_bootloader/dut/wstrb_i
add wave -noupdate -expand -group ls_cntr /tb_bootloader/dut/addr_i
add wave -noupdate -expand -group ls_cntr /tb_bootloader/dut/din_i
add wave -noupdate -expand -group ls_cntr /tb_bootloader/dut/ena_tx_word
add wave -noupdate -expand -group ls_cntr /tb_bootloader/dut/tx_done_word
add wave -noupdate -expand -group ls_cntr /tb_bootloader/dut/new_rx_word
add wave -noupdate -expand -group ls_cntr /tb_bootloader/dut/data_send_word
add wave -noupdate -expand -group ls_cntr /tb_bootloader/dut/data_recv_word
add wave -noupdate -expand -group ls_cntr /tb_bootloader/dut/cnt_data
add wave -noupdate -expand -group ls_cntr /tb_bootloader/dut/num_data
add wave -noupdate -expand -group ls_cntr /tb_bootloader/dut/addr_pos
add wave -noupdate -expand -group ls_cntr /tb_bootloader/dut/state
add wave -noupdate -expand -group adap /tb_bootloader/dut/uart_adapter_inst/clk
add wave -noupdate -expand -group adap /tb_bootloader/dut/uart_adapter_inst/nrst
add wave -noupdate -expand -group adap /tb_bootloader/dut/uart_adapter_inst/rx
add wave -noupdate -expand -group adap /tb_bootloader/dut/uart_adapter_inst/tx
add wave -noupdate -expand -group adap /tb_bootloader/dut/uart_adapter_inst/data_send_word
add wave -noupdate -expand -group adap /tb_bootloader/dut/uart_adapter_inst/data_recv_word
add wave -noupdate -expand -group adap /tb_bootloader/dut/uart_adapter_inst/ena_tx_word
add wave -noupdate -expand -group adap /tb_bootloader/dut/uart_adapter_inst/tx_done_word
add wave -noupdate -expand -group adap /tb_bootloader/dut/uart_adapter_inst/new_rx_word
add wave -noupdate -expand -group adap /tb_bootloader/dut/uart_adapter_inst/data_send_byte
add wave -noupdate -expand -group adap /tb_bootloader/dut/uart_adapter_inst/data_recv_byte
add wave -noupdate -expand -group adap /tb_bootloader/dut/uart_adapter_inst/ena_tx_byte
add wave -noupdate -expand -group adap /tb_bootloader/dut/uart_adapter_inst/tx_done_byte
add wave -noupdate -expand -group adap /tb_bootloader/dut/uart_adapter_inst/new_rx_byte
add wave -noupdate -expand -group adap /tb_bootloader/dut/uart_adapter_inst/byte_count_rx
add wave -noupdate -expand -group adap /tb_bootloader/dut/uart_adapter_inst/word_data_rx
add wave -noupdate -expand -group adap /tb_bootloader/dut/uart_adapter_inst/byte_count_tx
add wave -noupdate -expand -group adap /tb_bootloader/dut/uart_adapter_inst/word_data_tx
add wave -noupdate -expand -group adap /tb_bootloader/dut/uart_adapter_inst/state
add wave -noupdate -expand -group uart /tb_bootloader/dut/uart_adapter_inst/uart_inst/clk
add wave -noupdate -expand -group uart /tb_bootloader/dut/uart_adapter_inst/uart_inst/nrst
add wave -noupdate -expand -group uart /tb_bootloader/dut/uart_adapter_inst/uart_inst/rx
add wave -noupdate -expand -group uart /tb_bootloader/dut/uart_adapter_inst/uart_inst/tx
add wave -noupdate -expand -group uart /tb_bootloader/dut/uart_adapter_inst/uart_inst/data_send
add wave -noupdate -expand -group uart /tb_bootloader/dut/uart_adapter_inst/uart_inst/data_recv
add wave -noupdate -expand -group uart /tb_bootloader/dut/uart_adapter_inst/uart_inst/ena_tx
add wave -noupdate -expand -group uart /tb_bootloader/dut/uart_adapter_inst/uart_inst/tx_done
add wave -noupdate -expand -group uart /tb_bootloader/dut/uart_adapter_inst/uart_inst/error_rx
add wave -noupdate -expand -group uart /tb_bootloader/dut/uart_adapter_inst/uart_inst/new_rx
add wave -noupdate -expand -group uart /tb_bootloader/dut/uart_adapter_inst/uart_inst/sample_rx
add wave -noupdate -expand -group uart /tb_bootloader/dut/uart_adapter_inst/uart_inst/tx_state
add wave -noupdate -expand -group uart /tb_bootloader/dut/uart_adapter_inst/uart_inst/rx_state
add wave -noupdate -expand -group uart /tb_bootloader/dut/uart_adapter_inst/uart_inst/tx_bit_cnt
add wave -noupdate -expand -group uart /tb_bootloader/dut/uart_adapter_inst/uart_inst/rx_bit_cnt
add wave -noupdate -expand -group uart /tb_bootloader/dut/uart_adapter_inst/uart_inst/rx_ff
add wave -noupdate -expand -group uart /tb_bootloader/dut/uart_adapter_inst/uart_inst/data_send_reg
add wave -noupdate -expand -group uart /tb_bootloader/dut/uart_adapter_inst/uart_inst/clk_div1
add wave -noupdate -expand -group uart /tb_bootloader/dut/uart_adapter_inst/uart_inst/clk_div2
add wave -noupdate -expand -group uart /tb_bootloader/dut/uart_adapter_inst/uart_inst/tick_tx
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {342990000 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 150
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ps
update
WaveRestoreZoom {342227824 ps} {343792176 ps}
