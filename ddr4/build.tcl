#=============================================================================
# build.tcl  --  generate psu_init.tcl for this board's DDR4
#
#   cd ddr4
#   vivado -mode batch -source build.tcl
#
# Produces build/psu_init.tcl, which ddr4_test.tcl then runs over JTAG.
#
# This takes a couple of minutes, not the usual ten: nothing is synthesised.
# A DDR4 test needs no PL logic at all. The memory controller, the DDR PHY and
# the calibration engine are hardened silicon inside the PS, there is no MIG
# core to add and nothing in the data path that fabric could get wrong. All
# that is needed is the register sequence, and Vivado writes that out from the
# block design as soon as the IP's output products exist.
#
# WHERE THESE PARAMETERS COME FROM
#
# The board fits four MT40A512M16JY -- 512M x 16, 8 Gbit each -- on a 64-bit
# bus, giving 4 GB. Everything below describes those parts and how they are
# wired: geometry, speed bin, timings, and the DDR clock the PS has to make.
#
#   16 row bits + 10 column bits + 2 bank + 1 bank-group = one 8 Gbit x16 die
#   64-bit bus / 16-bit devices                          = 4 devices
#   DDR4_2400P at CL15-15-15                             = the fitted speed bin
#   DPLL 1200 MHz / 2 = 600 MHz DDR clock                = DDR4-1200, 2400 MT/s
#
# The PS reference clock is a 33.333 MHz crystal, and every PLL derives from
# it. Getting that number wrong scales every other frequency on the chip.
#
# ECC is off. These are plain components, not a DIMM with an extra device, so
# there is nowhere to put check bits.
#=============================================================================

set PART  xczu27dr-fsve1156-1-i
set HERE  [file normalize [file dirname [info script]]]
set BUILD [file join $HERE build]

file mkdir $BUILD
create_project ddr4_cfg [file join $BUILD proj] -part $PART -force

create_bd_design "ddr4_bd"
set ps [create_bd_cell -type ip -vlnv xilinx.com:ip:zynq_ultra_ps_e zynq_ultra_ps_e_0]

set_property -dict [list \
    CONFIG.PSU__PSS_REF_CLK__FREQMHZ                    {33.333} \
    CONFIG.PSU__OVERRIDE__BASIC_CLOCK                   {0} \
\
    CONFIG.PSU__DDRC__ENABLE                            {1} \
    CONFIG.PSU__DDRC__MEMORY_TYPE                       {DDR 4} \
    CONFIG.PSU__DDRC__COMPONENTS                        {Components} \
    CONFIG.PSU__DDRC__VENDOR_PART                       {OTHERS} \
    CONFIG.PSU__DDRC__SPEED_BIN                         {DDR4_2400P} \
    CONFIG.PSU__DDRC__DEVICE_CAPACITY                   {8192 MBits} \
    CONFIG.PSU__DDRC__DRAM_WIDTH                        {16 Bits} \
    CONFIG.PSU__DDRC__BUS_WIDTH                         {64 Bit} \
    CONFIG.PSU__DDRC__ROW_ADDR_COUNT                    {16} \
    CONFIG.PSU__DDRC__COL_ADDR_COUNT                    {10} \
    CONFIG.PSU__DDRC__BANK_ADDR_COUNT                   {2} \
    CONFIG.PSU__DDRC__BG_ADDR_COUNT                     {1} \
    CONFIG.PSU__DDRC__RANK_ADDR_COUNT                   {0} \
    CONFIG.PSU__DDRC__BRC_MAPPING                       {ROW_BANK_COL} \
    CONFIG.PSU__DDRC__DDR4_ADDR_MAPPING                 {1} \
    CONFIG.PSU__DDRC__ADDR_MIRROR                       {0} \
    CONFIG.PSU__DDRC__DIMM_ADDR_MIRROR                  {0} \
\
    CONFIG.PSU__DDRC__CL                                {15} \
    CONFIG.PSU__DDRC__CWL                               {12} \
    CONFIG.PSU__DDRC__AL                                {0} \
    CONFIG.PSU__DDRC__SB_TARGET                         {15-15-15} \
    CONFIG.PSU__DDRC__T_RCD                             {15} \
    CONFIG.PSU__DDRC__T_RP                              {15} \
    CONFIG.PSU__DDRC__T_RC                              {44.5} \
    CONFIG.PSU__DDRC__T_RAS_MIN                         {32.0} \
    CONFIG.PSU__DDRC__T_FAW                             {30.0} \
\
    CONFIG.PSU__DDRC__ECC                               {Disabled} \
    CONFIG.PSU__DDRC__ECC_SCRUB                         {0} \
    CONFIG.PSU__DDRC__PARITY_ENABLE                     {0} \
    CONFIG.PSU__DDRC__DM_DBI                            {DM_NO_DBI} \
    CONFIG.PSU__DDRC__PHY_DBI_MODE                      {0} \
    CONFIG.PSU__DDRC__VREF                              {1} \
    CONFIG.PSU__DDRC__DDR4_T_REF_RANGE                  {Normal (0-85)} \
    CONFIG.PSU__DDRC__DDR4_T_REF_MODE                   {0} \
    CONFIG.PSU__DDRC__FGRM                              {1X} \
    CONFIG.PSU__DDRC__PER_BANK_REFRESH                  {0} \
    CONFIG.PSU__DDRC__ENABLE_2T_TIMING                  {0} \
    CONFIG.PSU__DDRC__CLOCK_STOP_EN                     {0} \
    CONFIG.PSU__DDRC__PWR_DOWN_EN                       {0} \
    CONFIG.PSU__DDRC__DEEP_PWR_DOWN_EN                  {0} \
    CONFIG.PSU__DDRC__SELF_REF_ABORT                    {0} \
    CONFIG.PSU__DDRC__STATIC_RD_MODE                    {0} \
    CONFIG.PSU__DDRC__RD_DQS_CENTER                     {0} \
    CONFIG.PSU__DDRC__DDR4_CRC_CONTROL                  {0} \
    CONFIG.PSU__DDRC__DDR4_CAL_MODE_ENABLE              {0} \
    CONFIG.PSU__DDRC__DDR4_MAXPWR_SAVING_EN             {0} \
    CONFIG.PSU__DDRC__LP_ASR                            {manual normal} \
\
    CONFIG.PSU__DDRC__TRAIN_WRITE_LEVEL                 {1} \
    CONFIG.PSU__DDRC__TRAIN_READ_GATE                   {1} \
    CONFIG.PSU__DDRC__TRAIN_DATA_EYE                    {1} \
\
    CONFIG.PSU__DDR__INTERFACE__FREQMHZ                 {600.000} \
    CONFIG.PSU__CRF_APB__DDR_CTRL__SRCSEL               {DPLL} \
    CONFIG.PSU__CRF_APB__DDR_CTRL__FREQMHZ              {1200} \
    CONFIG.PSU__CRF_APB__DDR_CTRL__DIVISOR0             {2} \
    CONFIG.PSU__CRF_APB__DPLL_CTRL__SRCSEL              {PSS_REF_CLK} \
    CONFIG.PSU__CRF_APB__APLL_CTRL__SRCSEL              {PSS_REF_CLK} \
\
    CONFIG.PSU__DDR_HIGH_ADDRESS_GUI_ENABLE             {1} \
    CONFIG.PSU__DDR_SW_REFRESH_ENABLED                  {1} \
    CONFIG.PSU__DDR_QOS_ENABLE                          {0} \
] $ps

