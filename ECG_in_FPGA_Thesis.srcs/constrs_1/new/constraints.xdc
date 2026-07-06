set_property PACKAGE_PIN F21 [get_ports sw1]
set_property PACKAGE_PIN T14 [get_ports led0]
set_property PACKAGE_PIN T15 [get_ports led1]
set_property PACKAGE_PIN R4 [get_ports clk]
create_clock -period 10.000 -name sys_clk_pin -waveform {0.000 5.000} -add [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]
set_property IOSTANDARD LVCMOS25 [get_ports led0]
set_property IOSTANDARD LVCMOS25 [get_ports led1]
set_property IOSTANDARD LVCMOS12 [get_ports sw1]

set_property PACKAGE_PIN V18 [get_ports tx]
set_property PACKAGE_PIN B22 [get_ports reset]
set_property PACKAGE_PIN AB22 [get_ports sclk]
set_property PACKAGE_PIN AB21 [get_ports mosi]
set_property PACKAGE_PIN AB20 [get_ports miso]
set_property PACKAGE_PIN AB18 [get_ports cs_b]
set_property PACKAGE_PIN Y21 [get_ports drdy_b]
set_property IOSTANDARD LVCMOS33 [get_ports cs_b]
set_property IOSTANDARD LVCMOS33 [get_ports drdy_b]
set_property IOSTANDARD LVCMOS33 [get_ports miso]
set_property IOSTANDARD LVCMOS33 [get_ports mosi]
set_property IOSTANDARD LVCMOS33 [get_ports reset]
set_property IOSTANDARD LVCMOS33 [get_ports sclk]
set_property IOSTANDARD LVCMOS33 [get_ports tx]


connect_debug_port u_ila_0/probe26 [get_nets [list {SPI_INST/cfg_ptr[0]_i_1_n_0}]]
connect_debug_port u_ila_0/probe27 [get_nets [list {SPI_INST/cfg_ptr[1]_i_1_n_0}]]
connect_debug_port u_ila_0/probe28 [get_nets [list {SPI_INST/cfg_ptr[2]_i_1_n_0}]]




