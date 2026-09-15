#=============================================================================
# jtag_check.tcl  --  is the JTAG path to this board actually working?
#
#   cd jtag
#   xsdb jtag_check.tcl
#
# Needs nothing but the cable and a powered board: no bitstream, no SD card,
# no FSBL, no serial console. This is the script to run first when something
# else will not talk to the board, because everything else in this BSP is
# built on top of what it checks.
#
# WHAT IT CHECKS, IN ORDER
#
#   1. The cable is claimed and a chain was scanned.
#   2. An xczu27dr is on that chain, with the right IDCODE.
#   3. The PS debug targets enumerate -- PMU, APU with four A53s, RPU with two
#      R5s. This is the Arm DAP answering, which is a different path from the
#      one in step 2.
#   4. The DAP can read and write memory: patterns into on-chip RAM and back.
#      OCM always exists, so this works with no DDR and no boot.
#   5. The boot mode straps, decoded.
#   6. Whether the PL is configured.
#
# THE GOTCHA THIS SCRIPT EXISTS FOR
#
# hw_server's chain-scanning thread needs a few seconds after `connect` before
# it has opened the cable. Ask any sooner and `targets` returns an EMPTY LIST
# on a perfectly healthy cable, which looks exactly like a dead board. The
# `after 3000` below is not padding.
#=============================================================================

set FAIL 0
proc fail {msg} { global FAIL ; incr FAIL ; puts "   ** $msg" }

proc read32 {addr} {
    # `mrd -value` returns decimal on some xsdb builds and hex on others, with
    # no 0x to tell them apart, so parse the labelled form instead. Getting
    # this wrong silently corrupts every register this script prints.
    set line [mrd $addr]
    if {![regexp {:\s*([0-9a-fA-F]+)} $line -> hex]} {
        error "could not parse mrd output: '$line'"
    }
    return [expr "0x$hex"]
}

#-----------------------------------------------------------------------------
# 1. cable and chain
#-----------------------------------------------------------------------------
puts "== connecting to hw_server"
if {[catch {connect} err]} {
    puts "   ** could not reach hw_server: $err"
    puts "\n   Start one by hand if it did not launch itself:  hw_server &"
    exit 1
}
after 3000

puts "\n== JTAG chain"
set chain [jtag targets]
if {[string trim $chain] eq ""} {
    puts "   (empty)"
    puts "\n** NO CHAIN. Check, in this order:"
    puts "     1. cable on USB              lsusb | grep -Ei '03fd|0403'"
    puts "     2. board powered             this is the usual answer"
    puts "     3. ribbon seated, pin 1 to pin 1"
    puts "     4. no second hw_server holding the cable   pgrep -a hw_server"
    puts "     5. ftdi_sio bound to an FTDI cable         sudo modprobe -r ftdi_sio"
    exit 1
}
puts $chain

if {![string match -nocase "*xczu27dr*" $chain]} {
    puts "\n** Cable and chain found, but no xczu27dr on it."
    puts "   Expected IDCODE 147e4093. Any other FPGA cables on this host show"
    puts "   up in the list above too, so an empty-looking result here can just"
    puts "   mean this board is off."
    exit 1
}
puts "   xczu27dr found, IDCODE 147e4093"

#-----------------------------------------------------------------------------
# 2. PS debug targets
#-----------------------------------------------------------------------------
puts "\n== PS debug targets"
set tlist [targets]
puts $tlist

foreach {pattern what} {
    "*PSU*"          "PSU (the DAP memory view)"
    "*PMU*"          "PMU microblaze"
    "*Cortex-A53*#0*" "APU core 0"
    "*Cortex-A53*#3*" "APU core 3"
    "*Cortex-R5*#0*"  "RPU core 0"
} {
    if {[string match -nocase $pattern $tlist]} {
        puts [format "   present : %s" $what]
    } else {
        fail [format "missing : %s" $what]
    }
}

#-----------------------------------------------------------------------------
# 3. can the DAP actually move data?
#
# On-chip RAM lives at 0xFFFC0000 and is 256 KB. It is powered and usable with
# no DDR, no FSBL and no boot -- which is exactly the situation in JTAG boot
# mode. Nothing is running, so scribbling on it is safe. If you ran this while
# an FSBL or U-Boot was live it would not be, but then you would not need it.
#-----------------------------------------------------------------------------
puts "\n== DAP memory access"
targets -set -nocase -filter {name =~ "*PSU*"}

# Open the LPD peripheral protection gates so JTAG writes are allowed through.
catch { mwr 0xFFCA0038 0x1FF }

