#=============================================================================
# build.tcl  --  generate and build the RF Data Converter example design
#
#   cd adc-dac
#   vivado -mode batch -source build.tcl
#
# Expect 40-60 minutes. It is the big one in this BSP.
#
# WHAT THIS IS
#
# AMD's RF Data Converter IP ships an example design: the converter block, a
# MicroBlaze, a JTAG-to-AXI master, and block RAMs that feed the DACs and
# capture from the ADCs. That is a complete RF test bench with no PS involved,
# and it is what loopback.tcl and rfdc_status.tcl drive. This script generates
# it from the IP, configured for this board, and builds the bitstream.
#
# No PS block, so nothing here needs an FSBL, an SD card or a boot image --
# but see the warning about the reference clock at the bottom.
#
# THE CONFIGURATION, AND WHY
#
#   ADC tile 0 = ADC224, four slices, 4.0 GSPS, 200 MHz reference, PLL on
#   DAC tile 1 = DAC229, four slices, 4.0 GSPS, 200 MHz reference, PLL on
#
# Those are the two tiles this board brings out to SMA connectors, and 200 MHz
# is what the RC21008B delivers to them. Sampling at 4.0 GSPS from a 200 MHz
# reference means the tile PLL multiplies by 20.
#
#   ADC decimation 1x, 8 samples per AXI beat  -> 500 MHz fabric clock
#   DAC interpolation 1x, 16-bit samples       -> 250 MHz fabric clock
#
# Samples are 14-bit, left-aligned in a 16-bit word: the bottom two bits are
# always zero and full scale is 0x8000/0x7FFC, not 0x2000/0x1FFF. Getting that
# wrong costs you 12 dB and looks like a broken converter.
#
#   DAC output current 20 mA, which needs DAC_AVTT at 2.5 V. On this board
#   that rail is switched by a FET whose gate is ball A12: LOW selects 2.5 V.
#   This design does not drive A12, so make sure nothing else pulls it high.
#=============================================================================

set PART  xczu27dr-fsve1156-1-i
set HERE  [file normalize [file dirname [info script]]]
set BUILD [file join $HERE build]
set BIT   [file join $BUILD rfdc_example.bit]

foreach a $argv {
    switch -- $a {
        rebuild { file delete -force $BUILD }
        default { puts "unknown argument: $a" ; exit 1 }
    }
}
if {[file exists $BIT]} {
    puts "== $BIT already exists. Pass -tclargs rebuild to build it again."
    exit 0
}

file mkdir $BUILD
create_project rfdc_gen [file join $BUILD gen] -part $PART -force

# create_ip will not make this directory for you.
file mkdir [file join $BUILD gen ip]
create_ip -name usp_rf_data_converter -vendor xilinx.com -library ip \
          -module_name usp_rf_data_converter_0 -dir [file join $BUILD gen ip]

set ip [get_ips usp_rf_data_converter_0]

set_property -dict [list \
    CONFIG.Converter_Setup       {1} \
    CONFIG.PL_Clock_Freq         {100.0} \
    CONFIG.Sysref_Source         {1} \
    CONFIG.RF_Analyzer           {1} \
    CONFIG.use_bram              {1} \
\
    CONFIG.ADC0_Enable           {1} \
    CONFIG.ADC0_PLL_Enable       {true} \
    CONFIG.ADC0_Refclk_Freq      {200.000} \
    CONFIG.ADC0_Refclk_Div       {1} \
    CONFIG.ADC0_Sampling_Rate    {4.0} \
    CONFIG.ADC0_Fabric_Freq      {500.000} \
    CONFIG.ADC0_Outclk_Freq      {250.000} \
    CONFIG.ADC_Slice00_Enable    {true} \
    CONFIG.ADC_Slice01_Enable    {true} \
    CONFIG.ADC_Slice02_Enable    {true} \
    CONFIG.ADC_Slice03_Enable    {true} \
    CONFIG.ADC_Decimation_Mode00 {1} \
    CONFIG.ADC_Decimation_Mode01 {1} \
    CONFIG.ADC_Decimation_Mode02 {1} \
    CONFIG.ADC_Decimation_Mode03 {1} \
    CONFIG.ADC_Data_Width00      {8} \
    CONFIG.ADC_Data_Width01      {8} \
    CONFIG.ADC_Data_Width02      {8} \
    CONFIG.ADC_Data_Width03      {8} \
    CONFIG.ADC_Mixer_Type00      {0} \
    CONFIG.ADC_Mixer_Type01      {0} \
    CONFIG.ADC_Mixer_Type02      {0} \
    CONFIG.ADC_Mixer_Type03      {0} \
\
    CONFIG.DAC1_Enable           {1} \
    CONFIG.DAC1_PLL_Enable       {true} \
    CONFIG.DAC1_Refclk_Freq      {200.000} \
    CONFIG.DAC1_Refclk_Div       {1} \
    CONFIG.DAC1_Sampling_Rate    {4.0} \
    CONFIG.DAC1_Fabric_Freq      {250.000} \
    CONFIG.DAC1_Outclk_Freq      {125.000} \
    CONFIG.DAC1_VOP              {20.0} \
    CONFIG.DAC_VOP_Mode          {1} \
    CONFIG.DAC_Slice10_Enable    {true} \
    CONFIG.DAC_Slice11_Enable    {true} \
    CONFIG.DAC_Slice12_Enable    {true} \
    CONFIG.DAC_Slice13_Enable    {true} \
    CONFIG.DAC_Interpolation_Mode10 {1} \
    CONFIG.DAC_Interpolation_Mode11 {1} \
    CONFIG.DAC_Interpolation_Mode12 {1} \
    CONFIG.DAC_Interpolation_Mode13 {1} \
    CONFIG.DAC_Data_Width10      {16} \
    CONFIG.DAC_Data_Width11      {16} \
    CONFIG.DAC_Data_Width12      {16} \
    CONFIG.DAC_Data_Width13      {16} \
    CONFIG.DAC_Mixer_Type10      {0} \
    CONFIG.DAC_Mixer_Type11      {0} \
    CONFIG.DAC_Mixer_Type12      {0} \
    CONFIG.DAC_Mixer_Type13      {0} \
] $ip

