## Nexys A7 constraints template (fill in pins as needed)
## Clock: 50 MHz

# Clock input
set_property PACKAGE_PIN E3 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]
create_clock -period 10.000 -name sys_clk -waveform {0.000 5.000} [get_ports clk]

# Reset (active-low)
set_property PACKAGE_PIN J15 [get_ports rst_n]
set_property IOSTANDARD LVCMOS33 [get_ports rst_n]

# BOOTLOADER UART RX
set_property PACKAGE_PIN C4 [get_ports rx]
set_property IOSTANDARD LVCMOS33 [get_ports rx]

# BOOTLOADER UART TX
set_property PACKAGE_PIN D4 [get_ports tx]
set_property IOSTANDARD LVCMOS33 [get_ports tx]

# Status LED (active-low)
set_property PACKAGE_PIN H17 [get_ports led_status]
set_property IOSTANDARD LVCMOS33 [get_ports led_status]
