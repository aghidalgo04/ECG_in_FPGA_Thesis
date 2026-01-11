set_property PACKAGE_PIN F21 [get_ports sw1]
set_property PACKAGE_PIN T14 [get_ports led0]
set_property PACKAGE_PIN T15 [get_ports led1]
set_property PACKAGE_PIN R4 [get_ports clk]
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports { clk }];
set_property IOSTANDARD LVCMOS33 [get_ports clk]
set_property IOSTANDARD LVCMOS25 [get_ports led0]
set_property IOSTANDARD LVCMOS25 [get_ports led1]
set_property IOSTANDARD LVCMOS12 [get_ports sw1]
