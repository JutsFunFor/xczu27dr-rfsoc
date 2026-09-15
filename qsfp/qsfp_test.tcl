#=============================================================================
# qsfp_test.tcl  --  bring up and test both QSFP28 cages
#
#   cd qsfp
#   vivado -mode batch -source qsfp_test.tcl
#
# Board in JTAG boot mode, JTAG cable connected, board powered. No SD card, no
# FSBL, no boot image, no serial console.
#
# WHAT IT DOES
#
#   1. Builds build/qsfp_top.bit from rtl/qsfp_top.v if it is not there yet
#      (first run only; about ten minutes on this part).
#   2. Programs it over JTAG.
#   3. Reads ModPrsL and IntL on both cages and says which cages have a module.
#   4. Exercises the three control outputs on each cage -- ResetL, ModSelL,
#      LPMode -- and confirms the register path.
#   5. If a module is present: selects it with ModSelL, reads SFF-8636 page 0
#      over that cage's I2C bus, and prints the identifier, vendor name and
#      part number. That is the end-to-end proof -- sideband pins, I2C pins,
#      pull-ups and the module itself, all at once.
#
# With no module fitted, steps 3 and 4 still give a real result: both ModPrsL
# lines must read HIGH (nothing plugged in) and must go LOW when you insert
# something. Step 5 is skipped and says so.
#
# OPTIONS
#     -tclargs rebuild     force a rebuild even if the bitstream exists
#     -tclargs noprog      skip programming, test whatever is already loaded
#=============================================================================

set PART   xczu27dr-fsve1156-1-i
set HERE   [file normalize [file dirname [info script]]]
set BUILD  [file join $HERE build]
set BIT    [file join $BUILD qsfp_top.bit]