puts "\n== converter configuration as the IP sees it:"
foreach k {
    CONFIG.ADC0_Enable  CONFIG.ADC0_Sampling_Rate  CONFIG.ADC0_Refclk_Freq
    CONFIG.ADC0_PLL_Enable CONFIG.ADC0_Fabric_Freq
    CONFIG.DAC1_Enable  CONFIG.DAC1_Sampling_Rate  CONFIG.DAC1_Refclk_Freq
    CONFIG.DAC1_PLL_Enable CONFIG.DAC1_Fabric_Freq  CONFIG.DAC1_VOP
} {
    puts [format "   %-32s %s" $k [get_property $k $ip]]
}

generate_target all $ip

#-----------------------------------------------------------------------------
# The example design is a whole separate project that the IP writes out.
#-----------------------------------------------------------------------------
set EXDIR [file join $BUILD ex]
file delete -force $EXDIR
file mkdir $EXDIR
puts "\n== opening the IP example project in $EXDIR"
open_example_project -force -dir $EXDIR $ip

# open_example_project generates the project but does not reliably leave it as
# the current one -- queries after it still answer from the IP project, whose
# only "top" is the IP itself and which has no synthesisable sources. So find
# the generated .xpr and open it explicitly.
set exxpr [lindex [lsort [glob -nocomplain -directory $EXDIR */*.xpr]] 0]
if {$exxpr eq ""} { error "open_example_project wrote no .xpr under $EXDIR" }
close_project
open_project $exxpr
puts "== example project: $exxpr"

# The example project opens with no top module set, and find_top picks the IP
# rather than the example wrapper. Name it explicitly.
update_compile_order -fileset sources_1
set want usp_rf_data_converter_0_example_design
if {[llength [get_files -quiet "*${want}.v"]] == 0} {
    set cands [find_top -fileset sources_1]
    puts "== $want not found; find_top offers: $cands"
    if {[llength $cands] == 0} { error "no identifiable top in the RFDC example project" }
    set want [lindex $cands 0]
}
set_property top $want [current_fileset]
update_compile_order -fileset sources_1
puts "== example design top: [get_property top [current_fileset]]"

puts "== building (this is the slow part)"
launch_runs synth_1 -jobs 8
wait_on_run synth_1
if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} {
    error "synthesis failed -- open the project in $EXDIR and look at the log"
}
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} {
    error "implementation failed -- open the project in $EXDIR and look at the log"
}

#-----------------------------------------------------------------------------
# Record the address map. The example design's slave offsets move between IP
# versions, so writing them out here saves the test scripts from hardcoding a
# map that may not match the bitstream they are driving.
#-----------------------------------------------------------------------------
set MAP [file join $BUILD addrmap.tcl]
if {[catch {
    set bdf [lindex [get_files -quiet *.bd] 0]
    open_bd_design $bdf
    set spaces [get_bd_addr_spaces -quiet -filter {NAME =~ "*jtag_axi*"}]
    if {[llength $spaces] == 0} {
        set spaces [get_bd_addr_spaces -quiet]
    }
    set fh [open $MAP w]
    puts $fh "# Written by build.tcl from [file tail $bdf]. Do not edit."
    set n 0
    foreach sp $spaces {
        foreach seg [get_bd_addr_segs -quiet -of_objects $sp] {
            # Address spaces also contain segments with no offset of their own
            # (unmapped, or a container for others). Skip those rather than
            # letting an empty string blow up the format.
            set off [get_property -quiet OFFSET $seg]
            if {![string is entier -strict $off]} { continue }
            puts $fh [format "set ADDR(%s) 0x%08X" [get_property NAME $seg] $off]
            incr n
        }
    }
    close $fh
    if {$n == 0} { error "no addressable segments found" }
    puts "== address map: $MAP"
    foreach l [split [string trim [read [set f [open $MAP]]]] "\n"] { puts "   $l" }
    close $f
} err]} {
    puts "== could not write the address map ($err)."
    puts "== The test scripts will fall back to their built-in offsets."
}

set found [split [string trim [exec find $EXDIR -name "*.bit"]] "\n"]
if {[llength $found] == 0 || [lindex $found 0] eq ""} {
    puts "== ERROR: implementation finished but no .bit was written"
    exit 1
}
file copy -force [lindex $found 0] $BIT

open_run impl_1
set wns [get_property SLACK [get_timing_paths -delay_type min_max]]
puts [format "\n== worst negative slack: %.3f ns" $wns]
if {$wns < 0} {
    puts "== WARNING: timing did not close. The design will probably still run,"
    puts "== but treat any odd sample data as suspect."
}

puts "\n== bitstream : $BIT"
puts "== next      : vivado -mode batch -source loopback.tcl"
puts ""
puts "== BEFORE YOU RUN IT: the converter tiles cannot lock until the RC21008B"
puts "== clock chip has been programmed, and on this board that is done by the"
puts "== FSBL, not by anything in the PL. On a board that has only ever been"
puts "== JTAG-booted, expect no PLL lock. See ../clocking/."
close_project
exit 0
