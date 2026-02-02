onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -group xbar /tb_ROC_RV32_program/dut/axi_xbar/clk
add wave -noupdate -group xbar /tb_ROC_RV32_program/dut/axi_xbar/nrst
add wave -noupdate -group xbar /tb_ROC_RV32_program/dut/axi_xbar/awaddr_m
add wave -noupdate -group xbar /tb_ROC_RV32_program/dut/axi_xbar/awprot_m
add wave -noupdate -group xbar /tb_ROC_RV32_program/dut/axi_xbar/awvalid_m
add wave -noupdate -group xbar /tb_ROC_RV32_program/dut/axi_xbar/awready_m
add wave -noupdate -group xbar /tb_ROC_RV32_program/dut/axi_xbar/wdata_m
add wave -noupdate -group xbar /tb_ROC_RV32_program/dut/axi_xbar/wstrb_m
add wave -noupdate -group xbar /tb_ROC_RV32_program/dut/axi_xbar/wvalid_m
add wave -noupdate -group xbar /tb_ROC_RV32_program/dut/axi_xbar/wready_m
add wave -noupdate -group xbar /tb_ROC_RV32_program/dut/axi_xbar/bresp_m
add wave -noupdate -group xbar /tb_ROC_RV32_program/dut/axi_xbar/bvalid_m
add wave -noupdate -group xbar /tb_ROC_RV32_program/dut/axi_xbar/bready_m
add wave -noupdate -group xbar /tb_ROC_RV32_program/dut/axi_xbar/araddr_m
add wave -noupdate -group xbar /tb_ROC_RV32_program/dut/axi_xbar/arprot_m
add wave -noupdate -group xbar /tb_ROC_RV32_program/dut/axi_xbar/arvalid_m
add wave -noupdate -group xbar /tb_ROC_RV32_program/dut/axi_xbar/arready_m
add wave -noupdate -group xbar /tb_ROC_RV32_program/dut/axi_xbar/rdata_m
add wave -noupdate -group xbar /tb_ROC_RV32_program/dut/axi_xbar/rresp_m
add wave -noupdate -group xbar /tb_ROC_RV32_program/dut/axi_xbar/rvalid_m
add wave -noupdate -group xbar /tb_ROC_RV32_program/dut/axi_xbar/rready_m
add wave -noupdate -group xbar /tb_ROC_RV32_program/dut/axi_xbar/awaddr_s
add wave -noupdate -group xbar /tb_ROC_RV32_program/dut/axi_xbar/awprot_s
add wave -noupdate -group xbar /tb_ROC_RV32_program/dut/axi_xbar/awvalid_s
add wave -noupdate -group xbar /tb_ROC_RV32_program/dut/axi_xbar/awready_s
add wave -noupdate -group xbar /tb_ROC_RV32_program/dut/axi_xbar/wdata_s
add wave -noupdate -group xbar /tb_ROC_RV32_program/dut/axi_xbar/wstrb_s
add wave -noupdate -group xbar /tb_ROC_RV32_program/dut/axi_xbar/wvalid_s
add wave -noupdate -group xbar /tb_ROC_RV32_program/dut/axi_xbar/wready_s
add wave -noupdate -group xbar /tb_ROC_RV32_program/dut/axi_xbar/bresp_s
add wave -noupdate -group xbar /tb_ROC_RV32_program/dut/axi_xbar/bvalid_s
add wave -noupdate -group xbar /tb_ROC_RV32_program/dut/axi_xbar/bready_s
add wave -noupdate -group xbar /tb_ROC_RV32_program/dut/axi_xbar/araddr_s
add wave -noupdate -group xbar /tb_ROC_RV32_program/dut/axi_xbar/arprot_s
add wave -noupdate -group xbar /tb_ROC_RV32_program/dut/axi_xbar/arvalid_s
add wave -noupdate -group xbar /tb_ROC_RV32_program/dut/axi_xbar/arready_s
add wave -noupdate -group xbar /tb_ROC_RV32_program/dut/axi_xbar/rdata_s
add wave -noupdate -group xbar /tb_ROC_RV32_program/dut/axi_xbar/rresp_s
add wave -noupdate -group xbar /tb_ROC_RV32_program/dut/axi_xbar/rvalid_s
add wave -noupdate -group xbar /tb_ROC_RV32_program/dut/axi_xbar/rready_s
add wave -noupdate -group xbar /tb_ROC_RV32_program/dut/axi_xbar/state_write
add wave -noupdate -group xbar /tb_ROC_RV32_program/dut/axi_xbar/confirmed_aw
add wave -noupdate -group xbar /tb_ROC_RV32_program/dut/axi_xbar/confirmed_w
add wave -noupdate -group xbar /tb_ROC_RV32_program/dut/axi_xbar/selected_slave_addr_w
add wave -noupdate -group xbar /tb_ROC_RV32_program/dut/axi_xbar/selected_slave_w
add wave -noupdate -group xbar /tb_ROC_RV32_program/dut/axi_xbar/no_hit_w
add wave -noupdate -group xbar /tb_ROC_RV32_program/dut/axi_xbar/aw_buf_valid
add wave -noupdate -group xbar /tb_ROC_RV32_program/dut/axi_xbar/aw_buf_addr
add wave -noupdate -group xbar /tb_ROC_RV32_program/dut/axi_xbar/aw_buf_prot
add wave -noupdate -group xbar /tb_ROC_RV32_program/dut/axi_xbar/w_buf_valid
add wave -noupdate -group xbar /tb_ROC_RV32_program/dut/axi_xbar/w_buf_data
add wave -noupdate -group xbar /tb_ROC_RV32_program/dut/axi_xbar/w_buf_strb
add wave -noupdate -group xbar /tb_ROC_RV32_program/dut/axi_xbar/state_read
add wave -noupdate -group xbar /tb_ROC_RV32_program/dut/axi_xbar/selected_slave_addr_r
add wave -noupdate -group xbar /tb_ROC_RV32_program/dut/axi_xbar/selected_slave_r
add wave -noupdate -group xbar /tb_ROC_RV32_program/dut/axi_xbar/no_hit_r
add wave -noupdate -group xbar /tb_ROC_RV32_program/dut/axi_xbar/ar_buf_valid
add wave -noupdate -group xbar /tb_ROC_RV32_program/dut/axi_xbar/ar_buf_addr
add wave -noupdate -group xbar /tb_ROC_RV32_program/dut/axi_xbar/ar_buf_prot
add wave -noupdate -group gpio /tb_ROC_RV32_program/dut/axi_gpio_i/clk
add wave -noupdate -group gpio /tb_ROC_RV32_program/dut/axi_gpio_i/nrst
add wave -noupdate -group gpio /tb_ROC_RV32_program/dut/axi_gpio_i/awaddr
add wave -noupdate -group gpio /tb_ROC_RV32_program/dut/axi_gpio_i/awprot
add wave -noupdate -group gpio /tb_ROC_RV32_program/dut/axi_gpio_i/awvalid
add wave -noupdate -group gpio /tb_ROC_RV32_program/dut/axi_gpio_i/awready
add wave -noupdate -group gpio /tb_ROC_RV32_program/dut/axi_gpio_i/wdata
add wave -noupdate -group gpio /tb_ROC_RV32_program/dut/axi_gpio_i/wstrb
add wave -noupdate -group gpio /tb_ROC_RV32_program/dut/axi_gpio_i/wvalid
add wave -noupdate -group gpio /tb_ROC_RV32_program/dut/axi_gpio_i/wready
add wave -noupdate -group gpio /tb_ROC_RV32_program/dut/axi_gpio_i/bresp
add wave -noupdate -group gpio /tb_ROC_RV32_program/dut/axi_gpio_i/bvalid
add wave -noupdate -group gpio /tb_ROC_RV32_program/dut/axi_gpio_i/bready
add wave -noupdate -group gpio /tb_ROC_RV32_program/dut/axi_gpio_i/araddr
add wave -noupdate -group gpio /tb_ROC_RV32_program/dut/axi_gpio_i/arprot
add wave -noupdate -group gpio /tb_ROC_RV32_program/dut/axi_gpio_i/arvalid
add wave -noupdate -group gpio /tb_ROC_RV32_program/dut/axi_gpio_i/arready
add wave -noupdate -group gpio /tb_ROC_RV32_program/dut/axi_gpio_i/rdata
add wave -noupdate -group gpio /tb_ROC_RV32_program/dut/axi_gpio_i/rresp
add wave -noupdate -group gpio /tb_ROC_RV32_program/dut/axi_gpio_i/rvalid
add wave -noupdate -group gpio /tb_ROC_RV32_program/dut/axi_gpio_i/rready
add wave -noupdate -group gpio /tb_ROC_RV32_program/dut/axi_gpio_i/pin_gpio
add wave -noupdate -group gpio /tb_ROC_RV32_program/dut/axi_gpio_i/reg_dir
add wave -noupdate -group gpio /tb_ROC_RV32_program/dut/axi_gpio_i/reg_gpios_out
add wave -noupdate -group gpio /tb_ROC_RV32_program/dut/axi_gpio_i/gpios_ff
add wave -noupdate -group gpio /tb_ROC_RV32_program/dut/axi_gpio_i/gpios_ff2
add wave -noupdate -group gpio /tb_ROC_RV32_program/dut/axi_gpio_i/araddr_reg
add wave -noupdate -group gpio /tb_ROC_RV32_program/dut/axi_gpio_i/awaddr_reg
add wave -noupdate -group gpio /tb_ROC_RV32_program/dut/axi_gpio_i/wdata_reg
add wave -noupdate -group gpio /tb_ROC_RV32_program/dut/axi_gpio_i/wstrb_reg
add wave -noupdate -group gpio /tb_ROC_RV32_program/dut/axi_gpio_i/state_r
add wave -noupdate -group gpio /tb_ROC_RV32_program/dut/axi_gpio_i/state_w
add wave -noupdate -group regs /tb_ROC_RV32_program/dut/regs_peripheral_i/clk
add wave -noupdate -group regs /tb_ROC_RV32_program/dut/regs_peripheral_i/nrst
add wave -noupdate -group regs /tb_ROC_RV32_program/dut/regs_peripheral_i/awaddr
add wave -noupdate -group regs /tb_ROC_RV32_program/dut/regs_peripheral_i/awprot
add wave -noupdate -group regs /tb_ROC_RV32_program/dut/regs_peripheral_i/awvalid
add wave -noupdate -group regs /tb_ROC_RV32_program/dut/regs_peripheral_i/awready
add wave -noupdate -group regs /tb_ROC_RV32_program/dut/regs_peripheral_i/wdata
add wave -noupdate -group regs /tb_ROC_RV32_program/dut/regs_peripheral_i/wstrb
add wave -noupdate -group regs /tb_ROC_RV32_program/dut/regs_peripheral_i/wvalid
add wave -noupdate -group regs /tb_ROC_RV32_program/dut/regs_peripheral_i/wready
add wave -noupdate -group regs /tb_ROC_RV32_program/dut/regs_peripheral_i/bresp
add wave -noupdate -group regs /tb_ROC_RV32_program/dut/regs_peripheral_i/bvalid
add wave -noupdate -group regs /tb_ROC_RV32_program/dut/regs_peripheral_i/bready
add wave -noupdate -group regs /tb_ROC_RV32_program/dut/regs_peripheral_i/araddr
add wave -noupdate -group regs /tb_ROC_RV32_program/dut/regs_peripheral_i/arprot
add wave -noupdate -group regs /tb_ROC_RV32_program/dut/regs_peripheral_i/arvalid
add wave -noupdate -group regs /tb_ROC_RV32_program/dut/regs_peripheral_i/arready
add wave -noupdate -group regs /tb_ROC_RV32_program/dut/regs_peripheral_i/rdata
add wave -noupdate -group regs /tb_ROC_RV32_program/dut/regs_peripheral_i/rresp
add wave -noupdate -group regs /tb_ROC_RV32_program/dut/regs_peripheral_i/rvalid
add wave -noupdate -group regs /tb_ROC_RV32_program/dut/regs_peripheral_i/rready
add wave -noupdate -group regs /tb_ROC_RV32_program/dut/regs_peripheral_i/reg_array
add wave -noupdate -group regs /tb_ROC_RV32_program/dut/regs_peripheral_i/araddr_reg
add wave -noupdate -group regs /tb_ROC_RV32_program/dut/regs_peripheral_i/awaddr_reg
add wave -noupdate -group regs /tb_ROC_RV32_program/dut/regs_peripheral_i/wdata_reg
add wave -noupdate -group regs /tb_ROC_RV32_program/dut/regs_peripheral_i/wstrb_reg
add wave -noupdate -group regs /tb_ROC_RV32_program/dut/regs_peripheral_i/state_r
add wave -noupdate -group regs /tb_ROC_RV32_program/dut/regs_peripheral_i/state_w
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {102706937485 ps} 0}
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
WaveRestoreZoom {0 ps} {176702179500 ps}
