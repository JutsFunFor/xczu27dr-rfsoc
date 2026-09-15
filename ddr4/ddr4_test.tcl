#=============================================================================
# ddr4_test.tcl  --  bring up the PS DDR4 over JTAG and prove it works
#
#   cd ddr4
#   vivado -mode batch -source build.tcl     # once, makes build/psu_init.tcl
#   xsdb ddr4_test.tcl
#
# Board in JTAG boot mode, JTAG cable connected, board powered. No SD card, no
# FSBL, no boot image, no serial console.
#
# WHAT IT DOES
#
#   Drives exactly the sequence an FSBL would: psu_init programs the MIO, the
#   PLLs and the clocks, then the DDR controller and DDR PHY, then triggers PHY
#   training and polls for it to finish. This script then reads PGSR0 and says
#   which training stage passed or failed, and finally uses the memory for
#   real -- patterns across the range, and a distinct value per address to
#   catch a bus that aliases.
#
#   Calibration passing is necessary but not sufficient. A partially trained
#   bus can report all-done and still fold two addresses onto each other, so
#   the pattern test matters as much as the register decode.
#
# PGSR0 = 0xFD080030, DDR PHY General Status Register 0. The field names and
# the error mask below are from Xilinx's own PMU firmware source,
# lib/sw_apps/zynqmp_pmufw/src/pm_ddr.c, and "all 12 done bits" is what
# psu_init itself polls for:  poll 0xFD080030 0x00000FFF 0x00000FFF
#=============================================================================

set HERE  [file normalize [file dirname [info script]]]
set INIT  [file join $HERE build psu_init.tcl]
set PGSR0 0xFD080030

if {![file exists $INIT]} {
    puts "== ERROR: $INIT does not exist."
    puts "== Generate it first:   vivado -mode batch -source build.tcl"
    exit 1
}

# bit -> name, description, for the training DONE bits [11:0]
set DONE_BITS {
    0  IDONE      "Initialization"
    1  PLDONE     "PLL lock"
    2  DCDONE     "Digital delay line calibration"
    3  ZCDONE     "Impedance (ZQ) calibration"
    4  DIDONE     "DRAM initialization"
    5  WLDONE     "Write levelling"
    6  QSGDONE    "DQS gate training"
    7  WLADONE    "Write levelling adjustment"
    8  RDDONE     "Read bit deskew"
    9  WDDONE     "Write bit deskew"
    10 REDONE     "Read eye training"
    11 WEDONE     "Write eye training"
}

# bit -> name, description, for the error flags. From DDRPHY_PGSR0_TRAIN_ERRS.
set ERR_BITS {
    18 DQS2DQERR  "DQS-to-DQ training"
    19 VERR       "VREF training"
    20 ZCERR      "Impedance calibration"
    21 WLERR      "Write levelling"
    22 QSGERR     "DQS gate training"
    23 WLAERR     "Write levelling adjustment"
    24 RDERR      "Read bit deskew"
    25 WDERR      "Write bit deskew"
    26 REERR      "Read eye training"
    27 WEERR      "Write eye training"
    28 CAERR      "CA training"
    29 CAWRN      "CA training warning"
    30 SRDERR     "Static read"
}

proc bitset {val bit} { return [expr {($val >> $bit) & 1}] }

#-----------------------------------------------------------------------------
# READING A REGISTER CORRECTLY -- this is a trap worth spelling out.
#
# `mrd -value` returns the value in DECIMAL on xsdb 2025.2 and in HEX on some
# other builds, and it never carries a 0x to tell you which. Parsing it with
# `scan %x` therefore corrupts the result silently: a perfectly healthy PGSR0
# of 0x80004FFF comes back as the decimal string "2147504127", gets read as
# hex, and produces the impossible 40-bit 0x2147504127 -- which decodes as 7
# failed training stages and 6 errors. A passing board reported as a hard fail.
#
# The plain `mrd` form always prints "ADDR:   HEXVALUE". Parse that, and range
# check it.
#-----------------------------------------------------------------------------
proc read32 {addr} {
    set line [mrd $addr]
    if {![regexp {:\s*([0-9a-fA-F]+)} $line -> hex]} {
        error "could not parse mrd output: '$line'"
    }
    set v [expr "0x$hex"]
    if {$v < 0 || $v > 0xFFFFFFFF} {
        error [format "mrd returned something that does not fit in 32 bits: 0x%X" $v]
    }
    return $v
}

#-----------------------------------------------------------------------------
puts "== connecting to hw_server"
connect
after 3000

targets -set -nocase -filter {name =~ "*PSU*"}
# Open the security gates so JTAG is allowed to write PS registers.
mwr 0xFFCA0038 0x1FF

