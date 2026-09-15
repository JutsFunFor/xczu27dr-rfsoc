#=============================================================================
# led_test.tcl  --  bring up and test the three user LEDs and the J7 header
#
#   cd leds
#   vivado -mode batch -source led_test.tcl
#
# Board in JTAG boot mode, JTAG cable connected, board powered. Nothing else
# is needed: no SD card, no FSBL, no boot image, no serial console.
#
# WHAT IT DOES
#
#   1. Builds build/led_top.bit from rtl/led_top.v if it is not there yet
#      (first run only; about ten minutes on this part).
#   2. Programs it over JTAG.
#   3. Self-test, automatic PASS/FAIL: writes patterns through the JTAG-to-AXI
#      master into the GPIO data registers and reads them back. This proves the
#      bitstream loaded, the debug hub answered, and the AXI path works.
#   4. LED walk: lights each LED on its own for a second so you can confirm the
#      silkscreen. Watch the board -- this is the part only your eyes can check.
#   5. J7 walk: drives one header pin high at a time so you can identify the
#      pin order with a meter.
#
# OPTIONS
#     -tclargs rebuild     force a rebuild even if the bitstream exists
#     -tclargs noprog      skip programming, test whatever is already loaded
#=============================================================================

set PART     xczu27dr-fsve1156-1-i
set HERE     [file normalize [file dirname [info script]]]
set BUILD    [file join $HERE build]
set BIT      [file join $BUILD led_top.bit]
set GPIO_BASE 0x44A00000

set do_build 1
set do_prog  1
foreach a $argv {
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
proc build_led {} {
    global PART HERE BUILD BIT

    puts "\n== building $BIT"
    file mkdir $BUILD
    create_project led_top [file join $BUILD proj] -part $PART -force

    add_files -norecurse [list [file join $HERE rtl led_top.v]]
    add_files -fileset constrs_1 -norecurse [list [file join $HERE led_top.xdc]]

    # ---- block design: JTAG-to-AXI master -> dual-channel AXI GPIO ----------
    create_bd_design "led_bd"

    set jtag [create_bd_cell -type ip -vlnv xilinx.com:ip:jtag_axi jtag_axi_0]
    # PROTOCOL 2 = AXI4-Lite, so the master can drive the GPIO directly with no
    # interconnect in between.
    set_property -dict [list CONFIG.PROTOCOL {2}] $jtag

    set gpio [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio axi_gpio_0]
    set_property -dict [list \
        CONFIG.C_IS_DUAL      {1} \
        CONFIG.C_ALL_OUTPUTS  {1} \
        CONFIG.C_GPIO_WIDTH   {3} \
        CONFIG.C_ALL_OUTPUTS_2 {1} \
        CONFIG.C_GPIO2_WIDTH  {6} \
    ] $gpio

    create_bd_port -dir I -type clk aclk
    create_bd_port -dir I -type rst aresetn
    set_property CONFIG.ASSOCIATED_RESET aresetn [get_bd_ports aclk]

    connect_bd_net [get_bd_ports aclk] \
        [get_bd_pins jtag_axi_0/aclk] [get_bd_pins axi_gpio_0/s_axi_aclk]
    connect_bd_net [get_bd_ports aresetn] \
        [get_bd_pins jtag_axi_0/aresetn] [get_bd_pins axi_gpio_0/s_axi_aresetn]
    connect_bd_intf_net [get_bd_intf_pins jtag_axi_0/M_AXI] \
                        [get_bd_intf_pins axi_gpio_0/S_AXI]

    make_bd_intf_pins_external -name led [get_bd_intf_pins axi_gpio_0/GPIO]
    make_bd_intf_pins_external -name j7  [get_bd_intf_pins axi_gpio_0/GPIO2]

    assign_bd_address
    set seg [get_bd_addr_segs -of_objects [get_bd_addr_spaces jtag_axi_0/Data]]
    set_property offset 0x44A00000 $seg
    set_property range  64K        $seg

    validate_bd_design
    save_bd_design

    set bd [get_files led_bd.bd]
    add_files -norecurse [list [make_wrapper -files $bd -top -force]]
    set_property top led_top [current_fileset]
    update_compile_order -fileset sources_1

    launch_runs synth_1 -jobs 8
    wait_on_run synth_1
    if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} {
        error "synthesis failed -- see [file join $BUILD proj led_top.runs synth_1]"
    }

    launch_runs impl_1 -to_step write_bitstream -jobs 8
    wait_on_run impl_1
    if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} {
        error "implementation failed -- see [file join $BUILD proj led_top.runs impl_1]"
    }

    file copy -force \
        [file join $BUILD proj led_top.runs impl_1 led_top.bit] $BIT
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
    # Any other Xilinx cable on this host shows up here too; take the one that
    # actually has an xczu27dr on it.
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
    # The debug hub needs a moment after configuration before it answers.
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

