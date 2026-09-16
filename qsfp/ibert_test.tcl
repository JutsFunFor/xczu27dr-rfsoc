#=============================================================================
# ibert_test.tcl  --  test the eight GTY lanes through the QSFP cages
#
#   cd qsfp
#   vivado -mode batch -source ibert_test.tcl
#
# WHAT YOU NEED
#
#   A QSFP28 cable between the two cages -- a passive copper DAC cable is
#   ideal. That loops cage 0's four TX lanes into cage 1's four RX lanes and
#   cage 1's four TX into cage 0's four RX, giving eight links to test.
#   A single-cage loopback module works too; you then get four links.
#
#   AND: the RC21008B must have been programmed, or there is no reference
#   clock and nothing will come up. On this board that is the FSBL's job --
#   run ../clocking/clock_check.tcl first and make sure it reports a reference
#   on both quads.
#
# WHAT IT DOES
#
#   1. Builds build/ibert.bit if it is not there (first run, 15-20 minutes).
#   2. Programs it.
#   3. Brings up every lane at 10.3125 Gbps, links cage 0 to cage 1 both ways,
#      runs PRBS-31 and reports bit errors and BER per lane.
#
# WHY 10.3125 Gbps: it is 156.25 MHz x 66, the standard 10GBASE-R rate, and it
# is well inside what a 1 m passive copper cable will carry. The transceivers
# and the cable will both go faster; this is the rate to start at, because if
# it does not work here the problem is not marginal signal integrity.
#
# OPTIONS
#     -tclargs rebuild        force a rebuild
#     -tclargs noprog         skip programming
#     -tclargs dwell <sec>    seconds to accumulate errors (default 10)
#=============================================================================

set PART  xczu27dr-fsve1156-1-i
set HERE  [file normalize [file dirname [info script]]]
set BUILD [file join $HERE build]
set BIT   [file join $BUILD ibert.bit]
set LTX   [file join $BUILD ibert.ltx]

set do_build 1
set do_prog  1
set DWELL    10
for {set i 0} {$i < [llength $argv]} {incr i} {
    switch -- [lindex $argv $i] {
        rebuild { file delete -force $BUILD }
        noprog  { set do_prog 0 }
        dwell   { incr i ; set DWELL [lindex $argv $i] }
        default { puts "unknown argument: [lindex $argv $i]" ; exit 1 }
    }
}
if {[file exists $BIT]} { set do_build 0 }

