#==============================================================================
# ZU27DR_v1.1.xdc   -   master board constraints, XCZU27DR-v1.1
#
# Device : xczu27dr-fsve1156-1-i   (fsve1156, 1156 balls)
# Covers : every programmable-logic pin this board actually connects -
#          banks 65, 66, 88, 89 (136 I/O) plus the 8 GTY reference clock pins
#          and the GTY quad placement.
#
#------------------------------------------------------------------------------
# HOW TO USE IT
#------------------------------------------------------------------------------
# Vivado's XDC reader rejects Tcl control flow (proc / if / foreach are
# reported as "not supported" and silently skipped), so this file is plain
# set_property lines and CANNOT auto-skip pins your design does not have.
#
#   -> Copy this file into your project and comment out every section your
#      top level does not declare. A set_property on a port that does not
#      exist is a hard error and aborts the rest of the file.
#
# The interface folders in this repository each carry the subset they need,
# already trimmed -- leds/led_top.xdc, qsfp/qsfp_top.xdc and
# clocking/clk_meas.xdc are all copied out of this file. Use those as worked
# examples of what a trimmed subset looks like.
#
#------------------------------------------------------------------------------
# BANK VOLTAGES  -  the part example code out there disagrees about
#------------------------------------------------------------------------------
#   Bank 88 VCCO (E13, H12)          = VCC_ADJ  = 3.3 V   ->  LVCMOS33
#   Bank 89 VCCO (D10, G9)           = VCC_ADJ  = 3.3 V   ->  LVCMOS33
#   Bank 65 VCCO (AF15, AJ14, AK17)  = VCC_AUX  = 1.8 V   ->  LVCMOS18 / LVDS
#   Bank 66 VCCO (AE12, AH11, AL10)  = VCC_AUX  = 1.8 V   ->  LVCMOS18 / LVDS
#
# VCC_ADJ has exactly one source anywhere in the schematic: VCC_3V3 through
# ferrite bead LT14 (100R). The alternate feed from VCC_BANK89 goes through
# LT13, which is marked NC. Both are on page 3, immediately left of the
# HD BANK89 symbol. VCC_AUX is annotated "1.8V" on page 11 where it feeds
# VCCAUX_0/1/2 (L10, N10, R10), and page 3 ties that same net to VCCO_65_*
# and VCCO_66_*.
#
# So any constraint file using LVCMOS18 on A10 / H14 is wrong: those balls sit
# in a 3.3 V bank. It builds and the LEDs light anyway, because the output
# stage still swings to whatever VCCO actually is - Vivado has no way to know
# the board rail without a board file. LVCMOS33 is the correct one.
#
#------------------------------------------------------------------------------
# WHAT IS NOT A SPARE PIN
#------------------------------------------------------------------------------
#   A12        gate of QT2, which switches the RF-DAC AVTT rail 2.5 V <-> 3.0 V
#   B11, C11   D- / D+ of the USB Type-C receptacle JT5
#   14 pins    QSFP28 cage sidebands (2 cages x 7)
# In banks 88/89 the only unencumbered pins are the three LEDs, the six on
# header J7, and the ones that go nowhere but connector JT2.
#
#------------------------------------------------------------------------------
# WHERE EACH FACT COMES FROM
#------------------------------------------------------------------------------
# ball <-> Xilinx pin name
#     the io_placed report from a real routed build, which lists every ball in
#     the package whether the design used it or not
# net  <-> ball
#     XCZU27DR-v1.1.pdf page 3, both bank symbols, read by text geometry.
#     Cross-check: all 150 ball annotations on that page agree with
#     io_placed.rpt, and all 144 nets obey HD88_IO_Pk = IO_LkP_*_88 (same
#     shape for banks 89 / 65 / 66) with zero exceptions.
# net  <-> function
#     page 3   LEDs DT1/DT4/DT5, connectors JT1/JT2, bank VCCO rails
#     page 10  QSFP0 + QSFP1 cages, header J7, USB-C JT5
#     page 11  DAC_AVTT rail select, VCC_AUX = 1.8 V
#     page 12  QSFP0 lanes = GTY bank 128, QSFP1 lanes = GTY bank 129
#     page 15  PT1 "MIPI_DSI" 28-pin header
# GTY refclk balls + quad LOCs
#     an IBERT constraint set for this board, cross-checked against routed
#     10G and 25G builds.
#
# Deliberately NOT here, because they are not XDC-assignable on this device:
#   PS DDR4 and PS MIO (RGMII PHY, USB ULPI, QSPI, SD/eMMC) - these are Zynq
#     PS configuration, not constraints. See ddr4/build.tcl and
#     ethernet/build.tcl, which set them explicitly and write out a psu_init.
#   RF-ADC / RF-DAC tile pins - RF Data Converter IP, "I/O Planning" tab.
#     See adc-dac/build.tcl, which configures the tiles from the IP.
#
# Validated: synth_design + place_design clean on xczu27dr-fsve1156-1-i with a
# top level declaring all 136 ports, 0 DRC violations, WNS +18.2 ns. The LED
# and QSFP subsets have since been confirmed on the board itself - see leds/
# and qsfp/.
#==============================================================================


#==============================================================================
# USER LEDs  -  bank 89 / 88, 3.3 V, active HIGH
#
#   led[0] = DT1 (A10)    led[1] = DT5 (D12)    led[2] = DT4 (H14)
#
# FPGA pin -> LED anode -> 1K -> GND. Driving the pin HIGH lights the LED, and
# nothing else is on the net, so these three are the safest pins on the board to
# experiment with. Schematic page 3, right of the HD bank symbols (DT4/DT5/DT1
# with RT141/RT142/RT139).
#
# This ordering matches the LED[0..2] used by IBERT builds for this board.
#==============================================================================
set_property PACKAGE_PIN A10   [get_ports {led[0]}]            ;# HD89_IO_P3             IO_L3P_AD9P_89                 -  |  DT1
set_property IOSTANDARD LVCMOS33  [get_ports {led[0]}]
set_property DRIVE     8         [get_ports {led[0]}]
set_property SLEW      SLOW      [get_ports {led[0]}]
set_property PACKAGE_PIN D12   [get_ports {led[1]}]            ;# HD88_IO_N8             IO_L8N_HDGC_88                 -  |  DT5
set_property IOSTANDARD LVCMOS33  [get_ports {led[1]}]
set_property DRIVE     8         [get_ports {led[1]}]
set_property SLEW      SLOW      [get_ports {led[1]}]
set_property PACKAGE_PIN H14   [get_ports {led[2]}]            ;# HD88_IO_N2             IO_L2N_AD14N_88                -  |  DT4
set_property IOSTANDARD LVCMOS33  [get_ports {led[2]}]
set_property DRIVE     8         [get_ports {led[2]}]
set_property SLEW      SLOW      [get_ports {led[2]}]
#set_property PACKAGE_PIN A10   [get_ports {LED_DT1}]          ;# HD89_IO_P3             IO_L3P_AD9P_89                 -  |  legacy alias of led[0]
#set_property IOSTANDARD LVCMOS33  [get_ports {LED_DT1}]
#set_property DRIVE     8         [get_ports {LED_DT1}]
#set_property SLEW      SLOW      [get_ports {LED_DT1}]
#set_property PACKAGE_PIN H14   [get_ports {LED_DT4}]          ;# HD88_IO_N2             IO_L2N_AD14N_88                -  |  legacy alias of led[2]
#set_property IOSTANDARD LVCMOS33  [get_ports {LED_DT4}]
#set_property DRIVE     8         [get_ports {LED_DT4}]
#set_property SLEW      SLOW      [get_ports {LED_DT4}]