#-----------------------------------------------------------------------------
# 3. AXI helpers
#-----------------------------------------------------------------------------
proc axi_master {} {
    set m [get_hw_axis -quiet]
    if {[llength $m] == 0} {
        error "no JTAG-to-AXI master found. The bitstream in the device is not\
               this design, or configuration did not finish."
    }
    return [lindex $m 0]
}

proc axi_write {addr value} {
    set m [axi_master]
    create_hw_axi_txn -force w $m \
        -address [format %08X $addr] -data [format %08X $value] -type write
    run_hw_axi -quiet [get_hw_axi_txns w]
}

proc axi_read {addr} {
    set m [axi_master]
    create_hw_axi_txn -force r $m -address [format %08X $addr] -type read -len 1
    run_hw_axi -quiet [get_hw_axi_txns r]
    return [expr 0x[lindex [get_property DATA [get_hw_axi_txns r]] 0]]
}

#=============================================================================
# run
#=============================================================================
if {$do_build} { build_led } else { puts "== using existing $BIT" }

set dev [open_board]
if {$do_prog} { program_board $dev $BIT } else { puts "== skipping programming" }

set LED_DATA  [expr {$GPIO_BASE + 0x0}]
set J7_DATA   [expr {$GPIO_BASE + 0x8}]

#-----------------------------------------------------------------------------
# Self-test: the AXI path itself
#-----------------------------------------------------------------------------
puts "\n== AXI self-test"
set fails 0
foreach {reg mask name} [list $LED_DATA 0x7 "LED channel" $J7_DATA 0x3F "J7 channel"] {
    set bad 0
    foreach pat {0x0 0x1 0x2 0x4 0x15 0x2A 0x3F} {
        set want [expr {$pat & $mask}]
        axi_write $reg $want
        set got [expr {[axi_read $reg] & $mask}]
        if {$got != $want} {
            puts [format "   %-12s wrote 0x%02X  read 0x%02X   ** MISMATCH **" \
                    $name $want $got]
            incr bad
        }
    }
    if {$bad} {
        incr fails $bad
    } else {
        puts [format "   %-12s all patterns read back correctly" $name]
    }
}
axi_write $LED_DATA 0
axi_write $J7_DATA  0

if {$fails} {
    puts "\n== AXI SELF-TEST FAILED -- $fails mismatch(es)."
    puts "== The GPIO registers did not hold what was written, so nothing below"
    puts "== would mean anything. Check that build/led_top.bit is the bitstream"
    puts "== actually in the device."
    exit 1
}
puts "== AXI SELF-TEST PASSED"

#-----------------------------------------------------------------------------
# LED walk -- the part your eyes check
#-----------------------------------------------------------------------------
puts "\n== LED walk. Watch the board. Expected, three times over:"
puts "     led\[0\] alone  ->  the LED silkscreened DT1"
puts "     led\[1\] alone  ->  DT5"
puts "     led\[2\] alone  ->  DT4"
puts "     all three     ->  DT1 + DT5 + DT4"
puts "     all off"

for {set rep 1} {$rep <= 3} {incr rep} {
    foreach {val label} {1 "led\[0\] - DT1" 2 "led\[1\] - DT5" 4 "led\[2\] - DT4" 7 "all three" 0 "all off"} {
        axi_write $LED_DATA $val
        puts [format "   pass %d  0x%X  %s" $rep $val $label]
        after 1000
    }
}
axi_write $LED_DATA 0

#-----------------------------------------------------------------------------
# J7 walk -- identify the header pin order with a meter
#-----------------------------------------------------------------------------
puts "\n== J7 walk. Each header pin goes high on its own for two seconds."
puts "   J7.1 = +5 V, J7.2 = GND, J7.3 = +3.3 V -- do not short those."
puts "   Measure against J7.2."

for {set i 0} {$i < 6} {incr i} {
    axi_write $J7_DATA [expr {1 << $i}]
    puts [format "   J7.%d high" [expr {$i + 4}]]
    after 2000
}
axi_write $J7_DATA 0

puts "\n== done. The AXI self-test above is the automatic result; the LED and"
puts "== J7 walks are yours to confirm by looking at the board."
close_hw_manager
exit 0
