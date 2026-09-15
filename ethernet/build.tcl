#=============================================================================
# build.tcl  --  generate psu_init.tcl for this board's Ethernet
#
#   cd ethernet
#   vivado -mode batch -source build.tcl
#
# Produces build/psu_init.tcl, which eth_verify.tcl then runs over JTAG.
#
# A couple of minutes, not the usual ten -- nothing is synthesised. GEM3 is
# hardened silicon in the PS, and the only thing standing between a cold board
# and a working MAC is a register sequence: MIO mux, PLLs, the GEM3 reference
# clock, and releasing GEM3 from reset. Vivado writes that sequence out from
# the block design as soon as the IP's output products exist.
#
# WHAT IS A BOARD FACT HERE
#
#   GEM3 on MIO 64..75, RGMII                 which of the four MACs is wired
#   MDIO on MIO 76..77                        the management bus
#   PHY at MDIO address 7                     strapped on the board
#   GEM3 reference clock 125 MHz from IOPLL   gigabit RGMII needs 125 MHz
#   UART0 on MIO 42..43 at 115200             so the console works too
#   SD1 on MIO 46..51, card detect on MIO 45  the boot device
#   33.333 MHz PS reference crystal           everything derives from it
#
# DDR is configured as well. Nothing in the Ethernet test puts a buffer in DDR
# -- the descriptors and frame data live in on-chip RAM so this works on a
# board with no memory at all -- but leaving it out would make this psu_init
# differ from a real FSBL's for no good reason. See ../ddr4/ for what the
# memory parameters mean.
#=============================================================================

set PART  xczu27dr-fsve1156-1-i
set HERE  [file normalize [file dirname [info script]]]
set BUILD [file join $HERE build]

file mkdir $BUILD
create_project eth_cfg [file join $BUILD proj] -part $PART -force

create_bd_design "eth_bd"
set ps [create_bd_cell -type ip -vlnv xilinx.com:ip:zynq_ultra_ps_e zynq_ultra_ps_e_0]