#==============================================================================
# QSFP28 CAGE SIDEBANDS  -  bank 88, 3.3 V
#
#   qsfp0_*  cage with lanes QSFP_TX/RX*   ->  GTY bank 128  (GTYE4_COMMON_X0Y1)
#   qsfp1_*  cage with lanes QSFP1_TX/RX*  ->  GTY bank 129  (GTYE4_COMMON_X0Y2)
#
# scl / sda must be driven open-drain (an IOBUF whose T you toggle - never drive
# O high). External 4k7 pull-ups to QSFP_VCCT are fitted on scl, sda, modprs_l
# and int_l. modsel_l, reset_l and lpmode have no pull-up, so drive them or the
# module sees an undefined level.
#
# Example code you may come across names E14/B13/G13/F13 qsfp0_lpmode /
# qsfp0_resetn / qsfp1_lpmode / qsfp2_resetn. The first three are right;
# "qsfp2_resetn" is a typo for qsfp1_reset_l - there is no cage 2.
#
# These are the four balls the old project notes flagged as unresolved. They are
# resolved: schematic page 10 draws both cages with their QSFP28 pin numbers
# (8, 9, 11, 12, 27, 28, 31) against these exact nets.
#==============================================================================
set_property PACKAGE_PIN B12   [get_ports {qsfp0_scl}]         ;# HD88_IO_P12            IO_L12P_AD8P_88                -  |  QSFP28 pin 11 SCL      open-drain, 4k7 RT198 to QSFP_VCCT
set_property IOSTANDARD LVCMOS33  [get_ports {qsfp0_scl}]
set_property DRIVE     8         [get_ports {qsfp0_scl}]
set_property SLEW      SLOW      [get_ports {qsfp0_scl}]
set_property PACKAGE_PIN A13   [get_ports {qsfp0_sda}]         ;# HD88_IO_N11            IO_L11N_AD9N_88                -  |  QSFP28 pin 12 SDA      open-drain, 4k7 RT199 to QSFP_VCCT
set_property IOSTANDARD LVCMOS33  [get_ports {qsfp0_sda}]
set_property DRIVE     8         [get_ports {qsfp0_sda}]
set_property SLEW      SLOW      [get_ports {qsfp0_sda}]
set_property PACKAGE_PIN A14   [get_ports {qsfp0_modsel_l}]    ;# HD88_IO_P11            IO_L11P_AD9P_88                -  |  QSFP28 pin 8  ModSelL  drive LOW to talk to this module
set_property IOSTANDARD LVCMOS33  [get_ports {qsfp0_modsel_l}]
set_property DRIVE     8         [get_ports {qsfp0_modsel_l}]
set_property SLEW      SLOW      [get_ports {qsfp0_modsel_l}]
set_property PACKAGE_PIN B13   [get_ports {qsfp0_reset_l}]     ;# HD88_IO_N10            IO_L10N_AD10N_88               -  |  QSFP28 pin 9  ResetL   drive LOW to reset the module
set_property IOSTANDARD LVCMOS33  [get_ports {qsfp0_reset_l}]
set_property DRIVE     8         [get_ports {qsfp0_reset_l}]
set_property SLEW      SLOW      [get_ports {qsfp0_reset_l}]
set_property PACKAGE_PIN C14   [get_ports {qsfp0_modprs_l}]    ;# HD88_IO_P10            IO_L10P_AD10P_88               -  |  QSFP28 pin 27 ModPrsL  LOW = module present, 4k7 RT200
set_property IOSTANDARD LVCMOS33  [get_ports {qsfp0_modprs_l}]
set_property PACKAGE_PIN D14   [get_ports {qsfp0_int_l}]       ;# HD88_IO_N7             IO_L7N_HDGC_88                 -  |  QSFP28 pin 28 IntL     LOW = interrupt, 4k7 RT201
set_property IOSTANDARD LVCMOS33  [get_ports {qsfp0_int_l}]
set_property PACKAGE_PIN E14   [get_ports {qsfp0_lpmode}]      ;# HD88_IO_P7             IO_L7P_HDGC_88                 -  |  QSFP28 pin 31 LPMode   HIGH = low power mode
set_property IOSTANDARD LVCMOS33  [get_ports {qsfp0_lpmode}]
set_property DRIVE     8         [get_ports {qsfp0_lpmode}]
set_property SLEW      SLOW      [get_ports {qsfp0_lpmode}]
set_property PACKAGE_PIN D13   [get_ports {qsfp1_scl}]         ;# HD88_IO_P9             IO_L9P_AD11P_88                -  |  QSFP28 pin 11 SCL      open-drain, 4k7 RT219 to QSFP_VCCT
set_property IOSTANDARD LVCMOS33  [get_ports {qsfp1_scl}]
set_property DRIVE     8         [get_ports {qsfp1_scl}]
set_property SLEW      SLOW      [get_ports {qsfp1_scl}]
set_property PACKAGE_PIN F12   [get_ports {qsfp1_sda}]         ;# HD88_IO_N6             IO_L6N_HDGC_88                 -  |  QSFP28 pin 12 SDA      open-drain, 4k7 RT220 to QSFP_VCCT
set_property IOSTANDARD LVCMOS33  [get_ports {qsfp1_sda}]
set_property DRIVE     8         [get_ports {qsfp1_sda}]
set_property SLEW      SLOW      [get_ports {qsfp1_sda}]
set_property PACKAGE_PIN G12   [get_ports {qsfp1_modsel_l}]    ;# HD88_IO_P6             IO_L6P_HDGC_88                 -  |  QSFP28 pin 8  ModSelL  drive LOW to talk to this module
set_property IOSTANDARD LVCMOS33  [get_ports {qsfp1_modsel_l}]
set_property DRIVE     8         [get_ports {qsfp1_modsel_l}]
set_property SLEW      SLOW      [get_ports {qsfp1_modsel_l}]
set_property PACKAGE_PIN F13   [get_ports {qsfp1_reset_l}]     ;# HD88_IO_N5             IO_L5N_HDGC_88                 -  |  QSFP28 pin 9  ResetL   drive LOW to reset the module
set_property IOSTANDARD LVCMOS33  [get_ports {qsfp1_reset_l}]
set_property DRIVE     8         [get_ports {qsfp1_reset_l}]
set_property SLEW      SLOW      [get_ports {qsfp1_reset_l}]
set_property PACKAGE_PIN F14   [get_ports {qsfp1_modprs_l}]    ;# HD88_IO_P5             IO_L5P_HDGC_88                 -  |  QSFP28 pin 27 ModPrsL  LOW = module present, 4k7 RT221
set_property IOSTANDARD LVCMOS33  [get_ports {qsfp1_modprs_l}]
set_property PACKAGE_PIN H13   [get_ports {qsfp1_int_l}]       ;# HD88_IO_P4             IO_L4P_AD12P_88                -  |  QSFP28 pin 28 IntL     LOW = interrupt, 4k7 RT222
set_property IOSTANDARD LVCMOS33  [get_ports {qsfp1_int_l}]
set_property PACKAGE_PIN G13   [get_ports {qsfp1_lpmode}]      ;# HD88_IO_N4             IO_L4N_AD12N_88                -  |  QSFP28 pin 31 LPMode   HIGH = low power mode
set_property IOSTANDARD LVCMOS33  [get_ports {qsfp1_lpmode}]
set_property DRIVE     8         [get_ports {qsfp1_lpmode}]
set_property SLEW      SLOW      [get_ports {qsfp1_lpmode}]
#set_property PACKAGE_PIN B13   [get_ports {qsfp0_resetn}]     ;# HD88_IO_N10            IO_L10N_AD10N_88               -  |  legacy alias of qsfp0_reset_l
#set_property IOSTANDARD LVCMOS33  [get_ports {qsfp0_resetn}]
#set_property DRIVE     8         [get_ports {qsfp0_resetn}]
#set_property SLEW      SLOW      [get_ports {qsfp0_resetn}]
#set_property PACKAGE_PIN F13   [get_ports {qsfp2_resetn}]     ;# HD88_IO_N5             IO_L5N_HDGC_88                 -  |  legacy alias of qsfp1_reset_l (misnamed, there is no cage 2)
#set_property IOSTANDARD LVCMOS33  [get_ports {qsfp2_resetn}]
#set_property DRIVE     8         [get_ports {qsfp2_resetn}]
#set_property SLEW      SLOW      [get_ports {qsfp2_resetn}]


