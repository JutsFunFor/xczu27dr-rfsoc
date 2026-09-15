#==============================================================================
# qsfp_top.xdc  --  pins for the QSFP28 sideband test design
#
# Copied from ../ZU27DR_v1.1.xdc, which holds the full board pin map. Bank 88
# VCCO is VCC_ADJ = 3.3 V, so all fourteen sideband pins are LVCMOS33.
#
#   qsfp0_*  the cage whose lanes go to GTY bank 128  (schematic "QSFP1")
#   qsfp1_*  the cage whose lanes go to GTY bank 129  (schematic "QSFP2")
#
# scl and sda are open drain with 4k7 pull-ups to QSFP_VCCT fitted on the
# board. They are driven through IOBUFs inside the block design -- never drive
# them high.
#==============================================================================

# ---- cage 0 -----------------------------------------------------------------
set_property PACKAGE_PIN B12   [get_ports {qsfp0_scl}]        ;# HD88_IO_P12  IO_L12P_AD8P_88    QSFP28 pin 11  SCL
set_property IOSTANDARD LVCMOS33  [get_ports {qsfp0_scl}]
set_property DRIVE     8         [get_ports {qsfp0_scl}]
set_property SLEW      SLOW      [get_ports {qsfp0_scl}]
set_property PACKAGE_PIN A13   [get_ports {qsfp0_sda}]        ;# HD88_IO_N11  IO_L11N_AD9N_88    QSFP28 pin 12  SDA
set_property IOSTANDARD LVCMOS33  [get_ports {qsfp0_sda}]
set_property DRIVE     8         [get_ports {qsfp0_sda}]
set_property SLEW      SLOW      [get_ports {qsfp0_sda}]
set_property PACKAGE_PIN A14   [get_ports {qsfp0_modsel_l}]   ;# HD88_IO_P11  IO_L11P_AD9P_88    QSFP28 pin 8   ModSelL
set_property IOSTANDARD LVCMOS33  [get_ports {qsfp0_modsel_l}]
set_property DRIVE     8         [get_ports {qsfp0_modsel_l}]
set_property SLEW      SLOW      [get_ports {qsfp0_modsel_l}]
set_property PACKAGE_PIN B13   [get_ports {qsfp0_reset_l}]    ;# HD88_IO_N10  IO_L10N_AD10N_88   QSFP28 pin 9   ResetL
set_property IOSTANDARD LVCMOS33  [get_ports {qsfp0_reset_l}]
set_property DRIVE     8         [get_ports {qsfp0_reset_l}]
set_property SLEW      SLOW      [get_ports {qsfp0_reset_l}]
set_property PACKAGE_PIN E14   [get_ports {qsfp0_lpmode}]     ;# HD88_IO_P7   IO_L7P_HDGC_88     QSFP28 pin 31  LPMode
set_property IOSTANDARD LVCMOS33  [get_ports {qsfp0_lpmode}]
set_property DRIVE     8         [get_ports {qsfp0_lpmode}]
set_property SLEW      SLOW      [get_ports {qsfp0_lpmode}]
set_property PACKAGE_PIN C14   [get_ports {qsfp0_modprs_l}]   ;# HD88_IO_P10  IO_L10P_AD10P_88   QSFP28 pin 27  ModPrsL, 4k7 RT200
set_property IOSTANDARD LVCMOS33  [get_ports {qsfp0_modprs_l}]
set_property PACKAGE_PIN D14   [get_ports {qsfp0_int_l}]      ;# HD88_IO_N7   IO_L7N_HDGC_88     QSFP28 pin 28  IntL,    4k7 RT201
set_property IOSTANDARD LVCMOS33  [get_ports {qsfp0_int_l}]

# ---- cage 1 -----------------------------------------------------------------
set_property PACKAGE_PIN D13   [get_ports {qsfp1_scl}]        ;# HD88_IO_P9   IO_L9P_AD11P_88    QSFP28 pin 11  SCL
set_property IOSTANDARD LVCMOS33  [get_ports {qsfp1_scl}]
set_property DRIVE     8         [get_ports {qsfp1_scl}]
set_property SLEW      SLOW      [get_ports {qsfp1_scl}]
set_property PACKAGE_PIN F12   [get_ports {qsfp1_sda}]        ;# HD88_IO_N6   IO_L6N_HDGC_88     QSFP28 pin 12  SDA
set_property IOSTANDARD LVCMOS33  [get_ports {qsfp1_sda}]
set_property DRIVE     8         [get_ports {qsfp1_sda}]
set_property SLEW      SLOW      [get_ports {qsfp1_sda}]
set_property PACKAGE_PIN G12   [get_ports {qsfp1_modsel_l}]   ;# HD88_IO_P6   IO_L6P_HDGC_88     QSFP28 pin 8   ModSelL
set_property IOSTANDARD LVCMOS33  [get_ports {qsfp1_modsel_l}]
set_property DRIVE     8         [get_ports {qsfp1_modsel_l}]
set_property SLEW      SLOW      [get_ports {qsfp1_modsel_l}]
set_property PACKAGE_PIN F13   [get_ports {qsfp1_reset_l}]    ;# HD88_IO_N5   IO_L5N_HDGC_88     QSFP28 pin 9   ResetL
set_property IOSTANDARD LVCMOS33  [get_ports {qsfp1_reset_l}]
set_property DRIVE     8         [get_ports {qsfp1_reset_l}]
set_property SLEW      SLOW      [get_ports {qsfp1_reset_l}]
set_property PACKAGE_PIN G13   [get_ports {qsfp1_lpmode}]     ;# HD88_IO_N4   IO_L4N_AD12N_88    QSFP28 pin 31  LPMode
set_property IOSTANDARD LVCMOS33  [get_ports {qsfp1_lpmode}]
set_property DRIVE     8         [get_ports {qsfp1_lpmode}]
set_property SLEW      SLOW      [get_ports {qsfp1_lpmode}]
set_property PACKAGE_PIN F14   [get_ports {qsfp1_modprs_l}]   ;# HD88_IO_P5   IO_L5P_HDGC_88     QSFP28 pin 27  ModPrsL, 4k7 RT221
set_property IOSTANDARD LVCMOS33  [get_ports {qsfp1_modprs_l}]
set_property PACKAGE_PIN H13   [get_ports {qsfp1_int_l}]      ;# HD88_IO_P4   IO_L4P_AD12P_88    QSFP28 pin 28  IntL,    4k7 RT222
set_property IOSTANDARD LVCMOS33  [get_ports {qsfp1_int_l}]

# CFGMCLK is a free-running internal oscillator, nominally 50 MHz but specified
# only as 30-65 MHz. Constrain it at the fast end so timing is never optimistic.
create_clock -name cfgmclk -period 15.385 [get_pins startup_i/CFGMCLK]
