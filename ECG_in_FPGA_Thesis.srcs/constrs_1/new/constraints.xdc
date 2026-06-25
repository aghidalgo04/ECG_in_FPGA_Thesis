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



create_debug_core u_ila_0 ila
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_0]
set_property ALL_PROBE_SAME_MU_CNT 1 [get_debug_cores u_ila_0]
set_property C_ADV_TRIGGER false [get_debug_cores u_ila_0]
set_property C_DATA_DEPTH 16384 [get_debug_cores u_ila_0]
set_property C_EN_STRG_QUAL false [get_debug_cores u_ila_0]
set_property C_INPUT_PIPE_STAGES 0 [get_debug_cores u_ila_0]
set_property C_TRIGIN_EN false [get_debug_cores u_ila_0]
set_property C_TRIGOUT_EN false [get_debug_cores u_ila_0]
set_property port_width 1 [get_debug_ports u_ila_0/clk]
connect_debug_port u_ila_0/clk [get_nets [list clk_IBUF_BUFG]]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe0]
set_property port_width 24 [get_debug_ports u_ila_0/probe0]
connect_debug_port u_ila_0/probe0 [get_nets [list {s_dx_s3[0]} {s_dx_s3[1]} {s_dx_s3[2]} {s_dx_s3[3]} {s_dx_s3[4]} {s_dx_s3[5]} {s_dx_s3[6]} {s_dx_s3[7]} {s_dx_s3[8]} {s_dx_s3[9]} {s_dx_s3[10]} {s_dx_s3[11]} {s_dx_s3[12]} {s_dx_s3[13]} {s_dx_s3[14]} {s_dx_s3[15]} {s_dx_s3[16]} {s_dx_s3[17]} {s_dx_s3[18]} {s_dx_s3[19]} {s_dx_s3[20]} {s_dx_s3[21]} {s_dx_s3[22]} {s_dx_s3[23]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe1]
set_property port_width 23 [get_debug_ports u_ila_0/probe1]
connect_debug_port u_ila_0/probe1 [get_nets [list {s_rt_ms[0]} {s_rt_ms[1]} {s_rt_ms[2]} {s_rt_ms[3]} {s_rt_ms[4]} {s_rt_ms[5]} {s_rt_ms[6]} {s_rt_ms[7]} {s_rt_ms[8]} {s_rt_ms[9]} {s_rt_ms[10]} {s_rt_ms[11]} {s_rt_ms[12]} {s_rt_ms[13]} {s_rt_ms[14]} {s_rt_ms[15]} {s_rt_ms[16]} {s_rt_ms[17]} {s_rt_ms[18]} {s_rt_ms[19]} {s_rt_ms[20]} {s_rt_ms[21]} {s_rt_ms[23]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe2]
set_property port_width 24 [get_debug_ports u_ila_0/probe2]
connect_debug_port u_ila_0/probe2 [get_nets [list {s_raw_z[0]} {s_raw_z[1]} {s_raw_z[2]} {s_raw_z[3]} {s_raw_z[4]} {s_raw_z[5]} {s_raw_z[6]} {s_raw_z[7]} {s_raw_z[8]} {s_raw_z[9]} {s_raw_z[10]} {s_raw_z[11]} {s_raw_z[12]} {s_raw_z[13]} {s_raw_z[14]} {s_raw_z[15]} {s_raw_z[16]} {s_raw_z[17]} {s_raw_z[18]} {s_raw_z[19]} {s_raw_z[20]} {s_raw_z[21]} {s_raw_z[22]} {s_raw_z[23]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe3]
set_property port_width 24 [get_debug_ports u_ila_0/probe3]
connect_debug_port u_ila_0/probe3 [get_nets [list {s_raw_y[0]} {s_raw_y[1]} {s_raw_y[2]} {s_raw_y[3]} {s_raw_y[4]} {s_raw_y[5]} {s_raw_y[6]} {s_raw_y[7]} {s_raw_y[8]} {s_raw_y[9]} {s_raw_y[10]} {s_raw_y[11]} {s_raw_y[12]} {s_raw_y[13]} {s_raw_y[14]} {s_raw_y[15]} {s_raw_y[16]} {s_raw_y[17]} {s_raw_y[18]} {s_raw_y[19]} {s_raw_y[20]} {s_raw_y[21]} {s_raw_y[22]} {s_raw_y[23]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe4]
set_property port_width 24 [get_debug_ports u_ila_0/probe4]
connect_debug_port u_ila_0/probe4 [get_nets [list {s_dy_s3[0]} {s_dy_s3[1]} {s_dy_s3[2]} {s_dy_s3[3]} {s_dy_s3[4]} {s_dy_s3[5]} {s_dy_s3[6]} {s_dy_s3[7]} {s_dy_s3[8]} {s_dy_s3[9]} {s_dy_s3[10]} {s_dy_s3[11]} {s_dy_s3[12]} {s_dy_s3[13]} {s_dy_s3[14]} {s_dy_s3[15]} {s_dy_s3[16]} {s_dy_s3[17]} {s_dy_s3[18]} {s_dy_s3[19]} {s_dy_s3[20]} {s_dy_s3[21]} {s_dy_s3[22]} {s_dy_s3[23]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe5]
set_property port_width 24 [get_debug_ports u_ila_0/probe5]
connect_debug_port u_ila_0/probe5 [get_nets [list {s_raw_x[0]} {s_raw_x[1]} {s_raw_x[2]} {s_raw_x[3]} {s_raw_x[4]} {s_raw_x[5]} {s_raw_x[6]} {s_raw_x[7]} {s_raw_x[8]} {s_raw_x[9]} {s_raw_x[10]} {s_raw_x[11]} {s_raw_x[12]} {s_raw_x[13]} {s_raw_x[14]} {s_raw_x[15]} {s_raw_x[16]} {s_raw_x[17]} {s_raw_x[18]} {s_raw_x[19]} {s_raw_x[20]} {s_raw_x[21]} {s_raw_x[22]} {s_raw_x[23]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe6]
set_property port_width 24 [get_debug_ports u_ila_0/probe6]
connect_debug_port u_ila_0/probe6 [get_nets [list {s_dz_s3[0]} {s_dz_s3[1]} {s_dz_s3[2]} {s_dz_s3[3]} {s_dz_s3[4]} {s_dz_s3[5]} {s_dz_s3[6]} {s_dz_s3[7]} {s_dz_s3[8]} {s_dz_s3[9]} {s_dz_s3[10]} {s_dz_s3[11]} {s_dz_s3[12]} {s_dz_s3[13]} {s_dz_s3[14]} {s_dz_s3[15]} {s_dz_s3[16]} {s_dz_s3[17]} {s_dz_s3[18]} {s_dz_s3[19]} {s_dz_s3[20]} {s_dz_s3[21]} {s_dz_s3[22]} {s_dz_s3[23]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe7]
set_property port_width 23 [get_debug_ports u_ila_0/probe7]
connect_debug_port u_ila_0/probe7 [get_nets [list {s_rr_ms[0]} {s_rr_ms[1]} {s_rr_ms[2]} {s_rr_ms[3]} {s_rr_ms[4]} {s_rr_ms[5]} {s_rr_ms[6]} {s_rr_ms[7]} {s_rr_ms[8]} {s_rr_ms[9]} {s_rr_ms[10]} {s_rr_ms[11]} {s_rr_ms[12]} {s_rr_ms[13]} {s_rr_ms[14]} {s_rr_ms[15]} {s_rr_ms[16]} {s_rr_ms[17]} {s_rr_ms[18]} {s_rr_ms[19]} {s_rr_ms[20]} {s_rr_ms[21]} {s_rr_ms[23]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe8]
set_property port_width 1 [get_debug_ports u_ila_0/probe8]
connect_debug_port u_ila_0/probe8 [get_nets [list cs_b_OBUF]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe9]
set_property port_width 1 [get_debug_ports u_ila_0/probe9]
connect_debug_port u_ila_0/probe9 [get_nets [list drdy_b_IBUF]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe10]
set_property port_width 1 [get_debug_ports u_ila_0/probe10]
connect_debug_port u_ila_0/probe10 [get_nets [list miso_IBUF]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe11]
set_property port_width 1 [get_debug_ports u_ila_0/probe11]
connect_debug_port u_ila_0/probe11 [get_nets [list mosi_OBUF]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe12]
set_property port_width 1 [get_debug_ports u_ila_0/probe12]
connect_debug_port u_ila_0/probe12 [get_nets [list reset_IBUF]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe13]
set_property port_width 1 [get_debug_ports u_ila_0/probe13]
connect_debug_port u_ila_0/probe13 [get_nets [list s_al_asyst]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe14]
set_property port_width 1 [get_debug_ports u_ila_0/probe14]
connect_debug_port u_ila_0/probe14 [get_nets [list s_qrs_unified]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe15]
set_property port_width 1 [get_debug_ports u_ila_0/probe15]
connect_debug_port u_ila_0/probe15 [get_nets [list s_qrs_x]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe16]
set_property port_width 1 [get_debug_ports u_ila_0/probe16]
connect_debug_port u_ila_0/probe16 [get_nets [list s_qrs_y]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe17]
set_property port_width 1 [get_debug_ports u_ila_0/probe17]
connect_debug_port u_ila_0/probe17 [get_nets [list s_qrs_z]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe18]
set_property port_width 1 [get_debug_ports u_ila_0/probe18]
connect_debug_port u_ila_0/probe18 [get_nets [list s_rdy_s3]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe19]
set_property port_width 1 [get_debug_ports u_ila_0/probe19]
connect_debug_port u_ila_0/probe19 [get_nets [list sclk_OBUF]]
set_property C_CLK_INPUT_FREQ_HZ 300000000 [get_debug_cores dbg_hub]
set_property C_ENABLE_CLK_DIVIDER false [get_debug_cores dbg_hub]
set_property C_USER_SCAN_CHAIN 1 [get_debug_cores dbg_hub]
connect_debug_port dbg_hub/clk [get_nets clk_IBUF_BUFG]