#-----------------------------------------------------------------------------
# 1. build
#-----------------------------------------------------------------------------
proc build_ibert {} {
    global PART HERE BUILD BIT LTX

    puts "\n== building $BIT"
    file mkdir $BUILD
    create_project ibert [file join $BUILD proj] -part $PART -force

    file mkdir [file join $BUILD proj ip]
    create_ip -name ibert_ultrascale_gty -vendor xilinx.com -library ip \
              -module_name ibert_gty -dir [file join $BUILD proj ip]
    set ip [get_ips ibert_gty]

    # The IP numbers quads from GTY bank 127, so its "Quad 1" is bank 128 and
    # its "Quad 2" is bank 129 -- the two this board wires to the cages.
    #
    # SYSCLK_MODE_EXTERNAL 0 makes IBERT derive its own system clock from a
    # reference clock. This board has no spare differential clock input to give
    # it, and the default is to demand one.
    # THE IP IS FUSSY ABOUT ORDER, AND ITS ERROR MESSAGE LIES.
    #
    # C_PROTOCOL_QUAD_COUNT_1 is how many QUADS use protocol 1, but when it
    # disagrees with the quad assignments the IP complains about the "Number of
    # Lanes". Set the rate, the reference frequency, the quad count and both
    # quad assignments in ONE set_property, because validation runs per call
    # and any intermediate state where they disagree is rejected.
    #
    # Datawidth is left at its default: at this rate the IP only accepts 80.
    set_property -dict [list \
        CONFIG.C_PROTOCOL_REFCLK_FREQUENCY_1 {156.25} \
        CONFIG.C_PROTOCOL_MAXLINERATE_1      {10.3125} \
        CONFIG.C_PROTOCOL_PLL_1              {QPLL0} \
        CONFIG.C_PROTOCOL_QUAD_COUNT_1       {2} \
        CONFIG.C_PROTOCOL_QUAD1              {Custom_1_/_10.3125_Gbps} \
        CONFIG.C_PROTOCOL_QUAD2              {Custom_1_/_10.3125_Gbps} \
        CONFIG.C_NUM_QUADS                   {2} \
        CONFIG.C_NUM_CH_Q1                   {4} \
        CONFIG.C_NUM_CH_Q2                   {4} \
        CONFIG.C_REFCLK_SOURCE_QUAD_1        {MGTREFCLK0_128} \
        CONFIG.C_REFCLK_SOURCE_QUAD_2        {MGTREFCLK0_129} \
    ] $ip

    # IBERT wants a system clock and defaults to demanding an external
    # differential pin. This board has no spare clock input to give it, so
    # derive it from a GT reference instead. The only values this parameter
    # accepts are External, QUAD128_0 and QUAD129_0.
    set_property -dict [list \
        CONFIG.C_SYSCLK_MODE_EXTERNAL {0} \
        CONFIG.C_SYSCLOCK_SOURCE_INT  {QUAD128_0} \
    ] $ip

    puts "== IBERT configuration:"
    foreach k {CONFIG.C_NUM_QUADS CONFIG.C_NUM_CH_Q1 CONFIG.C_NUM_CH_Q2
               CONFIG.C_REFCLK_SOURCE_QUAD_1 CONFIG.C_REFCLK_SOURCE_QUAD_2
               CONFIG.C_PROTOCOL_QUAD1 CONFIG.C_PROTOCOL_QUAD2
               CONFIG.C_SYSCLK_MODE_EXTERNAL CONFIG.C_SYSCLOCK_SOURCE_INT} {
        puts [format "   %-38s %s" $k [get_property $k $ip]]
    }

    generate_target all $ip

    # IBERT is delivered as an IP you instantiate, not as a design. Its example
    # project is the ready-made top level -- GT pins, reference clocks and
    # constraints all wired up -- so build that rather than hand-writing a
    # wrapper whose port names would have to track the IP version.
    set EXDIR [file join $BUILD ex]
    file delete -force $EXDIR
    file mkdir $EXDIR
    puts "== opening the IBERT example project in $EXDIR"
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

    # The example project opens without a top module set, and find_top picks
    # the IP itself -- which has no synthesisable sources of its own. The real
    # top is the example wrapper under imports/.
    update_compile_order -fileset sources_1
    set want example_ibert_gty
    if {[llength [get_files -quiet "*${want}.v"]] == 0} {
        set cands [find_top -fileset sources_1]
        puts "== $want not found; find_top offers: $cands"
        if {[llength $cands] == 0} { error "no identifiable top in the IBERT example project" }
        set want [lindex $cands 0]
    }
    set_property top $want [current_fileset]
    update_compile_order -fileset sources_1
    puts "== example design top: [get_property top [current_fileset]]"

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

    set b [lindex [split [string trim [exec find $EXDIR -name "*.bit"]] "\n"] 0]
    if {$b eq ""} { error "implementation finished but no .bit was written" }
    file copy -force $b $BIT
    set l [lindex [split [string trim [exec find $EXDIR -name "*.ltx"]] "\n"] 0]
    if {$l ne ""} { file copy -force $l $LTX }
    close_project
    puts "== bitstream: $BIT"
}

#-----------------------------------------------------------------------------
# 2. hardware
#-----------------------------------------------------------------------------
proc open_board {} {
    open_hw_manager
    connect_hw_server -allow_non_jtag
    foreach t [get_hw_targets] {
        current_hw_target $t
        open_hw_target -quiet
        if {[llength [get_hw_devices xczu27dr*]] > 0} {
            set dev [lindex [get_hw_devices xczu27dr*] 0]
            current_hw_device $dev
            puts "== target : $t"
            puts "== device : $dev"
            return $dev
        }
        close_hw_target -quiet
    }
    error "no xczu27dr found. Is the board powered and the cable plugged in?"
}

#=============================================================================
# run
#=============================================================================
if {$do_build} { build_ibert } else { puts "== using existing $BIT" }

set dev [open_board]
if {[file exists $LTX]} { set_property PROBES.FILE $LTX $dev }
if {$do_prog} {
    puts "== programming $BIT"
    set_property PROGRAM.FILE $BIT $dev
    program_hw_devices $dev
    after 3000
}
refresh_hw_device $dev
after 2000

#-----------------------------------------------------------------------------
# Enumerate the transceivers
#-----------------------------------------------------------------------------
set gts [get_hw_sio_gts -quiet]
if {[llength $gts] == 0} {
    puts "\n== no transceivers visible. The bitstream in the device is not this"
    puts "== design, or the debug hub did not come up."
    close_hw_manager
    exit 1
}
puts "\n== transceivers found: [llength $gts]"

