## Nexys A7 constraints template (fill in pins as needed)
## Clock: 50 MHz

# Clock input
set_property PACKAGE_PIN E3 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]
create_clock -period 10.000 -name sys_clk -waveform {0.000 5.000} [get_ports clk]

# Reset (active-low)
set_property PACKAGE_PIN M17 [get_ports rst]
set_property IOSTANDARD LVCMOS33 [get_ports rst]

# BOOTLOADER UART RX
set_property PACKAGE_PIN C4 [get_ports rx]
set_property IOSTANDARD LVCMOS33 [get_ports rx]
set_property PACKAGE_PIN D4 [get_ports tx]
set_property IOSTANDARD LVCMOS33 [get_ports tx]

# UART peripheral
set_property PACKAGE_PIN C17 [get_ports uart_rx]
set_property IOSTANDARD LVCMOS33 [get_ports uart_rx]
set_property PACKAGE_PIN D18 [get_ports uart_tx]
set_property IOSTANDARD LVCMOS33 [get_ports uart_tx]

# Status LED (active-low)
set_property PACKAGE_PIN R11 [get_ports led_status]
set_property IOSTANDARD LVCMOS33 [get_ports led_status]

# GPIO Pins
# SW0 - SW15
set_property PACKAGE_PIN J15 [get_ports {pin_gpio[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {pin_gpio[0]}]
set_property PACKAGE_PIN L16 [get_ports {pin_gpio[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {pin_gpio[1]}]
set_property PACKAGE_PIN M13 [get_ports {pin_gpio[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {pin_gpio[2]}]
set_property PACKAGE_PIN R15 [get_ports {pin_gpio[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {pin_gpio[3]}]
set_property PACKAGE_PIN R17 [get_ports {pin_gpio[4]}]
set_property IOSTANDARD LVCMOS33 [get_ports {pin_gpio[4]}]
set_property PACKAGE_PIN T18 [get_ports {pin_gpio[5]}]
set_property IOSTANDARD LVCMOS33 [get_ports {pin_gpio[5]}]
set_property PACKAGE_PIN U18 [get_ports {pin_gpio[6]}]
set_property IOSTANDARD LVCMOS33 [get_ports {pin_gpio[6]}]
set_property PACKAGE_PIN R13 [get_ports {pin_gpio[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {pin_gpio[7]}]
set_property PACKAGE_PIN T8 [get_ports {pin_gpio[8]}]
set_property IOSTANDARD LVCMOS33 [get_ports {pin_gpio[8]}]
set_property PACKAGE_PIN U8 [get_ports {pin_gpio[9]}]
set_property IOSTANDARD LVCMOS33 [get_ports {pin_gpio[9]}]
set_property PACKAGE_PIN R16 [get_ports {pin_gpio[10]}]
set_property IOSTANDARD LVCMOS33 [get_ports {pin_gpio[10]}]
set_property PACKAGE_PIN T13 [get_ports {pin_gpio[11]}]
set_property IOSTANDARD LVCMOS33 [get_ports {pin_gpio[11]}]
set_property PACKAGE_PIN H6 [get_ports {pin_gpio[12]}]
set_property IOSTANDARD LVCMOS33 [get_ports {pin_gpio[12]}]
set_property PACKAGE_PIN U12 [get_ports {pin_gpio[13]}]
set_property IOSTANDARD LVCMOS33 [get_ports {pin_gpio[13]}]
set_property PACKAGE_PIN U11 [get_ports {pin_gpio[14]}]
set_property IOSTANDARD LVCMOS33 [get_ports {pin_gpio[14]}]
set_property PACKAGE_PIN V10 [get_ports {pin_gpio[15]}]
set_property IOSTANDARD LVCMOS33 [get_ports {pin_gpio[15]}]

# LED0 - LED15 (Nexys A7)
set_property PACKAGE_PIN H17 [get_ports {pin_gpio[16]}]
set_property IOSTANDARD LVCMOS33 [get_ports {pin_gpio[16]}]
set_property PACKAGE_PIN K15 [get_ports {pin_gpio[17]}]
set_property IOSTANDARD LVCMOS33 [get_ports {pin_gpio[17]}]
set_property PACKAGE_PIN J13 [get_ports {pin_gpio[18]}]
set_property IOSTANDARD LVCMOS33 [get_ports {pin_gpio[18]}]
set_property PACKAGE_PIN N14 [get_ports {pin_gpio[19]}]
set_property IOSTANDARD LVCMOS33 [get_ports {pin_gpio[19]}]
set_property PACKAGE_PIN R18 [get_ports {pin_gpio[20]}]
set_property IOSTANDARD LVCMOS33 [get_ports {pin_gpio[20]}]
set_property PACKAGE_PIN V17 [get_ports {pin_gpio[21]}]
set_property IOSTANDARD LVCMOS33 [get_ports {pin_gpio[21]}]
set_property PACKAGE_PIN U17 [get_ports {pin_gpio[22]}]
set_property IOSTANDARD LVCMOS33 [get_ports {pin_gpio[22]}]
set_property PACKAGE_PIN U16 [get_ports {pin_gpio[23]}]
set_property IOSTANDARD LVCMOS33 [get_ports {pin_gpio[23]}]
set_property PACKAGE_PIN V16 [get_ports {pin_gpio[24]}]
set_property IOSTANDARD LVCMOS33 [get_ports {pin_gpio[24]}]
set_property PACKAGE_PIN T15 [get_ports {pin_gpio[25]}]
set_property IOSTANDARD LVCMOS33 [get_ports {pin_gpio[25]}]
set_property PACKAGE_PIN U14 [get_ports {pin_gpio[26]}]
set_property IOSTANDARD LVCMOS33 [get_ports {pin_gpio[26]}]
set_property PACKAGE_PIN T16 [get_ports {pin_gpio[27]}]
set_property IOSTANDARD LVCMOS33 [get_ports {pin_gpio[27]}]
set_property PACKAGE_PIN V15 [get_ports {pin_gpio[28]}]
set_property IOSTANDARD LVCMOS33 [get_ports {pin_gpio[28]}]
set_property PACKAGE_PIN V14 [get_ports {pin_gpio[29]}]
set_property IOSTANDARD LVCMOS33 [get_ports {pin_gpio[29]}]
set_property PACKAGE_PIN V12 [get_ports {pin_gpio[30]}]
set_property IOSTANDARD LVCMOS33 [get_ports {pin_gpio[30]}]
set_property PACKAGE_PIN V11 [get_ports {pin_gpio[31]}]
set_property IOSTANDARD LVCMOS33 [get_ports {pin_gpio[31]}]


#7 segment display

set_property -dict { PACKAGE_PIN T10   IOSTANDARD LVCMOS33 } [get_ports {  ABDCEFG[6] }]; #IO_L24N_T3_A00_D16_14 Sch=ca
set_property -dict { PACKAGE_PIN R10   IOSTANDARD LVCMOS33 } [get_ports {  ABDCEFG[5] }]; #IO_25_14 Sch=cb
set_property -dict { PACKAGE_PIN K16   IOSTANDARD LVCMOS33 } [get_ports {  ABDCEFG[4] }]; #IO_25_15 Sch=cc
set_property -dict { PACKAGE_PIN K13   IOSTANDARD LVCMOS33 } [get_ports {  ABDCEFG[3] }]; #IO_L17P_T2_A26_15 Sch=cd
set_property -dict { PACKAGE_PIN P15   IOSTANDARD LVCMOS33 } [get_ports {  ABDCEFG[2] }]; #IO_L13P_T2_MRCC_14 Sch=ce
set_property -dict { PACKAGE_PIN T11   IOSTANDARD LVCMOS33 } [get_ports {  ABDCEFG[1] }]; #IO_L19P_T3_A10_D26_14 Sch=cf
set_property -dict { PACKAGE_PIN L18   IOSTANDARD LVCMOS33 } [get_ports {  ABDCEFG[0] }]; #IO_L4P_T0_D04_14 Sch=cg

set_property -dict { PACKAGE_PIN H15   IOSTANDARD LVCMOS33 } [get_ports { DP }]; #IO_L19N_T3_A21_VREF_15 Sch=dp

set_property -dict { PACKAGE_PIN J17   IOSTANDARD LVCMOS33 } [get_ports { seg[0] }]; #IO_L23P_T3_FOE_B_15 Sch=an[0]
set_property -dict { PACKAGE_PIN J18   IOSTANDARD LVCMOS33 } [get_ports { seg[1] }]; #IO_L23N_T3_FWE_B_15 Sch=an[1]
set_property -dict { PACKAGE_PIN T9    IOSTANDARD LVCMOS33 } [get_ports { seg[2] }]; #IO_L24P_T3_A01_D17_14 Sch=an[2]
set_property -dict { PACKAGE_PIN J14   IOSTANDARD LVCMOS33 } [get_ports { seg[3] }]; #IO_L19P_T3_A22_15 Sch=an[3]
set_property -dict { PACKAGE_PIN P14   IOSTANDARD LVCMOS33 } [get_ports { seg[4] }]; #IO_L8N_T1_D12_14 Sch=an[4]
set_property -dict { PACKAGE_PIN T14   IOSTANDARD LVCMOS33 } [get_ports { seg[5] }]; #IO_L14P_T2_SRCC_14 Sch=an[5]
set_property -dict { PACKAGE_PIN K2    IOSTANDARD LVCMOS33 } [get_ports { seg[6] }]; #IO_L23P_T3_35 Sch=an[6]
set_property -dict { PACKAGE_PIN U13   IOSTANDARD LVCMOS33 } [get_ports { seg[7] }]; #IO_L23N_T3_A02_D18_14 Sch=an[7]