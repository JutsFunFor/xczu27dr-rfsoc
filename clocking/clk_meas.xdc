#==============================================================================
# clk_meas.xdc  --  pins and clocks for the GTY reference clock counter
#
# Copied from ../ZU27DR_v1.1.xdc. GTY reference clock pins take a PACKAGE_PIN
# and nothing else -- no IOSTANDARD, they are not regular I/O.
#
#   quad 128  GTYE4_COMMON_X0Y1  ->  QSFP cage 0
#   quad 129  GTYE4_COMMON_X0Y2  ->  QSFP cage 1
#==============================================================================

set_property PACKAGE_PIN M28   [get_ports {gty_refclk0p_i[0]}]   ;# MGTREFCLK0P_128
set_property PACKAGE_PIN M29   [get_ports {gty_refclk0n_i[0]}]   ;# MGTREFCLK0N_128
set_property PACKAGE_PIN K28   [get_ports {gty_refclk1p_i[0]}]   ;# MGTREFCLK1P_128
set_property PACKAGE_PIN K29   [get_ports {gty_refclk1n_i[0]}]   ;# MGTREFCLK1N_128
set_property PACKAGE_PIN H28   [get_ports {gty_refclk0p_i[1]}]   ;# MGTREFCLK0P_129
set_property PACKAGE_PIN H29   [get_ports {gty_refclk0n_i[1]}]   ;# MGTREFCLK0N_129
set_property PACKAGE_PIN F28   [get_ports {gty_refclk1p_i[1]}]   ;# MGTREFCLK1P_129
set_property PACKAGE_PIN F29   [get_ports {gty_refclk1n_i[1]}]   ;# MGTREFCLK1N_129

# 6.400 ns = 156.25 MHz, the RC21008B profile used for 10G.
# These periods only tell the timing engine what to close on -- the design
# measures whatever is actually there. If you reprogram the clock chip well
# above 156.25 MHz, raise these so timing is still checked honestly.
create_clock -name gtrefclk0_128 -period 6.400 [get_ports {gty_refclk0p_i[0]}]
create_clock -name gtrefclk1_128 -period 6.400 [get_ports {gty_refclk1p_i[0]}]
create_clock -name gtrefclk0_129 -period 6.400 [get_ports {gty_refclk0p_i[1]}]
create_clock -name gtrefclk1_129 -period 6.400 [get_ports {gty_refclk1p_i[1]}]

# CFGMCLK: internal oscillator, nominally 50 MHz, specified only as 30-65 MHz.
# Constrain at the fast end so timing is never optimistic.
create_clock -name cfgmclk -period 15.385 [get_pins startup_i/CFGMCLK]

# The gate crosses from CFGMCLK into each reference clock domain and the
# counts come back the other way. Both crossings are synchronised in RTL, and
# the domains have no phase relationship, so tell the timing engine that
# rather than letting it try to close paths between them.
set_clock_groups -asynchronous \
    -group [get_clocks cfgmclk] \
    -group [get_clocks gtrefclk0_128 -include_generated_clocks] \
    -group [get_clocks gtrefclk1_128 -include_generated_clocks] \
    -group [get_clocks gtrefclk0_129 -include_generated_clocks] \
    -group [get_clocks gtrefclk1_129 -include_generated_clocks]