# The GTs report as MGT_X0Yn, with no quad in the name, so split them by
# channel number. On this device quad 128 is GTYE4_CHANNEL_X0Y4..X0Y7 and quad
# 129 is X0Y8..X0Y11 -- the same numbering the board XDC uses.
set q128 {} ; set q129 {}
foreach g $gts {
    set nm [get_property DISPLAY_NAME $g]
    puts "   $nm"
    if {[regexp {X0Y(\d+)} $nm -> n]} {
        if {$n >= 4 && $n <= 7}  { lappend q128 $g ; continue }
        if {$n >= 8 && $n <= 11} { lappend q129 $g ; continue }
    }
}
if {[llength $q128] != 4 || [llength $q129] != 4} {
    puts "\n== expected X0Y4..X0Y7 and X0Y8..X0Y11, got [llength $q128] and [llength $q129]."
    puts "== Falling back to pairing the first four with the second four."
    set q128 [lrange $gts 0 3]
    set q129 [lrange $gts 4 7]
}

#-----------------------------------------------------------------------------
# Link cage 0 to cage 1 in both directions
#-----------------------------------------------------------------------------
puts "\n== creating links"
set links {}
for {set i 0} {$i < 4} {incr i} {
    set a [lindex $q128 $i]
    set b [lindex $q129 $i]
    foreach {tx rx label} [list $a $b "cage0.$i -> cage1.$i" $b $a "cage1.$i -> cage0.$i"] {
        if {[catch {
            set l [create_hw_sio_link -description $label \
                      [lindex [get_hw_sio_txs -of_objects $tx] 0] \
                      [lindex [get_hw_sio_rxs -of_objects $rx] 0]]
            lappend links [list $l $label]
        } err]} {
            puts "   could not create $label : $err"
        }
    }
}
if {[llength $links] == 0} {
    puts "== no links could be created."
    close_hw_manager
    exit 1
}
puts "== [llength $links] links created"

#-----------------------------------------------------------------------------
# PRBS-31 both ends
#-----------------------------------------------------------------------------
puts "\n== setting PRBS 31-bit on every link"
foreach pair $links {
    set l [lindex $pair 0]
    catch { set_property TX_PATTERN "PRBS 31-bit" $l }
    catch { set_property RX_PATTERN "PRBS 31-bit" $l }
}
commit_hw_sio -non_blocking [lmap p $links {lindex $p 0}]
after 2000

# Reset the error counters, then let them run.
foreach pair $links {
    set l [lindex $pair 0]
    catch { set_property LOGIC.MGT_ERRCNT_RESET_CTRL 1 $l }
}
commit_hw_sio -non_blocking [lmap p $links {lindex $p 0}]
after 500
foreach pair $links {
    set l [lindex $pair 0]
    catch { set_property LOGIC.MGT_ERRCNT_RESET_CTRL 0 $l }
}
commit_hw_sio -non_blocking [lmap p $links {lindex $p 0}]

puts "== accumulating errors for $DWELL s at 10.3125 Gbps"
after [expr {$DWELL * 1000}]
refresh_hw_sio [lmap p $links {lindex $p 0}]

#-----------------------------------------------------------------------------
# Report
#-----------------------------------------------------------------------------
puts ""
# Vivado hands these counters back as zero-padded decimal strings -- a bit
# count arrives as "000206250000000" and an error count as "000000000000".
# Tcl reads a leading zero as octal and errors on "08", so strip the padding
# before doing arithmetic on any of it, and print something a person can read.
proc ibert_num {s} {
    if {![regexp {^[0-9]+$} $s]} { return "" }
    set t [string trimleft $s "0"]
    return [expr {$t eq "" ? "0" : $t}]
}

puts [format "   %-22s %-10s %12s %12s" "link" "locked" "bit errors" "BER"]
set bad 0
foreach pair $links {
    set l     [lindex $pair 0]
    set label [lindex $pair 1]
    set lock "?" ; set errs "?" ; set ber "?"
    catch { set lock [get_property RX_RECEIVED_BIT_COUNT $l] }
    catch { set errs [get_property LOGIC.ERRBIT_COUNT $l] }
    catch { set ber  [get_property RX_BER $l] }

    set lockn [ibert_num $lock]
    set errn  [ibert_num $errs]

    if {$lockn eq "" || $lockn <= 0} { incr bad ; set lockstr "NO" } else { set lockstr "yes" }
    if {$errn eq ""} { incr bad } elseif {$errn > 0} { incr bad }

    set errdisp [expr {$errn eq "" ? "?" : $errn}]
    set berdisp $ber
    if {[string is double -strict $ber]} { set berdisp [format "%.2e" $ber] }

    puts [format "   %-22s %-10s %12s %12s" $label $lockstr $errdisp $berdisp]
}

puts ""
if {$bad} {
    puts "== RESULT: $bad link(s) are not clean."
    puts "== A link that never locks usually means no reference clock on that"
    puts "== quad, or nothing on the other end of the cable. Errors on a link"
    puts "== that does lock point at the cable or the rate."
    close_hw_manager
    exit 1
}
puts "== RESULT: GTY PASS -- all [llength $links] links locked with no bit errors"
puts "== at 10.3125 Gbps through the QSFP cages."
close_hw_manager
exit 0