#==============================================================================
# J7  -  9-pin user header, TOP side, banks 88/89, 3.3 V
#
#   J7.1 = VCC5V    J7.2 = GND    J7.3 = VCC_3V3    J7.4..J7.9 = FPGA I/O
#
# The only free, top-side, probeable FPGA pins on the module. Use these (and the
# LEDs) for hardware bring-up. Also present on JT2 pins 1,3,5,7,9,11.
#==============================================================================
set_property PACKAGE_PIN K15   [get_ports {j7_io4}]            ;# HD88_IO_P1             IO_L1P_AD15P_88                J7.4 JT2.1  |  header pin 4
set_property IOSTANDARD LVCMOS33  [get_ports {j7_io4}]
set_property PACKAGE_PIN K14   [get_ports {j7_io5}]            ;# HD88_IO_N1             IO_L1N_AD15N_88                J7.5 JT2.3  |  header pin 5
set_property IOSTANDARD LVCMOS33  [get_ports {j7_io5}]
set_property PACKAGE_PIN J14   [get_ports {j7_io6}]            ;# HD88_IO_P3             IO_L3P_AD13P_88                J7.6 JT2.5  |  header pin 6
set_property IOSTANDARD LVCMOS33  [get_ports {j7_io6}]
set_property PACKAGE_PIN J13   [get_ports {j7_io7}]            ;# HD88_IO_N3             IO_L3N_AD13N_88                J7.7 JT2.7  |  header pin 7
set_property IOSTANDARD LVCMOS33  [get_ports {j7_io7}]
set_property PACKAGE_PIN J12   [get_ports {j7_io8}]            ;# HD89_IO_N12            IO_L12N_AD0N_89                J7.8 JT2.9  |  header pin 8
set_property IOSTANDARD LVCMOS33  [get_ports {j7_io8}]
set_property PACKAGE_PIN K12   [get_ports {j7_io9}]            ;# HD89_IO_P12            IO_L12P_AD0P_89                J7.9 JT2.11  |  header pin 9
set_property IOSTANDARD LVCMOS33  [get_ports {j7_io9}]


#==============================================================================
# PT1  -  28-pin header silkscreened "MIPI_DSI", TOP side
#
# Inherited from the RK3576 board this schematic was copied from, but it is a
# populated header carrying real FPGA pins: seven single-ended bank 89 pins at
# 3.3 V and five differential-capable bank 65 pairs at 1.8 V.
#
# PT1.4 / PT1.5 carry 4k7 pull-ups (RT230 / RT231) - they were the panel I2C.
# PT1 pins 1, 2, 9, 12, 15, 18, 21, 24, 26, 27, 28 are power / ground.
#
# The five bank 65 pairs are listed here at LVCMOS18. To use one differentially
# instead, delete its two single-ended lines and uncomment the LVDS pair below -
# one ball can only carry one port.
#==============================================================================
set_property PACKAGE_PIN F10   [get_ports {pt1_io3}]           ;# HD89_IO_P7             IO_L7P_HDGC_AD5P_89            PT1.3 JT2.34  |  header pin 3
set_property IOSTANDARD LVCMOS33  [get_ports {pt1_io3}]
set_property PACKAGE_PIN C9    [get_ports {pt1_io4}]           ;# HD89_IO_N4             IO_L4N_AD8N_89                 PT1.4 JT2.36  |  header pin 4
set_property IOSTANDARD LVCMOS33  [get_ports {pt1_io4}]
set_property PACKAGE_PIN D9    [get_ports {pt1_io5}]           ;# HD89_IO_P4             IO_L4P_AD8P_89                 PT1.5 JT2.38  |  header pin 5
set_property IOSTANDARD LVCMOS33  [get_ports {pt1_io5}]
set_property PACKAGE_PIN A9    [get_ports {pt1_io6}]           ;# HD89_IO_N3             IO_L3N_AD9N_89                 PT1.6 JT2.40  |  header pin 6
set_property IOSTANDARD LVCMOS33  [get_ports {pt1_io6}]
set_property PACKAGE_PIN B10   [get_ports {pt1_io7}]           ;# HD89_IO_N2             IO_L2N_AD10N_89                PT1.7 JT2.42  |  header pin 7
set_property IOSTANDARD LVCMOS33  [get_ports {pt1_io7}]
set_property PACKAGE_PIN C10   [get_ports {pt1_io8}]           ;# HD89_IO_P2             IO_L2P_AD10P_89                PT1.8 JT2.44  |  header pin 8
set_property IOSTANDARD LVCMOS33  [get_ports {pt1_io8}]
set_property PACKAGE_PIN F9    [get_ports {pt1_io25}]          ;# HD89_IO_N7             IO_L7N_HDGC_AD5N_89            PT1.25 JT2.32  |  header pin 25
set_property IOSTANDARD LVCMOS33  [get_ports {pt1_io25}]
set_property PACKAGE_PIN AD15  [get_ports {pt1_pair0_p}]       ;# HP65_IO_P21            IO_L21P_T3L_N4_AD8P_65         PT1.10 JT1.108  |  header pin 10
set_property IOSTANDARD LVCMOS18  [get_ports {pt1_pair0_p}]
set_property PACKAGE_PIN AE15  [get_ports {pt1_pair0_n}]       ;# HP65_IO_N21            IO_L21N_T3L_N5_AD8N_65         PT1.11 JT1.106  |  header pin 11
set_property IOSTANDARD LVCMOS18  [get_ports {pt1_pair0_n}]
set_property PACKAGE_PIN AE16  [get_ports {pt1_pair1_p}]       ;# HP65_IO_P17            IO_L17P_T2U_N8_AD10P_65        PT1.13 JT1.104  |  header pin 13
set_property IOSTANDARD LVCMOS18  [get_ports {pt1_pair1_p}]
set_property PACKAGE_PIN AF16  [get_ports {pt1_pair1_n}]       ;# HP65_IO_N17            IO_L17N_T2U_N9_AD10N_65        PT1.14 JT1.102  |  header pin 14
set_property IOSTANDARD LVCMOS18  [get_ports {pt1_pair1_n}]
set_property PACKAGE_PIN AF18  [get_ports {pt1_pair2_p}]       ;# HP65_IO_P18            IO_L18P_T2U_N10_AD2P_65        PT1.16 JT1.98  |  header pin 16
set_property IOSTANDARD LVCMOS18  [get_ports {pt1_pair2_p}]
set_property PACKAGE_PIN AF17  [get_ports {pt1_pair2_n}]       ;# HP65_IO_N18            IO_L18N_T2U_N11_AD2N_65        PT1.17 JT1.96  |  header pin 17
set_property IOSTANDARD LVCMOS18  [get_ports {pt1_pair2_n}]
set_property PACKAGE_PIN AG17  [get_ports {pt1_pair3_p}]       ;# HP65_IO_P14            IO_L14P_T2L_N2_GC_65           PT1.19 JT1.94  |  header pin 19
set_property IOSTANDARD LVCMOS18  [get_ports {pt1_pair3_p}]
set_property PACKAGE_PIN AH17  [get_ports {pt1_pair3_n}]       ;# HP65_IO_N14            IO_L14N_T2L_N3_GC_65           PT1.20 JT1.92  |  header pin 20
set_property IOSTANDARD LVCMOS18  [get_ports {pt1_pair3_n}]
set_property PACKAGE_PIN AG15  [get_ports {pt1_pair4_p}]       ;# HP65_IO_P13            IO_L13P_T2L_N0_GC_QBC_65       PT1.22 JT1.88  |  header pin 22
set_property IOSTANDARD LVCMOS18  [get_ports {pt1_pair4_p}]
set_property PACKAGE_PIN AH15  [get_ports {pt1_pair4_n}]       ;# HP65_IO_N13            IO_L13N_T2L_N1_GC_QBC_65       PT1.23 JT1.86  |  header pin 23
set_property IOSTANDARD LVCMOS18  [get_ports {pt1_pair4_n}]