targets -set -nocase -filter {name =~ "*Cortex-A53*#0*"}
rst -processor
after 500

puts "== running psu_init: $INIT"
puts "== (this programs the DDR controller and PHY, then trains)"
if {[catch {source $INIT ; psu_init} err]} {
    puts "\n== psu_init DID NOT COMPLETE: $err"
    puts "== psu_init polls PGSR0 for training to finish, so a hang or an error"
    puts "== here usually IS the calibration failure. Reading PGSR0 anyway."
}

targets -set -nocase -filter {name =~ "*PSU*"}

if {[catch {set val [read32 $PGSR0]} err]} {
    puts "== ERROR reading PGSR0: $err"
    exit 1
}
puts [format "\n== PGSR0 (%s) = 0x%08X\n" $PGSR0 $val]

set failed 0
puts "   Training stages:"
foreach {bit name desc} $DONE_BITS {
    if {[bitset $val $bit]} {
        puts [format "     \[%2d\] %-9s %-34s PASS" $bit $name $desc]
    } else {
        puts [format "     \[%2d\] %-9s %-34s ** NOT DONE **" $bit $name $desc]
        incr failed
    }
}

set errs 0
foreach {bit name desc} $ERR_BITS {
    if {[bitset $val $bit]} {
        if {!$errs} { puts "\n   Errors reported:" }
        puts [format "     \[%2d\] %-9s %-34s ** ERROR **" $bit $name $desc]
        incr errs
    }
}

puts ""
puts [format "   \[15\] DQS2DQDONE  DQS-to-DQ training                 %s" \
        [expr {[bitset $val 15] ? "done" : "not done"}]]
puts [format "   \[31\] APLOCK      PHY analog PLL lock                %s" \
        [expr {[bitset $val 31] ? "locked" : "NOT LOCKED"}]]
puts ""

if {$failed || $errs} {
    puts "== RESULT: DDR4 CALIBRATION FAILED -- $failed stage(s) not done, $errs error(s)."
    puts "== The first stage listed NOT DONE is where it stopped; everything"
    puts "== after it never ran. Read that stage name as a hint about what is"
    puts "== wrong: PLL lock points at the reference clock, DRAM initialization"
    puts "== at the address or command wiring, write levelling and DQS gate"
    puts "== training at the data byte lanes."
    exit 1
}
puts "== DDR4 CALIBRATION PASSED -- all 12 training stages done, no errors."

#-----------------------------------------------------------------------------
# Actually use the memory.
#
# Addresses are in the low 2 GB window, 0x0000_0000 - 0x7FEF_FFFF. Above that,
# 0x7FF0_0000 - 0x7FFF_FFFF is reserved for the PMU and the other 2 GB lives up
# at 0x8_0000_0000.
#-----------------------------------------------------------------------------
puts "\n== memory test"
set patterns {0xDEADBEEF 0xA5A5A5A5 0x5A5A5A5A 0xFFFFFFFF 0x00000000}
set addrs    {0x00100000 0x10000000 0x20000000 0x40000000 0x7FE00000}
set memfail  0

foreach a $addrs {
    set bad 0
    foreach pat $patterns {
        mwr $a $pat
        set rb [read32 $a]
        if {$rb != [expr $pat]} {
            puts [format "   %s  wrote 0x%08X  read 0x%08X  ** MISMATCH **" \
                    $a [expr $pat] $rb]
            incr bad ; incr memfail
        }
    }
    if {!$bad} { puts [format "   %s  all %d patterns OK" $a [llength $patterns]] }
}

# A distinct value per address. This is what catches a partially trained bus
# that passes every single-address pattern and still wraps two addresses onto
# the same storage.
foreach a $addrs { mwr $a [expr {$a ^ 0xA5A5A5A5}] }
foreach a $addrs {
    set want [expr {($a ^ 0xA5A5A5A5) & 0xFFFFFFFF}]
    set got  [read32 $a]
    if {$got != $want} {
        puts [format "   %s ALIASES -- want 0x%08X got 0x%08X" $a $want $got]
        incr memfail
    }
}

puts ""
if {$memfail} {
    puts "== RESULT: MEMORY TEST FAILED -- $memfail mismatch(es) although"
    puts "== calibration passed. That points at signal integrity, or at the"
    puts "== address map and device size being configured wrong."
    exit 1
}
puts "== RESULT: DDR4 PASSED -- calibration clean, patterns hold, every"
puts "== address distinct."
puts "== For eye margins rather than pass/fail, run the DRAM Diagnostics app"
puts "== from Vitis against this same psu_init."
exit 0
