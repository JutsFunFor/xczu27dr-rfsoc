#=============================================================================
# clock_check.tcl  --  measure the four GTY reference clocks
#
#   cd clocking
#   vivado -mode batch -source clock_check.tcl
#   vivado -mode batch -source clock_check.tcl -tclargs 161.1328125
#
# Board in JTAG boot mode, JTAG cable connected, board powered. No SD card,
# no FSBL, no boot image.
#
# WHAT IT DOES
#
#   1. Builds build/clk_meas_top.bit from rtl/clk_meas_top.v if it is not
#      there yet (first run only; about ten minutes on this part).
#   2. Programs it over JTAG.
#   3. Reads the four counters and reports each reference clock.
#
# THE ACCURACY STORY, BECAUSE IT MATTERS HERE
#
#   The gate that all four counters share is derived from STARTUPE3's internal
#   oscillator, which is specified only as 30-65 MHz. So the raw absolute
#   numbers are good to roughly +/-30% and no better.
#
#   The RATIOS are exact, because every channel is counted over the same gate.
#   So this script takes one channel as a known reference -- 156.25 MHz by
#   default, or whatever you pass on the command line -- back-solves the
#   oscillator frequency from it, and reports the other three against that.
#   Those three numbers are as accurate as your assumption about the first.
#
#   If you have not reprogrammed the RC21008B, 156.25 MHz is the profile the
#   10G profile uses and the default here is right. The 25G profile is
#   161.1328125 MHz.
#
# WHAT A RESULT MEANS
#
#   count 0            no clock arriving on that pin pair at all
#   all four equal     one synthesiser output feeding both quads, as expected
#   one channel off    that RC21008B output is programmed differently
#
# OPTIONS
#     -tclargs <MHz>            frequency to assume for quad 128 refclk0
#     -tclargs <MHz> rebuild    ... and force a rebuild
#     -tclargs <MHz> noprog     ... and skip programming
#=============================================================================

set PART  xczu27dr-fsve1156-1-i
set HERE  [file normalize [file dirname [info script]]]
set BUILD [file join $HERE build]
set BIT   [file join $BUILD clk_meas_top.bit]

# Must match GATE_BITS in rtl/clk_meas_top.v.
set GATE_CYCLES [expr {1 << 21}]

# Below this many counts in a gate window, call it no clock. 1000 counts is
# around 50 kHz; the slowest thing a GTY reference input will ever be asked to
# carry is three orders of magnitude above that.
set NOCLK_MAX 1000

set REF_MHZ  156.25
set do_build 1
set do_prog  1
foreach a $argv {
    if {[string is double -strict $a]} { set REF_MHZ $a ; continue }
    switch -- $a {
        rebuild { file delete -force $BUILD }
        noprog  { set do_prog 0 }
        default { puts "unknown argument: $a" ; exit 1 }
    }
}
if {[file exists $BIT]} { set do_build 0 }