# Differential alternative for the five bank 65 pairs:
#set_property PACKAGE_PIN AD15  [get_ports {pt1_pair0_p}] ;# PT1.10
#set_property PACKAGE_PIN AE15  [get_ports {pt1_pair0_n}] ;# PT1.11
#set_property IOSTANDARD LVDS [get_ports {pt1_pair0_p pt1_pair0_n}]
#set_property PACKAGE_PIN AE16  [get_ports {pt1_pair1_p}] ;# PT1.13
#set_property PACKAGE_PIN AF16  [get_ports {pt1_pair1_n}] ;# PT1.14
#set_property IOSTANDARD LVDS [get_ports {pt1_pair1_p pt1_pair1_n}]
#set_property PACKAGE_PIN AF18  [get_ports {pt1_pair2_p}] ;# PT1.16
#set_property PACKAGE_PIN AF17  [get_ports {pt1_pair2_n}] ;# PT1.17
#set_property IOSTANDARD LVDS [get_ports {pt1_pair2_p pt1_pair2_n}]
#set_property PACKAGE_PIN AG17  [get_ports {pt1_pair3_p}] ;# PT1.19
#set_property PACKAGE_PIN AH17  [get_ports {pt1_pair3_n}] ;# PT1.20
#set_property IOSTANDARD LVDS [get_ports {pt1_pair3_p pt1_pair3_n}]
#set_property PACKAGE_PIN AG15  [get_ports {pt1_pair4_p}] ;# PT1.22
#set_property PACKAGE_PIN AH15  [get_ports {pt1_pair4_n}] ;# PT1.23
#set_property IOSTANDARD LVDS [get_ports {pt1_pair4_p pt1_pair4_n}]


#==============================================================================
# PINS WITH A HARDWARE CONSEQUENCE  -  read before enabling these
#
# dac_avtt_sel (A12)
#   Not a spare pin. It drives the gate of QT2 (WNM6002-3) through 100R RT223.
#   QT2 switches RT207 + RT206 (10K + 24K) across the lower leg of the feedback
#   divider of UT64, the TPS74801 LDO (Vref 0.8 V) that generates DAC_AVTT:
#
#       A12 low  / QT2 off :  0.8 * (1 + 21.25K / 10K)         = 2.5 V
#       A12 high / QT2 on  :  0.8 * (1 + 21.25K / (10K||34K))  = 3.0 V
#
#   which is exactly the schematic's own note "20mA=2.5V / 30mA=3.0V" - it picks
#   the RF-DAC full-scale output current range. The gate has NO pull-down, so an
#   unused A12 leaves that gate floating. If you are not switching the rail on
#   purpose, either declare this port and tie it to 0, or set
#   BITSTREAM.CONFIG.UNUSEDPIN PULLDOWN (see the end of this file).
#
# usb2_dp / usb2_dm (C11 / B11)
#   Wired straight to the D+ / D- contacts of USB Type-C receptacle JT5. If a
#   cable is plugged in there is another driver on the net. Only enable these if
#   you know the port is empty, or if you are deliberately bit-banging USB.
#==============================================================================
set_property PACKAGE_PIN A12   [get_ports {dac_avtt_sel}]      ;# HD88_IO_N12            IO_L12N_AD8N_88                -  |  RF-DAC AVTT rail select - LOW = 2.5 V, HIGH = 3.0 V
set_property IOSTANDARD LVCMOS33  [get_ports {dac_avtt_sel}]
set_property DRIVE     4         [get_ports {dac_avtt_sel}]
set_property SLEW      SLOW      [get_ports {dac_avtt_sel}]
set_property PULLTYPE  PULLDOWN  [get_ports {dac_avtt_sel}]
set_property PACKAGE_PIN C11   [get_ports {usb2_dp}]           ;# HD89_IO_P1             IO_L1P_AD11P_89                -  |  USB-C JT5 contact T3 (D+)
set_property IOSTANDARD LVCMOS33  [get_ports {usb2_dp}]
set_property PACKAGE_PIN B11   [get_ports {usb2_dm}]           ;# HD89_IO_N1             IO_L1N_AD11N_89                -  |  USB-C JT5 contact T2 (D-)
set_property IOSTANDARD LVCMOS33  [get_ports {usb2_dm}]


#==============================================================================
# JT2  -  120-pin BOTTOM-side board-to-board connector (FCI 61082-121400LF)
#         bank 88/89 pins with no on-module function, 3.3 V
#
# JT1 and JT2 are populated on the BOTTOM of the PCB: this is a module meant to
# stack onto a carrier. (Earlier notes on this board dismissed them as leftover
# template symbols - BOT-CENTER.pdf shows both 120-pin footprints, so they are
# real hardware.) Port names carry the connector pin number.
#
# JT2 also carries PS MIO signals, PS_POR_B, POWER_SW, VBAT_IN and copies of the
# GTY128/129 reference clocks. Those are not PL pins, so they cannot be
# constrained here.
#==============================================================================
set_property PACKAGE_PIN K11   [get_ports {jt2_p15}]           ;# HD89_IO_P10            IO_L10P_AD2P_89                JT2.15  |  connector pin 15
set_property IOSTANDARD LVCMOS33  [get_ports {jt2_p15}]
set_property PACKAGE_PIN K10   [get_ports {jt2_p17}]           ;# HD89_IO_N10            IO_L10N_AD2N_89                JT2.17  |  connector pin 17
set_property IOSTANDARD LVCMOS33  [get_ports {jt2_p17}]
set_property PACKAGE_PIN H10   [get_ports {jt2_p19}]           ;# HD89_IO_P9             IO_L9P_AD3P_89                 JT2.19  |  connector pin 19
set_property IOSTANDARD LVCMOS33  [get_ports {jt2_p19}]
set_property PACKAGE_PIN H9    [get_ports {jt2_p21}]           ;# HD89_IO_N9             IO_L9N_AD3N_89                 JT2.21  |  connector pin 21
set_property IOSTANDARD LVCMOS33  [get_ports {jt2_p21}]
set_property PACKAGE_PIN J11   [get_ports {jt2_p23}]           ;# HD89_IO_P11            IO_L11P_AD1P_89                JT2.23  |  connector pin 23
set_property IOSTANDARD LVCMOS33  [get_ports {jt2_p23}]
set_property PACKAGE_PIN H11   [get_ports {jt2_p25}]           ;# HD89_IO_N11            IO_L11N_AD1N_89                JT2.25  |  connector pin 25
set_property IOSTANDARD LVCMOS33  [get_ports {jt2_p25}]
set_property PACKAGE_PIN E9    [get_ports {jt2_p27}]           ;# HD89_IO_N6             IO_L6N_HDGC_AD6N_89            JT2.27  |  connector pin 27
set_property IOSTANDARD LVCMOS33  [get_ports {jt2_p27}]
set_property PACKAGE_PIN E10   [get_ports {jt2_p29}]           ;# HD89_IO_P6             IO_L6P_HDGC_AD6P_89            JT2.29  |  connector pin 29
set_property IOSTANDARD LVCMOS33  [get_ports {jt2_p29}]
set_property PACKAGE_PIN G10   [get_ports {jt2_p33}]           ;# HD89_IO_N8             IO_L8N_HDGC_AD4N_89            JT2.33  |  connector pin 33
set_property IOSTANDARD LVCMOS33  [get_ports {jt2_p33}]
set_property PACKAGE_PIN G11   [get_ports {jt2_p35}]           ;# HD89_IO_P8             IO_L8P_HDGC_AD4P_89            JT2.35  |  connector pin 35
set_property IOSTANDARD LVCMOS33  [get_ports {jt2_p35}]
set_property PACKAGE_PIN D11   [get_ports {jt2_p37}]           ;# HD89_IO_N5             IO_L5N_HDGC_AD7N_89            JT2.37  |  connector pin 37
set_property IOSTANDARD LVCMOS33  [get_ports {jt2_p37}]
set_property PACKAGE_PIN E11   [get_ports {jt2_p39}]           ;# HD89_IO_P5             IO_L5P_HDGC_AD7P_89            JT2.39  |  connector pin 39
set_property IOSTANDARD LVCMOS33  [get_ports {jt2_p39}]
set_property PACKAGE_PIN E12   [get_ports {jt2_p41}]           ;# HD88_IO_P8             IO_L8P_HDGC_88                 JT2.41  |  connector pin 41
set_property IOSTANDARD LVCMOS33  [get_ports {jt2_p41}]
set_property PACKAGE_PIN C13   [get_ports {jt2_p43}]           ;# HD88_IO_N9             IO_L9N_AD11N_88                JT2.43  |  connector pin 43
set_property IOSTANDARD LVCMOS33  [get_ports {jt2_p43}]
set_property PACKAGE_PIN H15   [get_ports {jt2_p63}]           ;# HD88_IO_P2             IO_L2P_AD14P_88                JT2.63  |  connector pin 63
set_property IOSTANDARD LVCMOS33  [get_ports {jt2_p63}]