set GPIO_BASE 0x44A00000
set IIC0_BASE 0x44A10000
set IIC1_BASE 0x44A20000

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
proc build_qsfp {} {
    global PART HERE BUILD BIT

    puts "\n== building $BIT"
    file mkdir $BUILD
    create_project qsfp_top [file join $BUILD proj] -part $PART -force

    add_files -norecurse [list [file join $HERE rtl qsfp_top.v]]
    add_files -fileset constrs_1 -norecurse [list [file join $HERE qsfp_top.xdc]]

    create_bd_design "qsfp_bd"

    # JTAG-to-AXI master, AXI4-Lite (PROTOCOL 2).
    set jtag [create_bd_cell -type ip -vlnv xilinx.com:ip:jtag_axi jtag_axi_0]
    set_property -dict [list CONFIG.PROTOCOL {2}] $jtag

    # Three slaves, so an interconnect is needed.
    set sc [create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect smartconnect_0]
    set_property -dict [list CONFIG.NUM_SI {1} CONFIG.NUM_MI {3}] $sc

    # Sideband GPIO: channel 1 = 6 control outputs, channel 2 = 4 status inputs.
    set gpio [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio axi_gpio_0]
    set_property -dict [list \
        CONFIG.C_IS_DUAL      {1} \
        CONFIG.C_ALL_OUTPUTS  {1} \
        CONFIG.C_GPIO_WIDTH   {6} \
        CONFIG.C_ALL_INPUTS_2 {1} \
        CONFIG.C_GPIO2_WIDTH  {4} \
    ] $gpio

    # One I2C controller per cage -- the two cages are separate buses.
    foreach i {0 1} {
        set iic [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_iic axi_iic_$i]
        set_property -dict [list CONFIG.C_SCL_INERTIAL_DELAY {5}] $iic
    }

    create_bd_port -dir I -type clk aclk
    # axi_iic derives its SCL divider from the declared AXI clock rate, and
    # smartconnect wants to know it too. CFGMCLK is nominally 50 MHz.
    set_property CONFIG.FREQ_HZ 50000000 [get_bd_ports aclk]
    create_bd_port -dir I -type rst aresetn
    set_property CONFIG.ASSOCIATED_RESET aresetn [get_bd_ports aclk]

    connect_bd_net [get_bd_ports aclk] \
        [get_bd_pins jtag_axi_0/aclk] [get_bd_pins smartconnect_0/aclk] \
        [get_bd_pins axi_gpio_0/s_axi_aclk] \
        [get_bd_pins axi_iic_0/s_axi_aclk] [get_bd_pins axi_iic_1/s_axi_aclk]
    connect_bd_net [get_bd_ports aresetn] \
        [get_bd_pins jtag_axi_0/aresetn] [get_bd_pins smartconnect_0/aresetn] \
        [get_bd_pins axi_gpio_0/s_axi_aresetn] \
        [get_bd_pins axi_iic_0/s_axi_aresetn] [get_bd_pins axi_iic_1/s_axi_aresetn]

    connect_bd_intf_net [get_bd_intf_pins jtag_axi_0/M_AXI] \
                        [get_bd_intf_pins smartconnect_0/S00_AXI]
    connect_bd_intf_net [get_bd_intf_pins smartconnect_0/M00_AXI] \
                        [get_bd_intf_pins axi_gpio_0/S_AXI]
    connect_bd_intf_net [get_bd_intf_pins smartconnect_0/M01_AXI] \
                        [get_bd_intf_pins axi_iic_0/S_AXI]
    connect_bd_intf_net [get_bd_intf_pins smartconnect_0/M02_AXI] \
                        [get_bd_intf_pins axi_iic_1/S_AXI]

    make_bd_intf_pins_external -name ctl  [get_bd_intf_pins axi_gpio_0/GPIO]
    make_bd_intf_pins_external -name sts  [get_bd_intf_pins axi_gpio_0/GPIO2]
    make_bd_intf_pins_external -name iic0 [get_bd_intf_pins axi_iic_0/IIC]
    make_bd_intf_pins_external -name iic1 [get_bd_intf_pins axi_iic_1/IIC]

    assign_bd_address
    foreach {cell off} {axi_gpio_0 0x44A00000 axi_iic_0 0x44A10000 axi_iic_1 0x44A20000} {
        set seg [get_bd_addr_segs -of_objects [get_bd_addr_spaces jtag_axi_0/Data] \
                    -filter "NAME =~ *${cell}*"]
        set_property offset $off $seg
        set_property range  64K  $seg
    }

    validate_bd_design
    save_bd_design

    set bd [get_files qsfp_bd.bd]
    add_files -norecurse [list [make_wrapper -files $bd -top -force]]
    set_property top qsfp_top [current_fileset]
    update_compile_order -fileset sources_1

    launch_runs synth_1 -jobs 8
    wait_on_run synth_1
    if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} {
        error "synthesis failed -- see [file join $BUILD proj qsfp_top.runs synth_1]"
    }
    launch_runs impl_1 -to_step write_bitstream -jobs 8
    wait_on_run impl_1
    if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} {
        error "implementation failed -- see [file join $BUILD proj qsfp_top.runs impl_1]"
    }

    file copy -force \
        [file join $BUILD proj qsfp_top.runs impl_1 qsfp_top.bit] $BIT
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
    create_hw_axi_txn -force w [axi_master] \
        -address [format %08X $addr] -data [format %08X $value] -type write
    run_hw_axi -quiet [get_hw_axi_txns w]
}
proc axi_read {addr} {
    create_hw_axi_txn -force r [axi_master] \
        -address [format %08X $addr] -type read -len 1
    run_hw_axi -quiet [get_hw_axi_txns r]
    return [expr 0x[lindex [get_property DATA [get_hw_axi_txns r]] 0]]
}