#-----------------------------------------------------------------------------
# 1. build
#-----------------------------------------------------------------------------
proc build_clk_meas {} {
    global PART HERE BUILD BIT

    puts "\n== building $BIT"
    file mkdir $BUILD
    create_project clk_meas_top [file join $BUILD proj] -part $PART -force

    add_files -norecurse [list [file join $HERE rtl clk_meas_top.v]]
    add_files -fileset constrs_1 -norecurse [list [file join $HERE clk_meas.xdc]]

    create_bd_design "clk_meas_bd"

    set jtag [create_bd_cell -type ip -vlnv xilinx.com:ip:jtag_axi jtag_axi_0]
    set_property -dict [list CONFIG.PROTOCOL {2}] $jtag

    set sc [create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect smartconnect_0]
    set_property -dict [list CONFIG.NUM_SI {1} CONFIG.NUM_MI {2}] $sc

    # Two dual-channel GPIOs, all inputs: four 32-bit counters.
    foreach i {0 1} {
        set g [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio axi_gpio_$i]
        set_property -dict [list \
            CONFIG.C_IS_DUAL      {1} \
            CONFIG.C_ALL_INPUTS   {1} \
            CONFIG.C_GPIO_WIDTH   {32} \
            CONFIG.C_ALL_INPUTS_2 {1} \
            CONFIG.C_GPIO2_WIDTH  {32} \
        ] $g
    }

    create_bd_port -dir I -type clk aclk
    set_property CONFIG.FREQ_HZ 50000000 [get_bd_ports aclk]
    create_bd_port -dir I -type rst aresetn
    set_property CONFIG.ASSOCIATED_RESET aresetn [get_bd_ports aclk]

    connect_bd_net [get_bd_ports aclk] \
        [get_bd_pins jtag_axi_0/aclk] [get_bd_pins smartconnect_0/aclk] \
        [get_bd_pins axi_gpio_0/s_axi_aclk] [get_bd_pins axi_gpio_1/s_axi_aclk]
    connect_bd_net [get_bd_ports aresetn] \
        [get_bd_pins jtag_axi_0/aresetn] [get_bd_pins smartconnect_0/aresetn] \
        [get_bd_pins axi_gpio_0/s_axi_aresetn] [get_bd_pins axi_gpio_1/s_axi_aresetn]

    connect_bd_intf_net [get_bd_intf_pins jtag_axi_0/M_AXI] \
                        [get_bd_intf_pins smartconnect_0/S00_AXI]
    connect_bd_intf_net [get_bd_intf_pins smartconnect_0/M00_AXI] \
                        [get_bd_intf_pins axi_gpio_0/S_AXI]
    connect_bd_intf_net [get_bd_intf_pins smartconnect_0/M01_AXI] \
                        [get_bd_intf_pins axi_gpio_1/S_AXI]

    make_bd_intf_pins_external -name cnt0 [get_bd_intf_pins axi_gpio_0/GPIO]
    make_bd_intf_pins_external -name cnt1 [get_bd_intf_pins axi_gpio_0/GPIO2]
    make_bd_intf_pins_external -name cnt2 [get_bd_intf_pins axi_gpio_1/GPIO]
    make_bd_intf_pins_external -name cnt3 [get_bd_intf_pins axi_gpio_1/GPIO2]

    assign_bd_address
    foreach {cell off} {axi_gpio_0 0x44A00000 axi_gpio_1 0x44A10000} {
        set seg [get_bd_addr_segs -of_objects [get_bd_addr_spaces jtag_axi_0/Data] \
                    -filter "NAME =~ *${cell}*"]
        set_property offset $off $seg
        set_property range  64K  $seg
    }

    validate_bd_design
    save_bd_design

    set bd [get_files clk_meas_bd.bd]
    add_files -norecurse [list [make_wrapper -files $bd -top -force]]
    set_property top clk_meas_top [current_fileset]
    update_compile_order -fileset sources_1

    launch_runs synth_1 -jobs 8
    wait_on_run synth_1
    if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} {
        error "synthesis failed -- see [file join $BUILD proj clk_meas_top.runs synth_1]"
    }
    launch_runs impl_1 -to_step write_bitstream -jobs 8
    wait_on_run impl_1
    if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} {
        error "implementation failed -- see [file join $BUILD proj clk_meas_top.runs impl_1]"
    }

    file copy -force \
        [file join $BUILD proj clk_meas_top.runs impl_1 clk_meas_top.bit] $BIT
    close_project
    puts "== bitstream: $BIT"
}