#==============================================================================
# BANK 66  -  1.8 V, every I/O reaches only JT1 (bottom-side carrier connector)
#
# Port names mirror the schematic net names: hp66_p7 is the net drawn as
# HP_IO_P7 on page 3. Comments give the Xilinx pin name and the JT1 pin.
#
# High Performance bank: 1.8 V is the ceiling. LVCMOS18 is set here; swap to
# LVDS (or DIFF_SSTL etc.) on a P/N pair if you want a differential link.
# Global-clock-capable pairs in this bank: L11, L12, L13, L14.
#==============================================================================
set_property PACKAGE_PIN AP8   [get_ports {hp66_p1}]           ;# HP_IO_P1               IO_L1P_T0L_N0_DBC_66           JT1.75
set_property IOSTANDARD LVCMOS18  [get_ports {hp66_p1}]
set_property PACKAGE_PIN AP7   [get_ports {hp66_n1}]           ;# HP_IO_N1               IO_L1N_T0L_N1_DBC_66           JT1.77
set_property IOSTANDARD LVCMOS18  [get_ports {hp66_n1}]
set_property PACKAGE_PIN AP6   [get_ports {hp66_p2}]           ;# HP_IO_P2               IO_L2P_T0L_N2_66               JT1.81
set_property IOSTANDARD LVCMOS18  [get_ports {hp66_p2}]
set_property PACKAGE_PIN AP5   [get_ports {hp66_n2}]           ;# HP_IO_N2               IO_L2N_T0L_N3_66               JT1.83
set_property IOSTANDARD LVCMOS18  [get_ports {hp66_n2}]
set_property PACKAGE_PIN AM6   [get_ports {hp66_p3}]           ;# HP_IO_P3               IO_L3P_T0L_N4_AD15P_66         JT1.17
set_property IOSTANDARD LVCMOS18  [get_ports {hp66_p3}]
set_property PACKAGE_PIN AM5   [get_ports {hp66_n3}]           ;# HP_IO_N3               IO_L3N_T0L_N5_AD15N_66         JT1.15
set_property IOSTANDARD LVCMOS18  [get_ports {hp66_n3}]
set_property PACKAGE_PIN AN5   [get_ports {hp66_p4}]           ;# HP_IO_P4               IO_L4P_T0U_N6_DBC_AD7P_66      JT1.13
set_property IOSTANDARD LVCMOS18  [get_ports {hp66_p4}]
set_property PACKAGE_PIN AN4   [get_ports {hp66_n4}]           ;# HP_IO_N4               IO_L4N_T0U_N7_DBC_AD7N_66      JT1.11
set_property IOSTANDARD LVCMOS18  [get_ports {hp66_n4}]
set_property PACKAGE_PIN AP3   [get_ports {hp66_p5}]           ;# HP_IO_P5               IO_L5P_T0U_N8_AD14P_66         JT1.78
set_property IOSTANDARD LVCMOS18  [get_ports {hp66_p5}]
set_property PACKAGE_PIN AP2   [get_ports {hp66_n5}]           ;# HP_IO_N5               IO_L5N_T0U_N9_AD14N_66         JT1.76
set_property IOSTANDARD LVCMOS18  [get_ports {hp66_n5}]
set_property PACKAGE_PIN AN2   [get_ports {hp66_p6}]           ;# HP_IO_P6               IO_L6P_T0U_N10_AD6P_66         JT1.72
set_property IOSTANDARD LVCMOS18  [get_ports {hp66_p6}]
set_property PACKAGE_PIN AN1   [get_ports {hp66_n6}]           ;# HP_IO_N6               IO_L6N_T0U_N11_AD6N_66         JT1.74
set_property IOSTANDARD LVCMOS18  [get_ports {hp66_n6}]
set_property PACKAGE_PIN AP13  [get_ports {hp66_p7}]           ;# HP_IO_P7               IO_L7P_T1L_N0_QBC_AD13P_66     JT1.65
set_property IOSTANDARD LVCMOS18  [get_ports {hp66_p7}]
set_property PACKAGE_PIN AP12  [get_ports {hp66_n7}]           ;# HP_IO_N7               IO_L7N_T1L_N1_QBC_AD13N_66     JT1.67
set_property IOSTANDARD LVCMOS18  [get_ports {hp66_n7}]
set_property PACKAGE_PIN AN13  [get_ports {hp66_p8}]           ;# HP_IO_P8               IO_L8P_T1L_N2_AD5P_66          JT1.53
set_property IOSTANDARD LVCMOS18  [get_ports {hp66_p8}]
set_property PACKAGE_PIN AN12  [get_ports {hp66_n8}]           ;# HP_IO_N8               IO_L8N_T1L_N3_AD5N_66          JT1.51
set_property IOSTANDARD LVCMOS18  [get_ports {hp66_n8}]
set_property PACKAGE_PIN AN8   [get_ports {hp66_p9}]           ;# HP_IO_P9               IO_L9P_T1L_N4_AD12P_66         JT1.27
set_property IOSTANDARD LVCMOS18  [get_ports {hp66_p9}]
set_property PACKAGE_PIN AN7   [get_ports {hp66_n9}]           ;# HP_IO_N9               IO_L9N_T1L_N5_AD12N_66         JT1.25
set_property IOSTANDARD LVCMOS18  [get_ports {hp66_n9}]
set_property PACKAGE_PIN AM8   [get_ports {hp66_p10}]          ;# HP_IO_P10              IO_L10P_T1U_N6_QBC_AD4P_66     JT1.23
set_property IOSTANDARD LVCMOS18  [get_ports {hp66_p10}]
set_property PACKAGE_PIN AM7   [get_ports {hp66_n10}]          ;# HP_IO_N10              IO_L10N_T1U_N7_QBC_AD4N_66     JT1.21
set_property IOSTANDARD LVCMOS18  [get_ports {hp66_n10}]
set_property PACKAGE_PIN AP11  [get_ports {hp66_p11}]          ;# HP_IO_P11              IO_L11P_T1U_N8_GC_66           JT1.71
set_property IOSTANDARD LVCMOS18  [get_ports {hp66_p11}]
set_property PACKAGE_PIN AP10  [get_ports {hp66_n11}]          ;# HP_IO_N11              IO_L11N_T1U_N9_GC_66           JT1.73
set_property IOSTANDARD LVCMOS18  [get_ports {hp66_n11}]
set_property PACKAGE_PIN AM10  [get_ports {hp66_p12}]          ;# HP_IO_P12              IO_L12P_T1U_N10_GC_66          JT1.35
set_property IOSTANDARD LVCMOS18  [get_ports {hp66_p12}]
set_property PACKAGE_PIN AN10  [get_ports {hp66_n12}]          ;# HP_IO_N12              IO_L12N_T1U_N11_GC_66          JT1.37
set_property IOSTANDARD LVCMOS18  [get_ports {hp66_n12}]
set_property PACKAGE_PIN AL9   [get_ports {hp66_p13}]          ;# HP_IO_P13              IO_L13P_T2L_N0_GC_QBC_66       JT1.31
set_property IOSTANDARD LVCMOS18  [get_ports {hp66_p13}]
set_property PACKAGE_PIN AM9   [get_ports {hp66_n13}]          ;# HP_IO_N13              IO_L13N_T2L_N1_GC_QBC_66       JT1.33
set_property IOSTANDARD LVCMOS18  [get_ports {hp66_n13}]
set_property PACKAGE_PIN AM12  [get_ports {hp66_p14}]          ;# HP_IO_P14              IO_L14P_T2L_N2_GC_66           JT1.47
set_property IOSTANDARD LVCMOS18  [get_ports {hp66_p14}]
set_property PACKAGE_PIN AM11  [get_ports {hp66_n14}]          ;# HP_IO_N14              IO_L14N_T2L_N3_GC_66           JT1.45
set_property IOSTANDARD LVCMOS18  [get_ports {hp66_n14}]
set_property PACKAGE_PIN AK13  [get_ports {hp66_p15}]          ;# HP_IO_P15              IO_L15P_T2L_N4_AD11P_66        JT1.52
set_property IOSTANDARD LVCMOS18  [get_ports {hp66_p15}]
set_property PACKAGE_PIN AL13  [get_ports {hp66_n15}]          ;# HP_IO_N15              IO_L15N_T2L_N5_AD11N_66        JT1.54
set_property IOSTANDARD LVCMOS18  [get_ports {hp66_n15}]
set_property PACKAGE_PIN AL12  [get_ports {hp66_p16}]          ;# HP_IO_P16              IO_L16P_T2U_N6_QBC_AD3P_66     JT1.43
set_property IOSTANDARD LVCMOS18  [get_ports {hp66_p16}]
set_property PACKAGE_PIN AL11  [get_ports {hp66_n16}]          ;# HP_IO_N16              IO_L16N_T2U_N7_QBC_AD3N_66     JT1.41
set_property IOSTANDARD LVCMOS18  [get_ports {hp66_n16}]
set_property PACKAGE_PIN AK10  [get_ports {hp66_p17}]          ;# HP_IO_P17              IO_L17P_T2U_N8_AD10P_66        JT1.44
set_property IOSTANDARD LVCMOS18  [get_ports {hp66_p17}]
set_property PACKAGE_PIN AK9   [get_ports {hp66_n17}]          ;# HP_IO_N17              IO_L17N_T2U_N9_AD10N_66        JT1.42
set_property IOSTANDARD LVCMOS18  [get_ports {hp66_n17}]
set_property PACKAGE_PIN AJ11  [get_ports {hp66_p18}]          ;# HP_IO_P18              IO_L18P_T2U_N10_AD2P_66        JT1.5
set_property IOSTANDARD LVCMOS18  [get_ports {hp66_p18}]
set_property PACKAGE_PIN AK11  [get_ports {hp66_n18}]          ;# HP_IO_N18              IO_L18N_T2U_N11_AD2N_66        JT1.7
set_property IOSTANDARD LVCMOS18  [get_ports {hp66_n18}]
set_property PACKAGE_PIN AG12  [get_ports {hp66_p19}]          ;# HP_IO_P19              IO_L19P_T3L_N0_DBC_AD9P_66     JT1.34
set_property IOSTANDARD LVCMOS18  [get_ports {hp66_p19}]
set_property PACKAGE_PIN AG11  [get_ports {hp66_n19}]          ;# HP_IO_N19              IO_L19N_T3L_N1_DBC_AD9N_66     JT1.32
set_property IOSTANDARD LVCMOS18  [get_ports {hp66_n19}]
set_property PACKAGE_PIN AH10  [get_ports {hp66_p20}]          ;# HP_IO_P20              IO_L20P_T3L_N2_AD1P_66         JT1.3
set_property IOSTANDARD LVCMOS18  [get_ports {hp66_p20}]
set_property PACKAGE_PIN AH9   [get_ports {hp66_n20}]          ;# HP_IO_N20              IO_L20N_T3L_N3_AD1N_66         JT1.1
set_property IOSTANDARD LVCMOS18  [get_ports {hp66_n20}]
set_property PACKAGE_PIN AG10  [get_ports {hp66_p21}]          ;# HP_IO_P21              IO_L21P_T3L_N4_AD8P_66         JT1.28
set_property IOSTANDARD LVCMOS18  [get_ports {hp66_p21}]
set_property PACKAGE_PIN AG9   [get_ports {hp66_n21}]          ;# HP_IO_N21              IO_L21N_T3L_N5_AD8N_66         JT1.26
set_property IOSTANDARD LVCMOS18  [get_ports {hp66_n21}]
set_property PACKAGE_PIN AJ10  [get_ports {hp66_p22}]          ;# HP_IO_P22              IO_L22P_T3U_N6_DBC_AD0P_66     JT1.38
set_property IOSTANDARD LVCMOS18  [get_ports {hp66_p22}]
set_property PACKAGE_PIN AJ9   [get_ports {hp66_n22}]          ;# HP_IO_N22              IO_L22N_T3U_N7_DBC_AD0N_66     JT1.36
set_property IOSTANDARD LVCMOS18  [get_ports {hp66_n22}]
set_property PACKAGE_PIN AF12  [get_ports {hp66_p23}]          ;# HP_IO_P23              IO_L23P_T3U_N8_66              JT1.16
set_property IOSTANDARD LVCMOS18  [get_ports {hp66_p23}]
set_property PACKAGE_PIN AF11  [get_ports {hp66_n23}]          ;# HP_IO_N23              IO_L23N_T3U_N9_66              JT1.18
set_property IOSTANDARD LVCMOS18  [get_ports {hp66_n23}]


