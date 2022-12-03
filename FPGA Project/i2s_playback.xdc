# 12 MHz System Clock
set_property -dict { PACKAGE_PIN M9    IOSTANDARD LVCMOS33 } [get_ports { clk }]; #IO_L13P_T2_MRCC_14 Sch=gclk
create_clock -add -name sys_clk_pin -period 83.33 -waveform {0 41.66} [get_ports { clk }];

set_property -dict {PACKAGE_PIN J2 IOSTANDARD LVCMOS33} [get_ports {mclk[1]}] 
set_property -dict {PACKAGE_PIN H3 IOSTANDARD LVCMOS33}  [get_ports {mclk[0]}]
set_property -dict {PACKAGE_PIN H4 IOSTANDARD LVCMOS33} [get_ports {sclk[1]}]
set_property -dict {PACKAGE_PIN G1 IOSTANDARD LVCMOS33} [get_ports {sclk[0]}]
set_property -dict {PACKAGE_PIN H2 IOSTANDARD LVCMOS33} [get_ports {ws[1]}]
set_property -dict {PACKAGE_PIN H1 IOSTANDARD LVCMOS33} [get_ports {ws[0]}]
set_property -dict {PACKAGE_PIN F4 IOSTANDARD LVCMOS33} [get_ports sd_rx]
set_property -dict {PACKAGE_PIN F3 IOSTANDARD LVCMOS33} [get_ports sd_tx]