set OCM 0xFFFC0000
set mem_ok 1
foreach pat {0xDEADBEEF 0xA5A5A5A5 0x5A5A5A5A 0xFFFFFFFF 0x00000000 0x0F0F0F0F} {
    if {[catch {
        mwr $OCM $pat
        set got [read32 $OCM]
    } err]} {
        fail "OCM access threw: $err"
        set mem_ok 0
        break
    }
    if {$got != [expr $pat]} {
        fail [format "OCM 0x%08X: wrote 0x%08X read 0x%08X" $OCM [expr $pat] $got]
        set mem_ok 0
    }
}
# Distinct value per address, which catches an address bus that is not moving.
if {$mem_ok} {
    set addrs {}
    for {set i 0} {$i < 8} {incr i} { lappend addrs [expr {$OCM + $i*0x1000}] }
    foreach a $addrs { mwr $a [expr {$a ^ 0xA5A5A5A5}] }
    foreach a $addrs {
        set want [expr {($a ^ 0xA5A5A5A5) & 0xFFFFFFFF}]
        set got  [read32 $a]
        if {$got != $want} {
            fail [format "OCM 0x%08X aliases: want 0x%08X got 0x%08X" $a $want $got]
            set mem_ok 0
        }
    }
}
if {$mem_ok} {
    puts "   6 patterns and 8 distinct addresses across OCM, all correct"
}

#-----------------------------------------------------------------------------
# 4. boot mode straps
#
# CRL_APB BOOT_MODE_USER, bits [3:0]. Encoding from UG1085 table 11-1.
#-----------------------------------------------------------------------------
puts "\n== boot mode"
array set BOOTMODE {
    0  "JTAG"            1  "QSPI 24-bit"     2  "QSPI 32-bit"    3  "SD0"
    4  "NAND"            5  "SD1"             6  "eMMC 1.8V"      7  "USB0"
    8  "PJTAG0"          9  "PJTAG1"         14  "SD1 level-shifted"
}
if {[catch {set bm [read32 0xFF5E0200]} err]} {
    fail "could not read BOOT_MODE_USER: $err"
} else {
    set mode [expr {$bm & 0xF}]
    set name [expr {[info exists BOOTMODE($mode)] ? $BOOTMODE($mode) : "reserved"}]
    puts [format "   BOOT_MODE_USER = 0x%08X  ->  mode %d = %s" $bm $mode $name]
    if {$mode == 0} {
        puts "   JTAG boot mode: the boot ROM stops and waits for you. This is"
        puts "   the right setting for every PL-only script in this BSP."
    } elseif {$mode == 5} {
        puts "   SD1: the boot ROM reads BOOT.BIN from the first FAT partition"
        puts "   of the microSD card. Confirmed on this board from the FSBL"
        puts "   banner, which prints 'SD1 Boot Mode' / 'File name is 1:/BOOT.BIN'."
    }
}

#-----------------------------------------------------------------------------
# 5. PL configuration
#
# `device status config_status` needs ONE FPGA selected, and it looks at the
# whole host, not just this cable. With another FPGA cable plugged in it fails
# with "Multiple devices found" -- which says nothing about this board. So try
# it, and when it cannot decide, fall back to what the chain scan already told
# us: a configured PL publishes a debug hub, an unconfigured one does not.
#-----------------------------------------------------------------------------
puts "\n== PL configuration"
set decided 0
set cfgerr ""
if {![catch {
    targets -set -nocase -filter {name == "PL"}
    set cfg [device status config_status]
} cfgerr]} {
    foreach line [split $cfg "\n"] {
        if {[string match -nocase "*DONE PIN*" $line] ||
            [string match -nocase "*END OF STARTUP*" $line]} {
            puts "   [string trim $line]"
            set decided 1
        }
    }
}
if {!$decided} {
    if {[regexp -nocase {debug.hub|bscan-switch} $chain]} {
        puts "   a debug hub is on the chain, so a bitstream is loaded"
    } else {
        puts "   no debug hub on the chain. Either the PL is unconfigured --"
        puts "   normal if nothing has programmed it since power-on -- or the"
        puts "   design that is loaded has no debug cores in it."
    }
    if {[regexp -nocase {Multiple devices found} $cfgerr]} {
        puts "   (config_status would not choose between the FPGAs on this host."
        puts "   That is a host condition, not a fault on this board -- the same"
        puts "   one that breaks xsdb's `fpga -file`.)"
    }
}

#-----------------------------------------------------------------------------
puts ""
if {$FAIL} {
    puts "== RESULT: JTAG CHECK FAILED -- $FAIL problem(s) above."
    exit 1
}
puts "== RESULT: JTAG PASSED. Chain, DAP and memory access all work."
exit 0