#==============================================================================
# BANK 65  -  1.8 V. 38 I/O reach only JT1. The five pairs L13 L14 L17 L18 L21
# are ALSO wired to header PT1 and are already constrained in the PT1 section,
# so they appear here commented out - enable them here only if you delete the
# matching pt1_pair* lines above.
# Global-clock-capable pairs in this bank: L11, L12, L13, L14.
#==============================================================================
set_property PACKAGE_PIN AM14  [get_ports {hp65_p1}]           ;# HP65_IO_P1             IO_L1P_T0L_N0_DBC_65           JT1.55
set_property IOSTANDARD LVCMOS18  [get_ports {hp65_p1}]
set_property PACKAGE_PIN AN14  [get_ports {hp65_n1}]           ;# HP65_IO_N1             IO_L1N_T0L_N1_DBC_65           JT1.57
set_property IOSTANDARD LVCMOS18  [get_ports {hp65_n1}]
set_property PACKAGE_PIN AM15  [get_ports {hp65_p2}]           ;# HP65_IO_P2             IO_L2P_T0L_N2_65               JT1.61
set_property IOSTANDARD LVCMOS18  [get_ports {hp65_p2}]
set_property PACKAGE_PIN AN15  [get_ports {hp65_n2}]           ;# HP65_IO_N2             IO_L2N_T0L_N3_65               JT1.63
set_property IOSTANDARD LVCMOS18  [get_ports {hp65_n2}]
set_property PACKAGE_PIN AP16  [get_ports {hp65_p3}]           ;# HP65_IO_P3             IO_L3P_T0L_N4_AD15P_65         JT1.87
set_property IOSTANDARD LVCMOS18  [get_ports {hp65_p3}]
set_property PACKAGE_PIN AP15  [get_ports {hp65_n3}]           ;# HP65_IO_N3             IO_L3N_T0L_N5_AD15N_65         JT1.85
set_property IOSTANDARD LVCMOS18  [get_ports {hp65_n3}]
set_property PACKAGE_PIN AL17  [get_ports {hp65_p4}]           ;# HP65_IO_P4             IO_L4P_T0U_N6_DBC_AD7P_SMBALERT_65 JT1.97
set_property IOSTANDARD LVCMOS18  [get_ports {hp65_p4}]
set_property PACKAGE_PIN AM16  [get_ports {hp65_n4}]           ;# HP65_IO_N4             IO_L4N_T0U_N7_DBC_AD7N_65      JT1.95
set_property IOSTANDARD LVCMOS18  [get_ports {hp65_n4}]
set_property PACKAGE_PIN AM17  [get_ports {hp65_p5}]           ;# HP65_IO_P5             IO_L5P_T0U_N8_AD14P_65         JT1.103
set_property IOSTANDARD LVCMOS18  [get_ports {hp65_p5}]
set_property PACKAGE_PIN AN17  [get_ports {hp65_n5}]           ;# HP65_IO_N5             IO_L5N_T0U_N9_AD14N_65         JT1.101
set_property IOSTANDARD LVCMOS18  [get_ports {hp65_n5}]
set_property PACKAGE_PIN AN18  [get_ports {hp65_p6}]           ;# HP65_IO_P6             IO_L6P_T0U_N10_AD6P_65         JT1.93
set_property IOSTANDARD LVCMOS18  [get_ports {hp65_p6}]
set_property PACKAGE_PIN AP17  [get_ports {hp65_n6}]           ;# HP65_IO_N6             IO_L6N_T0U_N11_AD6N_65         JT1.91
set_property IOSTANDARD LVCMOS18  [get_ports {hp65_n6}]
set_property PACKAGE_PIN AH13  [get_ports {hp65_p7}]           ;# HP65_IO_P7             IO_L7P_T1L_N0_QBC_AD13P_65     JT1.58
set_property IOSTANDARD LVCMOS18  [get_ports {hp65_p7}]
set_property PACKAGE_PIN AJ13  [get_ports {hp65_n7}]           ;# HP65_IO_N7             IO_L7N_T1L_N1_QBC_AD13N_65     JT1.56
set_property IOSTANDARD LVCMOS18  [get_ports {hp65_n7}]
set_property PACKAGE_PIN AK15  [get_ports {hp65_p8}]           ;# HP65_IO_P8             IO_L8P_T1L_N2_AD5P_65          JT1.64
set_property IOSTANDARD LVCMOS18  [get_ports {hp65_p8}]
set_property PACKAGE_PIN AK14  [get_ports {hp65_n8}]           ;# HP65_IO_N8             IO_L8N_T1L_N3_AD5N_65          JT1.62
set_property IOSTANDARD LVCMOS18  [get_ports {hp65_n8}]
set_property PACKAGE_PIN AK18  [get_ports {hp65_p9}]           ;# HP65_IO_P9             IO_L9P_T1L_N4_AD12P_65         JT1.113
set_property IOSTANDARD LVCMOS18  [get_ports {hp65_p9}]
set_property PACKAGE_PIN AL18  [get_ports {hp65_n9}]           ;# HP65_IO_N9             IO_L9N_T1L_N5_AD12N_65         JT1.111
set_property IOSTANDARD LVCMOS18  [get_ports {hp65_n9}]
set_property PACKAGE_PIN AH18  [get_ports {hp65_p10}]          ;# HP65_IO_P10            IO_L10P_T1U_N6_QBC_AD4P_65     JT1.105
set_property IOSTANDARD LVCMOS18  [get_ports {hp65_p10}]
set_property PACKAGE_PIN AJ18  [get_ports {hp65_n10}]          ;# HP65_IO_N10            IO_L10N_T1U_N7_QBC_AD4N_65     JT1.107
set_property IOSTANDARD LVCMOS18  [get_ports {hp65_n10}]
set_property PACKAGE_PIN AJ16  [get_ports {hp65_p11}]          ;# HP65_IO_P11            IO_L11P_T1U_N8_GC_65           JT1.68
set_property IOSTANDARD LVCMOS18  [get_ports {hp65_p11}]
set_property PACKAGE_PIN AJ15  [get_ports {hp65_n11}]          ;# HP65_IO_N11            IO_L11N_T1U_N9_GC_65           JT1.66
set_property IOSTANDARD LVCMOS18  [get_ports {hp65_n11}]
set_property PACKAGE_PIN AJ17  [get_ports {hp65_p12}]          ;# HP65_IO_P12            IO_L12P_T1U_N10_GC_65          JT1.84
set_property IOSTANDARD LVCMOS18  [get_ports {hp65_p12}]
set_property PACKAGE_PIN AK16  [get_ports {hp65_n12}]          ;# HP65_IO_N12            IO_L12N_T1U_N11_GC_65          JT1.82
set_property IOSTANDARD LVCMOS18  [get_ports {hp65_n12}]
#set_property PACKAGE_PIN AG15  [get_ports {hp65_p13}]         ;# HP65_IO_P13            IO_L13P_T2L_N0_GC_QBC_65       PT1.22 JT1.88  |  ALSO on PT1.22 - constrained in the PT1 section above
#set_property IOSTANDARD LVCMOS18  [get_ports {hp65_p13}]
#set_property PACKAGE_PIN AH15  [get_ports {hp65_n13}]         ;# HP65_IO_N13            IO_L13N_T2L_N1_GC_QBC_65       PT1.23 JT1.86  |  ALSO on PT1.23 - constrained in the PT1 section above
#set_property IOSTANDARD LVCMOS18  [get_ports {hp65_n13}]
#set_property PACKAGE_PIN AG17  [get_ports {hp65_p14}]         ;# HP65_IO_P14            IO_L14P_T2L_N2_GC_65           PT1.19 JT1.94  |  ALSO on PT1.19 - constrained in the PT1 section above
#set_property IOSTANDARD LVCMOS18  [get_ports {hp65_p14}]
#set_property PACKAGE_PIN AH17  [get_ports {hp65_n14}]         ;# HP65_IO_N14            IO_L14N_T2L_N3_GC_65           PT1.20 JT1.92  |  ALSO on PT1.20 - constrained in the PT1 section above
#set_property IOSTANDARD LVCMOS18  [get_ports {hp65_n14}]
set_property PACKAGE_PIN AF14  [get_ports {hp65_p15}]          ;# HP65_IO_P15            IO_L15P_T2L_N4_AD11P_65        JT1.24
set_property IOSTANDARD LVCMOS18  [get_ports {hp65_p15}]
set_property PACKAGE_PIN AF13  [get_ports {hp65_n15}]          ;# HP65_IO_N15            IO_L15N_T2L_N5_AD11N_65        JT1.22
set_property IOSTANDARD LVCMOS18  [get_ports {hp65_n15}]
set_property PACKAGE_PIN AG14  [get_ports {hp65_p16}]          ;# HP65_IO_P16            IO_L16P_T2U_N6_QBC_AD3P_65     JT1.46
set_property IOSTANDARD LVCMOS18  [get_ports {hp65_p16}]
set_property PACKAGE_PIN AH14  [get_ports {hp65_n16}]          ;# HP65_IO_N16            IO_L16N_T2U_N7_QBC_AD3N_65     JT1.48
set_property IOSTANDARD LVCMOS18  [get_ports {hp65_n16}]
#set_property PACKAGE_PIN AE16  [get_ports {hp65_p17}]         ;# HP65_IO_P17            IO_L17P_T2U_N8_AD10P_65        PT1.13 JT1.104  |  ALSO on PT1.13 - constrained in the PT1 section above
#set_property IOSTANDARD LVCMOS18  [get_ports {hp65_p17}]
#set_property PACKAGE_PIN AF16  [get_ports {hp65_n17}]         ;# HP65_IO_N17            IO_L17N_T2U_N9_AD10N_65        PT1.14 JT1.102  |  ALSO on PT1.14 - constrained in the PT1 section above
#set_property IOSTANDARD LVCMOS18  [get_ports {hp65_n17}]
#set_property PACKAGE_PIN AF18  [get_ports {hp65_p18}]         ;# HP65_IO_P18            IO_L18P_T2U_N10_AD2P_65        PT1.16 JT1.98  |  ALSO on PT1.16 - constrained in the PT1 section above
#set_property IOSTANDARD LVCMOS18  [get_ports {hp65_p18}]
#set_property PACKAGE_PIN AF17  [get_ports {hp65_n18}]         ;# HP65_IO_N18            IO_L18N_T2U_N11_AD2N_65        PT1.17 JT1.96  |  ALSO on PT1.17 - constrained in the PT1 section above
#set_property IOSTANDARD LVCMOS18  [get_ports {hp65_n18}]
#set_property PACKAGE_PIN AD15  [get_ports {hp65_p21}]         ;# HP65_IO_P21            IO_L21P_T3L_N4_AD8P_65         PT1.10 JT1.108  |  ALSO on PT1.10 - constrained in the PT1 section above
#set_property IOSTANDARD LVCMOS18  [get_ports {hp65_p21}]
#set_property PACKAGE_PIN AE15  [get_ports {hp65_n21}]         ;# HP65_IO_N21            IO_L21N_T3L_N5_AD8N_65         PT1.11 JT1.106  |  ALSO on PT1.11 - constrained in the PT1 section above
#set_property IOSTANDARD LVCMOS18  [get_ports {hp65_n21}]
set_property PACKAGE_PIN AC16  [get_ports {hp65_p22}]          ;# HP65_IO_P22            IO_L22P_T3U_N6_DBC_AD0P_65     JT1.6
set_property IOSTANDARD LVCMOS18  [get_ports {hp65_p22}]
set_property PACKAGE_PIN AC15  [get_ports {hp65_n22}]          ;# HP65_IO_N22            IO_L22N_T3U_N7_DBC_AD0N_65     JT1.8
set_property IOSTANDARD LVCMOS18  [get_ports {hp65_n22}]
set_property PACKAGE_PIN AC17  [get_ports {hp65_p23}]          ;# HP65_IO_P23            IO_L23P_T3U_N8_I2C_SCLK_65     JT1.119
set_property IOSTANDARD LVCMOS18  [get_ports {hp65_p23}]
set_property PACKAGE_PIN AD16  [get_ports {hp65_n23}]          ;# HP65_IO_N23            IO_L23N_T3U_N9_65              JT1.117
set_property IOSTANDARD LVCMOS18  [get_ports {hp65_n23}]