#-----------------------------------------------------------------------------
# 4. AXI IIC, dynamic mode
#
# Register offsets and bit positions are from PG090, "AXI IIC Bus Interface".
#   0x040 SOFTR     write 0x0A to reset the core
#   0x100 CR        bit0 EN, bit1 TX_FIFO_RESET
#   0x104 SR        bit2 BB bus-busy, bit6 RX_FIFO_EMPTY
#   0x108 TX_FIFO   bit8 = send START before this byte, bit9 = send STOP after
#   0x10C RX_FIFO
#   0x118 RX_FIFO_OCY
#
# Dynamic mode reads a byte-addressed device in one shot: address the slave for
# write, send the byte offset, re-START for read, then ask for N bytes.
#-----------------------------------------------------------------------------
proc iic_reset {base} {
    axi_write [expr {$base + 0x040}] 0x0A       ;# SOFTR
    after 20
    axi_write [expr {$base + 0x100}] 0x02       ;# CR: TX FIFO reset
    axi_write [expr {$base + 0x100}] 0x01       ;# CR: enable, release FIFO reset
    after 20
    # SOFTR empties the TX FIFO but not the RX FIFO. Drain whatever is left so
    # a stale byte does not come back as the first byte of the next read.
    for {set i 0} {$i < 32} {incr i} {
        if {[axi_read [expr {$base + 0x104}]] & 0x40} { break }   ;# RX empty
        axi_read [expr {$base + 0x10C}]
    }
}

# Reset the core ONCE per cage, then do as many reads as you like. Resetting
# between transfers is what wedges this bus: SOFTR drops the core mid-bus
# while the module is still clocking out a byte, the module holds SDA low
# waiting for a clock that never comes, and every read after that times out.
proc iic_read {base slave7 offset n} {
    set CR  [expr {$base + 0x100}]
    set SR  [expr {$base + 0x104}]
    set TX  [expr {$base + 0x108}]
    set RX  [expr {$base + 0x10C}]

    # The bus must be idle before we start. SDA held low by a confused module
    # reads as busy and never clears, so recover the core if it does not.
    set idle 0
    for {set i 0} {$i < 50} {incr i} {
        if {!([axi_read $SR] & 0x04)} { set idle 1 ; break }
        after 20
    }
    if {!$idle} {
        iic_reset $base
        for {set i 0} {$i < 50} {incr i} {
            if {!([axi_read $SR] & 0x04)} { set idle 1 ; break }
            after 20
        }
        if {!$idle} { return {} }
    }

    # Dynamic mode: address the slave for write, send the byte offset, repeated
    # START for read, then ask for n bytes. Bit 8 = send START before this
    # byte, bit 9 = send STOP after it.
    axi_write $TX [expr {0x100 | ($slave7 << 1)}]
    axi_write $TX [expr {$offset & 0xFF}]
    axi_write $TX [expr {0x100 | ($slave7 << 1) | 1}]
    axi_write $TX [expr {0x200 | $n}]

    # SR bit 6 is RX_FIFO_EMPTY. Drain a byte whenever it clears; give up after
    # a second of nothing, which is what a module that never ACKed looks like.
    set out  {}
    set idle 0
    while {[llength $out] < $n && $idle < 100} {
        if {[axi_read $SR] & 0x40} {
            incr idle
            after 10
        } else {
            set idle 0
            lappend out [expr {[axi_read $RX] & 0xFF}]
        }
    }

    # Let the STOP finish before the caller starts another transfer.
    for {set i 0} {$i < 50} {incr i} {
        if {!([axi_read $SR] & 0x04)} { break }
        after 10
    }
    if {[llength $out] < $n} { return {} }
    return $out
}

proc bytes_to_ascii {bytes} {
    set s ""
    foreach b $bytes {
        if {$b >= 32 && $b < 127} { append s [format %c $b] } else { append s "." }
    }
    return [string trim $s]
}

#=============================================================================
# run
#=============================================================================
if {$do_build} { build_qsfp } else { puts "== using existing $BIT" }

set dev [open_board]
if {$do_prog} { program_board $dev $BIT } else { puts "== skipping programming" }

set CTL [expr {$GPIO_BASE + 0x0}]
set STS [expr {$GPIO_BASE + 0x8}]

# Park everything benign: ResetL high, ModSelL high, LPMode low.
axi_write $CTL 0x00
after 100

#-----------------------------------------------------------------------------
# Cage status
#-----------------------------------------------------------------------------
puts "\n== cage status (raw pin levels; both lines are active LOW)"
set sts [axi_read $STS]
puts [format "   status register = 0x%X" $sts]

