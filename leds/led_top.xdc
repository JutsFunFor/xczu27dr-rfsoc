#==============================================================================
# led_top.xdc  --  pins for the LED / J7 test design
#
# Every line here is a copy of the matching line in ../ZU27DR_v1.1.xdc. The
# master file constrains all 136 board pins, and Vivado errors out on a
# set_property against a port the design does not declare, so each design
# carries the subset it actually uses.
#
# Bank 88 and bank 89 VCCO are both VCC_ADJ = 3.3 V -> LVCMOS33. You will find
# example code declaring LVCMOS18 on A10/H14; that is a bug. See ./README.md.
#==============================================================================

set_property PACKAGE_PIN A10   [get_ports {led[0]}]     ;# HD89_IO_P3   IO_L3P_AD9P_89    DT1
set_property IOSTANDARD LVCMOS33  [get_ports {led[0]}]
set_property DRIVE     8         [get_ports {led[0]}]
set_property SLEW      SLOW      [get_ports {led[0]}]
set_property PACKAGE_PIN D12   [get_ports {led[1]}]     ;# HD88_IO_N8   IO_L8N_HDGC_88    DT5
set_property IOSTANDARD LVCMOS33  [get_ports {led[1]}]
set_property DRIVE     8         [get_ports {led[1]}]
set_property SLEW      SLOW      [get_ports {led[1]}]
set_property PACKAGE_PIN H14   [get_ports {led[2]}]     ;# HD88_IO_N2   IO_L2N_AD14N_88   DT4
set_property IOSTANDARD LVCMOS33  [get_ports {led[2]}]
set_property DRIVE     8         [get_ports {led[2]}]
set_property SLEW      SLOW      [get_ports {led[2]}]

set_property PACKAGE_PIN K15   [get_ports {j7_io4}]     ;# HD88_IO_P1   IO_L1P_AD15P_88   J7.4
set_property IOSTANDARD LVCMOS33  [get_ports {j7_io4}]
set_property PACKAGE_PIN K14   [get_ports {j7_io5}]     ;# HD88_IO_N1   IO_L1N_AD15N_88   J7.5
set_property IOSTANDARD LVCMOS33  [get_ports {j7_io5}]
set_property PACKAGE_PIN J14   [get_ports {j7_io6}]     ;# HD88_IO_P3   IO_L3P_AD13P_88   J7.6
set_property IOSTANDARD LVCMOS33  [get_ports {j7_io6}]
set_property PACKAGE_PIN J13   [get_ports {j7_io7}]     ;# HD88_IO_N3   IO_L3N_AD13N_88   J7.7
set_property IOSTANDARD LVCMOS33  [get_ports {j7_io7}]
set_property PACKAGE_PIN J12   [get_ports {j7_io8}]     ;# HD89_IO_N12  IO_L12N_AD0N_89   J7.8
set_property IOSTANDARD LVCMOS33  [get_ports {j7_io8}]
set_property PACKAGE_PIN K12   [get_ports {j7_io9}]     ;# HD89_IO_P12  IO_L12P_AD0P_89   J7.9
set_property IOSTANDARD LVCMOS33  [get_ports {j7_io9}]

# CFGMCLK is a free-running internal oscillator, nominally 50 MHz but specified
# only as 30-65 MHz. Constrain it at the fast end so timing is never optimistic.
create_clock -name cfgmclk -period 15.385 [get_pins startup_i/CFGMCLK]