#==============================================================================
# NOT CONNECTED  -  in the package, but with no net on this board.
# There is nothing on the other end of these; do not constrain them.
#==============================================================================
#   AF10  IO_L24N_T3U_N11_66                       (schematic net HP_IO_N24, ends at the FPGA symbol)
#   AE11  IO_L24P_T3U_N10_66                       (schematic net HP_IO_P24, ends at the FPGA symbol)
#   AD13  IO_L19N_T3L_N1_DBC_AD9N_65               (schematic net HP65_IO_N19, ends at the FPGA symbol)
#   AC13  IO_L19P_T3L_N0_DBC_AD9P_65               (schematic net HP65_IO_P19, ends at the FPGA symbol)
#   AE13  IO_L20N_T3L_N3_AD1N_65                   (schematic net HP65_IO_N20, ends at the FPGA symbol)
#   AE14  IO_L20P_T3L_N2_AD1P_65                   (schematic net HP65_IO_P20, ends at the FPGA symbol)
#   AE18  IO_L24N_T3U_N11_PERSTN0_65               (schematic net HP65_IO_N24, ends at the FPGA symbol)
#   AD18  IO_L24P_T3U_N10_PERSTN1_I2C_SDA_65       (schematic net HP65_IO_P24, ends at the FPGA symbol)
#   AN3   IO_T0U_N12_VRP_66                        (no schematic net at all)
#   AN9   IO_T1U_N12_66                            (no schematic net at all)
#   AJ12  IO_T2U_N12_66                            (no schematic net at all)
#   AH12  IO_T3U_N12_66                            (no schematic net at all)
#   AL14  IO_T0U_N12_VRP_65                        (no schematic net at all)
#   AL16  IO_T1U_N12_65                            (no schematic net at all)
#   AG16  IO_T2U_N12_65                            (no schematic net at all)
#   AD17  IO_T3U_N12_65                            (no schematic net at all)