array set present {}
foreach {cage prs int} {0 0 1 1 2 3} {
    set p [expr {($sts >> $prs) & 1}]
    set i [expr {($sts >> $int) & 1}]
    set present($cage) [expr {$p == 0}]
    puts [format "   cage %d  ModPrsL=%d -> %-18s   IntL=%d -> %s" \
            $cage $p [expr {$p ? "no module fitted" : "MODULE PRESENT"}] \
            $i [expr {$i ? "no interrupt" : "INTERRUPT ASSERTED"}]]
}

#-----------------------------------------------------------------------------
# Control outputs
#-----------------------------------------------------------------------------
puts "\n== control outputs"
set fails 0
foreach {bit name} {0 "cage 0 ResetL" 1 "cage 0 ModSelL" 2 "cage 0 LPMode"
                    3 "cage 1 ResetL" 4 "cage 1 ModSelL" 5 "cage 1 LPMode"} {
    set v [expr {1 << $bit}]
    axi_write $CTL $v
    set rb [expr {[axi_read $CTL] & 0x3F}]
    if {$rb != $v} {
        puts [format "   %-16s wrote 0x%02X read 0x%02X  ** MISMATCH **" $name $v $rb]
        incr fails
    } else {
        puts [format "   %-16s asserted and read back" $name]
    }
}
axi_write $CTL 0x00
if {$fails} {
    puts "\n== CONTROL TEST FAILED -- $fails register(s) did not hold their value."
    exit 1
}
puts "== CONTROL TEST PASSED"

#-----------------------------------------------------------------------------
# Module I2C
#-----------------------------------------------------------------------------
puts "\n== module I2C (SFF-8636 page 0, slave address 0x50)"
set any 0
foreach {cage base modsel} [list 0 $IIC0_BASE 1 1 $IIC1_BASE 4] {
    if {!$present($cage)} {
        puts "   cage $cage  skipped, no module fitted"
        continue
    }
    set any 1
    # ModSelL must be LOW for the module to answer on I2C.
    axi_write $CTL [expr {1 << $modsel}]
    after 50
    iic_reset $base

    set id [iic_read $base 0x50 0 1]
    if {[llength $id] == 0} {
        puts "   cage $cage  module present but did not answer on I2C"
        puts "              check the 4k7 pull-ups to QSFP_VCCT and that the"
        puts "              cage is powered"
        axi_write $CTL 0x00
        continue
    }
    # SFF-8024 identifier values, in decimal because that is what iic_read gives.
    set idv [lindex $id 0]
    switch -- $idv {
        12      { set idname "QSFP" }
        13      { set idname "QSFP+" }
        17      { set idname "QSFP28" }
        24      { set idname "QSFP-DD" }
        0       { set idname "not specified" }
        255     { set idname "not specified - common on passive copper cables" }
        default { set idname "unrecognised - see SFF-8024 table 4-1" }
    }
    puts [format "   cage %d  identifier byte 0 = 0x%02X  (%s)" $cage $idv $idname]

    # Bytes 0-127 are the lower page; 128-255 are whichever upper page byte 127
    # selects. Vendor name and part number live in upper page 00h, which is the
    # default after reset, so this works on a module nobody has poked at.
    set vendor [iic_read $base 0x50 148 16]
    set partno [iic_read $base 0x50 168 16]
    if {[llength $vendor]} { puts "   cage $cage  vendor    : [bytes_to_ascii $vendor]" }
    if {[llength $partno]} { puts "   cage $cage  part      : [bytes_to_ascii $partno]" }

    axi_write $CTL 0x00
}
if {!$any} {
    puts "   no modules fitted, so nothing to read. Plug a QSFP28 module or a"
    puts "   loopback into a cage and run this again -- ModPrsL above should"
    puts "   flip to MODULE PRESENT and the identifier should appear here."
}

axi_write $CTL 0x00
puts "\n== done"
close_hw_manager
exit 0