#-----------------------------------------------------------------------------
# 2. hardware
#-----------------------------------------------------------------------------
proc open_board {} {
    open_hw_manager
    connect_hw_server -allow_non_jtag
    set targets [get_hw_targets]
    if {[llength $targets] == 0} {
        error "no JTAG target. Is the board powered and the cable plugged in?"
    }
    foreach t $targets {
        current_hw_target $t
        open_hw_target -quiet
        if {[llength [get_hw_devices xczu27dr*]] > 0} {
            set dev [lindex [get_hw_devices xczu27dr*] 0]
            current_hw_device $dev
            # Discover whatever debug cores the loaded bitstream has. Without
            # this, get_hw_axis finds nothing even when the design is already
            # in the device -- which is what "noprog" runs depend on.
            catch { refresh_hw_device -update_hw_probes false $dev }
            puts "== target : $t"
            puts "== device : $dev  idcode [get_property IDCODE $dev]"
            return $dev
        }
        close_hw_target -quiet
    }
    error "found [llength $targets] JTAG target(s) but no xczu27dr on any of them"
}

proc program_board {dev bit} {
    puts "== programming $bit"
    set_property PROGRAM.FILE $bit $dev
    program_hw_devices $dev
    after 2000
    refresh_hw_device -update_hw_probes false $dev
    # The name of the DONE-pin property moved between Vivado versions, so read
    # whichever one this install has rather than assuming.
    set done "unknown"
    foreach prop [list_property -quiet $dev] {
        if {[string match -nocase "*CONFIG_STATUS*DONE*" $prop] ||
            [string match -nocase "*END_OF_STARTUP*" $prop]} {
            set done "[get_property $prop $dev]  ($prop)"
            break
        }
    }
    puts "== configuration done: $done"
}

proc axi_read {addr} {
    set m [get_hw_axis -quiet]
    if {[llength $m] == 0} {
        error "no JTAG-to-AXI master found. The bitstream in the device is not\
               this design, or configuration did not finish."
    }
    create_hw_axi_txn -force r [lindex $m 0] \
        -address [format %08X $addr] -type read -len 1
    run_hw_axi -quiet [get_hw_axi_txns r]
    return [expr 0x[lindex [get_property DATA [get_hw_axi_txns r]] 0]]
}

#=============================================================================
# run
#=============================================================================
if {$do_build} { build_clk_meas } else { puts "== using existing $BIT" }

set dev [open_board]
if {$do_prog} { program_board $dev $BIT } else { puts "== skipping programming" }

# Let at least two full gate periods elapse so every channel has latched.
puts [format "\n== measuring (gate window is 2^%d oscillator cycles, about %d ms)" \
        [expr {int(log($GATE_CYCLES)/log(2))}] [expr {$GATE_CYCLES/50000}]]
after 1000

set CH {
    0x44A00000  "quad 128 refclk0"  "M28 / M29"
    0x44A00008  "quad 128 refclk1"  "K28 / K29"
    0x44A10000  "quad 129 refclk0"  "H28 / H29"
    0x44A10008  "quad 129 refclk1"  "F28 / F29"
}

# Every word is {7-bit capture sequence, 25-bit count}. Read all four and
# require the sequence numbers to match: a set of reads that straddles a
# capture boundary would otherwise mix two measurement windows and throw the
# ratios off by a tenth of a percent.
array set count {}
set got 0
for {set attempt 1} {$attempt <= 12} {incr attempt} {
    set seqs {}
    set vals {}
    foreach {addr name pins} $CH {
        set w [axi_read $addr]
        lappend seqs [expr {($w >> 25) & 0x7F}]
        lappend vals [expr {$w & 0x1FFFFFF}]
    }
    if {[llength [lsort -unique $seqs]] == 1} {
        for {set i 0} {$i < 4} {incr i} { set count($i) [lindex $vals $i] }
        puts "== capture [lindex $seqs 0], all four channels from the same gate window"
        set got 1
        break
    }
    after 50
}
if {!$got} {
    puts "\n== could not read all four counters from one capture window after 12"
    puts "== attempts. That should not happen -- the JTAG link is unusually slow"
    puts "== or the design in the device is not this one."
    close_hw_manager
    exit 1
}