# No PL logic in this project, so switch off the PL-facing interfaces the IP
# turns on by default rather than leave masters dangling.
set_property -dict [list \
    CONFIG.PSU__USE__M_AXI_GP0 {0} \
    CONFIG.PSU__USE__M_AXI_GP1 {0} \
    CONFIG.PSU__USE__M_AXI_GP2 {0} \
] $ps

#-----------------------------------------------------------------------------
# Report what actually stuck. A CONFIG name that does not exist on this version
# of the IP is silently ignored, so read the important ones back and print them.
#-----------------------------------------------------------------------------
puts "\n== DDR parameters as the IP sees them:"
foreach k {
    CONFIG.PSU__DDRC__MEMORY_TYPE     CONFIG.PSU__DDRC__SPEED_BIN
    CONFIG.PSU__DDRC__BUS_WIDTH       CONFIG.PSU__DDRC__DRAM_WIDTH
    CONFIG.PSU__DDRC__DEVICE_CAPACITY CONFIG.PSU__DDRC__CL
    CONFIG.PSU__DDRC__CWL             CONFIG.PSU__DDRC__ECC
    CONFIG.PSU__DDRC__ROW_ADDR_COUNT  CONFIG.PSU__DDRC__COL_ADDR_COUNT
    CONFIG.PSU__DDRC__BANK_ADDR_COUNT CONFIG.PSU__DDRC__BG_ADDR_COUNT
    CONFIG.PSU__DDRC__T_RC            CONFIG.PSU__DDRC__T_RCD
    CONFIG.PSU__DDRC__T_RP            CONFIG.PSU__ACT_DDR_FREQ_MHZ
    CONFIG.PSU__PSS_REF_CLK__FREQMHZ
} {
    puts [format "   %-46s %s" $k [get_property $k $ps]]
}

validate_bd_design
save_bd_design

# Generating the IP's output products is what writes psu_init.tcl.
generate_target all [get_files ddr4_bd.bd]

set found [glob -nocomplain -directory [file join $BUILD proj] \
              -types f */sources_1/bd/*/ip/*/psu_init.tcl */bd/*/ip/*/psu_init.tcl]
if {[llength $found] == 0} {
    # Different Vivado versions park it in different places; search the lot.
    set found [exec find [file join $BUILD proj] -name psu_init.tcl]
    set found [split [string trim $found] "\n"]
}
if {[llength $found] == 0} {
    puts "\n== ERROR: Vivado did not write a psu_init.tcl. Nothing to test with."
    exit 1
}

set src [lindex $found 0]
file copy -force $src [file join $BUILD psu_init.tcl]
puts "\n== psu_init : [file join $BUILD psu_init.tcl]"
puts "== next     : xsdb ddr4_test.tcl"
close_project
exit 0
