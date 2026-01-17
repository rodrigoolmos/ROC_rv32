onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -expand -group SoC /tb_ROC_RV32_program/dut/clk
add wave -noupdate -expand -group SoC /tb_ROC_RV32_program/dut/rst_n
add wave -noupdate -expand -group SoC /tb_ROC_RV32_program/dut/rx
add wave -noupdate -expand -group SoC /tb_ROC_RV32_program/dut/tx
add wave -noupdate -expand -group SoC /tb_ROC_RV32_program/dut/data_imem_o
add wave -noupdate -expand -group SoC /tb_ROC_RV32_program/dut/data_imem_i
add wave -noupdate -expand -group SoC /tb_ROC_RV32_program/dut/imem_addr_cpu
add wave -noupdate -expand -group SoC /tb_ROC_RV32_program/dut/imem_addr_boot
add wave -noupdate -expand -group SoC /tb_ROC_RV32_program/dut/we_i
add wave -noupdate -expand -group SoC /tb_ROC_RV32_program/dut/wena_mem_d
add wave -noupdate -expand -group SoC /tb_ROC_RV32_program/dut/dmem_addr_cpu
add wave -noupdate -expand -group SoC /tb_ROC_RV32_program/dut/dmem_addr_boot
add wave -noupdate -expand -group SoC /tb_ROC_RV32_program/dut/store_wdata
add wave -noupdate -expand -group SoC /tb_ROC_RV32_program/dut/data_dmem_o
add wave -noupdate -expand -group SoC /tb_ROC_RV32_program/dut/data_dmem_boot_o
add wave -noupdate -expand -group SoC /tb_ROC_RV32_program/dut/store_strb
add wave -noupdate -group CPU /tb_ROC_RV32_program/dut/cpu_core/clk
add wave -noupdate -group CPU /tb_ROC_RV32_program/dut/cpu_core/rst_n
add wave -noupdate -group CPU /tb_ROC_RV32_program/dut/cpu_core/data_imem
add wave -noupdate -group CPU /tb_ROC_RV32_program/dut/cpu_core/imem_addr
add wave -noupdate -group CPU /tb_ROC_RV32_program/dut/cpu_core/wena_mem
add wave -noupdate -group CPU /tb_ROC_RV32_program/dut/cpu_core/store_strb
add wave -noupdate -group CPU /tb_ROC_RV32_program/dut/cpu_core/dmem_addr
add wave -noupdate -group CPU /tb_ROC_RV32_program/dut/cpu_core/store_wdata
add wave -noupdate -group CPU /tb_ROC_RV32_program/dut/cpu_core/data_dmem_o
add wave -noupdate -group CPU /tb_ROC_RV32_program/dut/cpu_core/ir
add wave -noupdate -group CPU /tb_ROC_RV32_program/dut/cpu_core/op1
add wave -noupdate -group CPU /tb_ROC_RV32_program/dut/cpu_core/op2
add wave -noupdate -group CPU /tb_ROC_RV32_program/dut/cpu_core/op_type
add wave -noupdate -group CPU /tb_ROC_RV32_program/dut/cpu_core/result
add wave -noupdate -group CPU /tb_ROC_RV32_program/dut/cpu_core/rs1
add wave -noupdate -group CPU /tb_ROC_RV32_program/dut/cpu_core/rs2
add wave -noupdate -group CPU /tb_ROC_RV32_program/dut/cpu_core/rd
add wave -noupdate -group CPU /tb_ROC_RV32_program/dut/cpu_core/opcode
add wave -noupdate -group CPU /tb_ROC_RV32_program/dut/cpu_core/funct3
add wave -noupdate -group CPU /tb_ROC_RV32_program/dut/cpu_core/funct7
add wave -noupdate -group CPU /tb_ROC_RV32_program/dut/cpu_core/imm_i
add wave -noupdate -group CPU /tb_ROC_RV32_program/dut/cpu_core/imm_s
add wave -noupdate -group CPU /tb_ROC_RV32_program/dut/cpu_core/imm_b
add wave -noupdate -group CPU /tb_ROC_RV32_program/dut/cpu_core/imm_u
add wave -noupdate -group CPU /tb_ROC_RV32_program/dut/cpu_core/imm_j
add wave -noupdate -group CPU /tb_ROC_RV32_program/dut/cpu_core/pc_output
add wave -noupdate -group CPU /tb_ROC_RV32_program/dut/cpu_core/pc_ir
add wave -noupdate -group CPU /tb_ROC_RV32_program/dut/cpu_core/pc_ir_plus4
add wave -noupdate -group CPU /tb_ROC_RV32_program/dut/cpu_core/wena_reg
add wave -noupdate -group CPU /tb_ROC_RV32_program/dut/cpu_core/imm_ext
add wave -noupdate -group CPU /tb_ROC_RV32_program/dut/cpu_core/alu_src1
add wave -noupdate -group CPU /tb_ROC_RV32_program/dut/cpu_core/alu_src2
add wave -noupdate -group CPU /tb_ROC_RV32_program/dut/cpu_core/data_2_reg
add wave -noupdate -group CPU /tb_ROC_RV32_program/dut/cpu_core/branch_invert
add wave -noupdate -group CPU /tb_ROC_RV32_program/dut/cpu_core/cpu_state
add wave -noupdate -group CPU /tb_ROC_RV32_program/dut/cpu_core/alu_out
add wave -noupdate -group CPU /tb_ROC_RV32_program/dut/cpu_core/load_ext
add wave -noupdate -group CPU /tb_ROC_RV32_program/dut/cpu_core/reg_di
add wave -noupdate -group CPU /tb_ROC_RV32_program/dut/cpu_core/do1
add wave -noupdate -group CPU /tb_ROC_RV32_program/dut/cpu_core/do2
add wave -noupdate -group CPU /tb_ROC_RV32_program/dut/cpu_core/dmem_byte_addr
add wave -noupdate -group CPU /tb_ROC_RV32_program/dut/cpu_core/alu_op1
add wave -noupdate -group imem /tb_ROC_RV32_program/dut/instruction_memory/data_memory/clk
add wave -noupdate -group imem /tb_ROC_RV32_program/dut/instruction_memory/data_memory/en_a
add wave -noupdate -group imem /tb_ROC_RV32_program/dut/instruction_memory/data_memory/we_a
add wave -noupdate -group imem /tb_ROC_RV32_program/dut/instruction_memory/data_memory/wstrb_a
add wave -noupdate -group imem /tb_ROC_RV32_program/dut/instruction_memory/data_memory/addr_a
add wave -noupdate -group imem /tb_ROC_RV32_program/dut/instruction_memory/data_memory/din_a
add wave -noupdate -group imem /tb_ROC_RV32_program/dut/instruction_memory/data_memory/dout_a
add wave -noupdate -group imem /tb_ROC_RV32_program/dut/instruction_memory/data_memory/en_b
add wave -noupdate -group imem /tb_ROC_RV32_program/dut/instruction_memory/data_memory/we_b
add wave -noupdate -group imem /tb_ROC_RV32_program/dut/instruction_memory/data_memory/wstrb_b
add wave -noupdate -group imem /tb_ROC_RV32_program/dut/instruction_memory/data_memory/addr_b
add wave -noupdate -group imem /tb_ROC_RV32_program/dut/instruction_memory/data_memory/din_b
add wave -noupdate -group imem /tb_ROC_RV32_program/dut/instruction_memory/data_memory/dout_b
add wave -noupdate -group imem /tb_ROC_RV32_program/dut/instruction_memory/data_memory/mem
add wave -noupdate -group dmem /tb_ROC_RV32_program/dut/data_memory/data_memory/clk
add wave -noupdate -group dmem /tb_ROC_RV32_program/dut/data_memory/data_memory/en_a
add wave -noupdate -group dmem /tb_ROC_RV32_program/dut/data_memory/data_memory/we_a
add wave -noupdate -group dmem /tb_ROC_RV32_program/dut/data_memory/data_memory/wstrb_a
add wave -noupdate -group dmem /tb_ROC_RV32_program/dut/data_memory/data_memory/addr_a
add wave -noupdate -group dmem /tb_ROC_RV32_program/dut/data_memory/data_memory/din_a
add wave -noupdate -group dmem /tb_ROC_RV32_program/dut/data_memory/data_memory/dout_a
add wave -noupdate -group dmem /tb_ROC_RV32_program/dut/data_memory/data_memory/en_b
add wave -noupdate -group dmem /tb_ROC_RV32_program/dut/data_memory/data_memory/we_b
add wave -noupdate -group dmem /tb_ROC_RV32_program/dut/data_memory/data_memory/wstrb_b
add wave -noupdate -group dmem /tb_ROC_RV32_program/dut/data_memory/data_memory/addr_b
add wave -noupdate -group dmem /tb_ROC_RV32_program/dut/data_memory/data_memory/din_b
add wave -noupdate -group dmem /tb_ROC_RV32_program/dut/data_memory/data_memory/dout_b
add wave -noupdate -group dmem /tb_ROC_RV32_program/dut/data_memory/data_memory/mem
add wave -noupdate -group loader /tb_ROC_RV32_program/dut/loader/clk
add wave -noupdate -group loader /tb_ROC_RV32_program/dut/loader/nrst
add wave -noupdate -group loader /tb_ROC_RV32_program/dut/loader/rx
add wave -noupdate -group loader /tb_ROC_RV32_program/dut/loader/tx
add wave -noupdate -group loader /tb_ROC_RV32_program/dut/loader/addr_d
add wave -noupdate -group loader /tb_ROC_RV32_program/dut/loader/dout_d
add wave -noupdate -group loader /tb_ROC_RV32_program/dut/loader/we_i
add wave -noupdate -group loader /tb_ROC_RV32_program/dut/loader/addr_i
add wave -noupdate -group loader /tb_ROC_RV32_program/dut/loader/din_i
add wave -noupdate -group loader /tb_ROC_RV32_program/dut/loader/ena_tx_word
add wave -noupdate -group loader /tb_ROC_RV32_program/dut/loader/tx_done_word
add wave -noupdate -group loader /tb_ROC_RV32_program/dut/loader/new_rx_word
add wave -noupdate -group loader /tb_ROC_RV32_program/dut/loader/data_send_word
add wave -noupdate -group loader /tb_ROC_RV32_program/dut/loader/data_recv_word
add wave -noupdate -group loader /tb_ROC_RV32_program/dut/loader/cnt_data
add wave -noupdate -group loader /tb_ROC_RV32_program/dut/loader/num_data
add wave -noupdate -group loader /tb_ROC_RV32_program/dut/loader/addr_pos
add wave -noupdate -group loader /tb_ROC_RV32_program/dut/loader/header_num_data
add wave -noupdate -group loader /tb_ROC_RV32_program/dut/loader/final_addr
add wave -noupdate -group loader /tb_ROC_RV32_program/dut/loader/header_addr
add wave -noupdate -group loader /tb_ROC_RV32_program/dut/loader/header_addr_oob
add wave -noupdate -group loader /tb_ROC_RV32_program/dut/loader/state
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {0 ps} 0}
quietly wave cursor active 0
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
WaveRestoreZoom {129818309050 ps} {129818310050 ps}
