set_property -dict {PACKAGE_PIN Y9  IOSTANDARD LVCMOS33} [get_ports clk]
create_clock -period 20.000 -name sys_clk [get_ports clk]
set_property -dict {PACKAGE_PIN P15 IOSTANDARD LVCMOS33} [get_ports tx]