#==============================================================================
# GTY TRANSCEIVERS
#
# Both reference clock pairs of each quad come from the on-board Renesas/IDT
# RC21008B VersaClock7, which is I2C programmable - so the refclk frequency is a
# configuration choice, not a board constant. Two profiles are in common use:
# 156.25 MHz for 10G and about 161.13 MHz for 25G. The periods below are the
# 156.25 MHz / 10G case - edit them if you reprogram the synthesiser.
#
#   GTY bank 128  GTYE4_COMMON_X0Y1, channels X0Y4..X0Y7   ->  QSFP0 cage
#   GTY bank 129  GTYE4_COMMON_X0Y2, channels X0Y8..X0Y11  ->  QSFP1 cage
#
# Lane TX/RX balls need no PACKAGE_PIN - they follow from the channel LOC.
# Refclk pins take no IOSTANDARD.
#==============================================================================
set_property PACKAGE_PIN M28   [get_ports {gty_refclk0p_i[0]}] ;# MGTREFCLK0P_128
set_property PACKAGE_PIN M29   [get_ports {gty_refclk0n_i[0]}] ;# MGTREFCLK0N_128
set_property PACKAGE_PIN K28   [get_ports {gty_refclk1p_i[0]}] ;# MGTREFCLK1P_128
set_property PACKAGE_PIN K29   [get_ports {gty_refclk1n_i[0]}] ;# MGTREFCLK1N_128
set_property PACKAGE_PIN H28   [get_ports {gty_refclk0p_i[1]}] ;# MGTREFCLK0P_129
set_property PACKAGE_PIN H29   [get_ports {gty_refclk0n_i[1]}] ;# MGTREFCLK0N_129
set_property PACKAGE_PIN F28   [get_ports {gty_refclk1p_i[1]}] ;# MGTREFCLK1P_129
set_property PACKAGE_PIN F29   [get_ports {gty_refclk1n_i[1]}] ;# MGTREFCLK1N_129

# 6.400 ns = 156.25 MHz
create_clock -name gtrefclk0_1  -period 6.400 [get_ports {gty_refclk0p_i[0]}]
create_clock -name gtrefclk1_1  -period 6.400 [get_ports {gty_refclk1p_i[0]}]
create_clock -name gtrefclk0_2  -period 6.400 [get_ports {gty_refclk0p_i[1]}]
create_clock -name gtrefclk1_2  -period 6.400 [get_ports {gty_refclk1p_i[1]}]
set_clock_groups -group [get_clocks gtrefclk0_1  -include_generated_clocks] -asynchronous
set_clock_groups -group [get_clocks gtrefclk1_1  -include_generated_clocks] -asynchronous
set_clock_groups -group [get_clocks gtrefclk0_2  -include_generated_clocks] -asynchronous
set_clock_groups -group [get_clocks gtrefclk1_2  -include_generated_clocks] -asynchronous

#------------------------------------------------------------------------------
# GTY channel / common placement. These are LOC constraints on GT primitive
# CELLS, not on package balls, so they only apply to a design that instantiates
# GTYE4_CHANNEL / GTYE4_COMMON at these exact hierarchy paths, which is the
# IBERT example's hierarchy. Change the cell paths to match your own
# transceiver wrapper.
#------------------------------------------------------------------------------
set_property LOC GTYE4_CHANNEL_X0Y4   [get_cells {QUAD0.u_q/CH[0].u_ch/u_gtye4_channel}]
set_property LOC GTYE4_CHANNEL_X0Y5   [get_cells {QUAD0.u_q/CH[1].u_ch/u_gtye4_channel}]
set_property LOC GTYE4_CHANNEL_X0Y6   [get_cells {QUAD0.u_q/CH[2].u_ch/u_gtye4_channel}]
set_property LOC GTYE4_CHANNEL_X0Y7   [get_cells {QUAD0.u_q/CH[3].u_ch/u_gtye4_channel}]
set_property LOC GTYE4_COMMON_X0Y1    [get_cells {QUAD0.u_q/u_common/u_gtye4_common}]
set_property LOC GTYE4_CHANNEL_X0Y8   [get_cells {QUAD1.u_q/CH[0].u_ch/u_gtye4_channel}]
set_property LOC GTYE4_CHANNEL_X0Y9   [get_cells {QUAD1.u_q/CH[1].u_ch/u_gtye4_channel}]
set_property LOC GTYE4_CHANNEL_X0Y10  [get_cells {QUAD1.u_q/CH[2].u_ch/u_gtye4_channel}]
set_property LOC GTYE4_CHANNEL_X0Y11  [get_cells {QUAD1.u_q/CH[3].u_ch/u_gtye4_channel}]
set_property LOC GTYE4_COMMON_X0Y2    [get_cells {QUAD1.u_q/u_common/u_gtye4_common}]


#==============================================================================
# OPTIONAL SAFETY DEFAULT
#
# Holds every pin you did NOT use in a defined state instead of floating. On
# this board that matters for A12 (the RF-DAC AVTT FET gate has no external
# pull-down). It applies device-wide, including banks 65/66, so decide
# deliberately rather than leaving it on by habit.
#==============================================================================
#set_property BITSTREAM.CONFIG.UNUSEDPIN PULLDOWN [current_design]

#==============================================================================
# end of ZU27DR_v1.1.xdc
#==============================================================================