set_property -dict [list \
    CONFIG.PSU__PSS_REF_CLK__FREQMHZ            {33.333} \
    CONFIG.PSU__OVERRIDE__BASIC_CLOCK           {0} \
    CONFIG.PSU__CRL_APB__IOPLL_CTRL__SRCSEL      {PSS_REF_CLK} \
    CONFIG.PSU__CRL_APB__RPLL_CTRL__SRCSEL       {PSS_REF_CLK} \
    CONFIG.PSU__CRF_APB__DPLL_CTRL__SRCSEL       {PSS_REF_CLK} \
    CONFIG.PSU__CRF_APB__APLL_CTRL__SRCSEL       {PSS_REF_CLK} \
    CONFIG.PSU__CRF_APB__VPLL_CTRL__SRCSEL       {PSS_REF_CLK} \
\
    CONFIG.PSU__ENET3__PERIPHERAL__ENABLE        {1} \
    CONFIG.PSU__ENET3__PERIPHERAL__IO            {MIO 64 .. 75} \
    CONFIG.PSU__ENET3__GRP_MDIO__ENABLE          {1} \
    CONFIG.PSU__ENET3__GRP_MDIO__IO              {MIO 76 .. 77} \
    CONFIG.PSU__ENET3__PTP__ENABLE               {0} \
    CONFIG.PSU__ENET3__TSU__ENABLE               {0} \
    CONFIG.PSU__ENET3__FIFO__ENABLE              {0} \
    CONFIG.PSU__CRL_APB__GEM3_REF_CTRL__SRCSEL   {IOPLL} \
    CONFIG.PSU__CRL_APB__GEM3_REF_CTRL__FREQMHZ  {125} \
    CONFIG.PSU__CRL_APB__GEM3_REF_CTRL__DIVISOR0 {12} \
    CONFIG.PSU__CRL_APB__GEM3_REF_CTRL__DIVISOR1 {1} \
\
    CONFIG.PSU__UART0__PERIPHERAL__ENABLE        {1} \
    CONFIG.PSU__UART0__PERIPHERAL__IO            {MIO 42 .. 43} \
    CONFIG.PSU__UART0__BAUD_RATE                 {115200} \
    CONFIG.PSU__CRL_APB__UART0_REF_CTRL__SRCSEL  {IOPLL} \
    CONFIG.PSU__CRL_APB__UART0_REF_CTRL__FREQMHZ {100} \
\
    CONFIG.PSU__SD1__PERIPHERAL__ENABLE          {1} \
    CONFIG.PSU__SD1__PERIPHERAL__IO              {MIO 46 .. 51} \
    CONFIG.PSU__SD1__SLOT_TYPE                   {SD 2.0} \
    CONFIG.PSU__SD1__DATA_TRANSFER_MODE          {4Bit} \
    CONFIG.PSU__SD1__GRP_CD__ENABLE              {1} \
    CONFIG.PSU__SD1__GRP_CD__IO                  {MIO 45} \
    CONFIG.PSU__CRL_APB__SDIO1_REF_CTRL__SRCSEL  {RPLL} \
    CONFIG.PSU__CRL_APB__SDIO1_REF_CTRL__FREQMHZ {200} \
\
    CONFIG.PSU__DDRC__ENABLE                     {1} \
    CONFIG.PSU__DDRC__MEMORY_TYPE                {DDR 4} \
    CONFIG.PSU__DDRC__COMPONENTS                 {Components} \
    CONFIG.PSU__DDRC__VENDOR_PART                {OTHERS} \
    CONFIG.PSU__DDRC__SPEED_BIN                  {DDR4_2400P} \
    CONFIG.PSU__DDRC__DEVICE_CAPACITY            {8192 MBits} \
    CONFIG.PSU__DDRC__DRAM_WIDTH                 {16 Bits} \
    CONFIG.PSU__DDRC__BUS_WIDTH                  {64 Bit} \
    CONFIG.PSU__DDRC__ROW_ADDR_COUNT             {16} \
    CONFIG.PSU__DDRC__COL_ADDR_COUNT             {10} \
    CONFIG.PSU__DDRC__BANK_ADDR_COUNT            {2} \
    CONFIG.PSU__DDRC__BG_ADDR_COUNT              {1} \
    CONFIG.PSU__DDRC__CL                         {15} \
    CONFIG.PSU__DDRC__CWL                        {12} \
    CONFIG.PSU__DDRC__T_RCD                      {15} \
    CONFIG.PSU__DDRC__T_RP                       {15} \
    CONFIG.PSU__DDRC__T_RC                       {44.5} \
    CONFIG.PSU__DDRC__T_RAS_MIN                  {32.0} \
    CONFIG.PSU__DDRC__T_FAW                      {30.0} \
    CONFIG.PSU__DDRC__ECC                        {Disabled} \
    CONFIG.PSU__DDR__INTERFACE__FREQMHZ          {600.000} \
    CONFIG.PSU__CRF_APB__DDR_CTRL__SRCSEL        {DPLL} \
    CONFIG.PSU__CRF_APB__DDR_CTRL__FREQMHZ       {1200} \
    CONFIG.PSU__CRF_APB__DDR_CTRL__DIVISOR0      {2} \
] $ps

# No PL logic in this project.
set_property -dict [list \
    CONFIG.PSU__USE__M_AXI_GP0 {0} \
    CONFIG.PSU__USE__M_AXI_GP1 {0} \
    CONFIG.PSU__USE__M_AXI_GP2 {0} \
] $ps

puts "\n== Ethernet-relevant settings as the IP sees them:"
foreach k {
    CONFIG.PSU__ENET3__PERIPHERAL__ENABLE  CONFIG.PSU__ENET3__PERIPHERAL__IO
    CONFIG.PSU__ENET3__GRP_MDIO__ENABLE    CONFIG.PSU__ENET3__GRP_MDIO__IO
    CONFIG.PSU__CRL_APB__GEM3_REF_CTRL__SRCSEL
    CONFIG.PSU__CRL_APB__GEM3_REF_CTRL__ACT_FREQMHZ
    CONFIG.PSU__UART0__PERIPHERAL__IO      CONFIG.PSU__PSS_REF_CLK__FREQMHZ
} {
    puts [format "   %-48s %s" $k [get_property $k $ps]]
}

validate_bd_design
save_bd_design
generate_target all [get_files eth_bd.bd]

set found [split [string trim [exec find [file join $BUILD proj] -name psu_init.tcl]] "\n"]
if {[llength $found] == 0 || [lindex $found 0] eq ""} {
    puts "\n== ERROR: Vivado did not write a psu_init.tcl. Nothing to test with."
    exit 1
}
file copy -force [lindex $found 0] [file join $BUILD psu_init.tcl]
puts "\n== psu_init : [file join $BUILD psu_init.tcl]"
puts "== next     : sudo ip addr add 192.168.2.1/24 dev <nic> && \\"
puts "==            ZU27DR_NIC=<nic> xsdb eth_verify.tcl"
close_project
exit 0