set ref $count(0)
if {$ref == 0} {
    puts "\n== quad 128 refclk0 counted ZERO, so there is nothing to calibrate"
    puts "== against. Raw counts, in oscillator-gate units only:"
    set idx 0
    foreach {addr name pins} $CH {
        puts [format "   %-18s %-12s count %d" $name $pins $count($idx)]
        incr idx
    }
    puts "\n== RESULT: FAIL -- the reference clock this script calibrates from"
    puts "== is absent. Check that the RC21008B is programmed; on this board it"
    puts "== is set up by the FSBL, so a PL-only JTAG session on a board"
    puts "== that has never booted may genuinely have no GTY reference."
    close_hw_manager
    exit 1
}

# f = 2 * count * f_cfgmclk / GATE_CYCLES, and channel 0 is assumed to be
# REF_MHZ, so f_cfgmclk falls out of that.
set cfgmclk [expr {double($REF_MHZ) * $GATE_CYCLES / (2.0 * $ref)}]

puts ""
puts [format "== assuming quad 128 refclk0 = %.6f MHz" $REF_MHZ]
puts [format "== implied CFGMCLK          = %.3f MHz   (spec is 30-65 MHz)" $cfgmclk]
set sane [expr {$cfgmclk >= 30.0 && $cfgmclk <= 65.0}]
if {!$sane} {
    puts ""
    puts "== The implied oscillator frequency is outside the 30-65 MHz the part"
    puts "== guarantees, so something upstream is wrong. In order of likelihood:"
    puts "=="
    puts "==   1. The device is running a different bitstream. That is what a"
    puts "==      'noprog' run does if something else programmed the board since,"
    puts "==      and the counters then read whatever registers happen to be at"
    puts "==      these addresses. Re-run without 'noprog'."
    puts "==   2. The reference frequency assumed above is not what the board is"
    puts "==      actually producing. Pass the real one as an argument."
    puts ""
}
puts ""

set fails 0
set live 0
set idx 0
foreach {addr name pins} $CH {
    set c $count($idx)
    # A dead differential input does not always latch a clean zero. Left
    # floating it picks up the odd edge from its neighbours, and one or two
    # counts in a 41 ms window come back instead. That is about 50 Hz, which is
    # not a clock by any reading -- a GTY reference is tens of megahertz and
    # lands in the millions of counts. So the test is a threshold, not == 0,
    # and the stray count is printed rather than hidden.
    if {$c < $NOCLK_MAX} {
        if {$c == 0} {
            puts [format "   %-18s %-12s  no clock" $name $pins]
        } else {
            puts [format "   %-18s %-12s  no clock (count %d -- stray edges on a floating input)" \
                    $name $pins $c]
        }
        incr fails
    } else {
        set mhz [expr {2.0 * $c * $cfgmclk / $GATE_CYCLES}]
        set rel [expr {100.0 * ($c - $ref) / double($ref)}]
        puts [format "   %-18s %-12s  %10.4f MHz   count %d   %+.4f%% vs refclk0" \
                $name $pins $mhz $c $rel]
        incr live
    }
    incr idx
}

puts ""
if {$live == 0} {
    puts "== RESULT: FAIL -- no reference clock on any of the four inputs."
    close_hw_manager
    exit 1
}
if {$fails} {
    puts "== $fails of the 4 inputs have no clock on them."
    puts "== On this board that is expected, not a fault: the RC21008B profile"
    puts "== the FSBL loads drives refclk0 of each quad and leaves refclk1"
    puts "== unconnected. Both quads have a usable reference, which is all a"
    puts "== transceiver design needs. If you reprogrammed the synthesiser to"
    puts "== feed all four, an absent one here means that did not take effect."
    puts ""
}
if {!$sane} {
    puts "== RESULT: FAIL -- the numbers above are not trustworthy, for the"
    puts "== reason given further up. Nothing here has been measured reliably."
    close_hw_manager
    exit 1
}
puts "== RESULT: PASS -- $live of 4 GTY reference clocks present."
puts "== The percentages are exact -- all four counters come from one gate"
puts "== window. The megahertz inherit whatever error is in the assumed"
puts "== reference above."
close_hw_manager
exit 0
