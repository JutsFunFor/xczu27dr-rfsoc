# =============================================================================
# eth_verify.tcl - end-to-end Ethernet check: GEM3 puts frames on the wire and
# the host NIC counts them as good.
#
#   cd ethernet
#   vivado -mode batch -source build.tcl      # once, makes build/psu_init.tcl
#   sudo ip addr add 192.168.2.1/24 dev <nic>
#   ZU27DR_NIC=<nic> xsdb eth_verify.tcl
#
# Board in JTAG boot mode, JTAG cable connected, Ethernet cable from the board
# straight into the host NIC named above. No SD card and no boot image: this
# script brings the PS up itself by running the psu_init that build.tcl
# generated, exactly as an FSBL would.
#
# WHAT IT PROVES
#
#   The MAC is told to transmit N frames, and the HOST's own counters are read
#   before and after. Passing means the host's NIC accepted them as good
#   frames with a correct FCS -- not merely that GEM3's transmit counter went
#   up, which it will do happily while nothing at all reaches the wire.
#
# THREE THINGS THAT FAIL SILENTLY
#
#   The MAC increments frames_transmitted regardless of all of these:
#
#     dma_config    (0x010)  INCR16 burst, 8 K RX buffer, TX store-and-forward
#     laddr1        (0x088)  transmit is dropped with no source address set
#     receive_q_ptr (0x018)  left at reset with RX enabled, the DMA wedges
#
#   And the MDIO block is dead until the management port is enabled and the MDC
#   divider is set. All four are done below, in that order -- the management
#   port MUST be up before the first MDIO access or every register reads 0x0000.
#
# THE PHY
#
#   Realtek RTL8211FD at MDIO address 7, RGMII. Its RGMII delay register
#   (page 0xd08, register 0x11) must stay at its strapped 0x0109. Setting
#   0x0009 gives frames with a wrong FCS; 0x0100 stops transmit dead.
# =============================================================================
# the host NIC cabled to the board; override with ZU27DR_NIC
set NIC [expr {[info exists ::env(ZU27DR_NIC)] ? $::env(ZU27DR_NIC) : "eth0"}]
set GEM 0xFF0E0000
set BDR 0xFFFC0000
set BUF 0xFFFC0100
set PHY 7
set INIT [file join [file dirname [file normalize [info script]]] build psu_init.tcl]

proc read32 {addr} { set out [mrd $addr]; return [expr 0x[lindex [split [string trim $out]] end]] }
proc mask_write {addr mask val} { set cur [read32 $addr]; mwr $addr [expr {($cur & ~$mask) | ($val & $mask)}] }
proc host {s} { global NIC; return [string trim [exec cat /sys/class/net/$NIC/statistics/$s]] }
proc mdio_read {phy reg} {
    mwr 0xFF0E0034 [expr {0x60020000 | ($phy << 23) | ($reg << 18)}]
    for {set i 0} {$i < 200} {incr i} { if {[read32 0xFF0E0008] & 0x4} break; after 1 }
    return [expr {[read32 0xFF0E0034] & 0xFFFF}]
}
proc mdio_write {phy reg val} {
    mwr 0xFF0E0034 [expr {0x50020000 | ($phy << 23) | ($reg << 18) | ($val & 0xFFFF)}]
    for {set i 0} {$i < 200} {incr i} { if {[read32 0xFF0E0008] & 0x4} break; after 1 }
}

if {![file exists $INIT]} {
    puts "== ERROR: $INIT does not exist."
    puts "== Generate it first:   vivado -mode batch -source build.tcl"
    exit 1
}

connect
after 3000
targets -set -nocase -filter {name =~ "*PSU*"}
mwr 0xFFCA0038 0x1FF                     ;# open LPD peripheral protection

targets -set -nocase -filter {name =~ "*Cortex-A53*#0*"}
catch {stop}
rst -processor
after 500

# psu_init does what an FSBL's first job is: MIO mux, PLLs, peripheral clocks,
# and releasing GEM3 from reset. Without it the MAC registers read back but the
# block is clock-gated and held in reset, so nothing ever reaches the pins.
puts "== running psu_init: $INIT"
if {[catch {source $INIT ; psu_init} err]} {
    puts "== psu_init reported: $err"
    puts "== continuing anyway -- some stages poll for things this board does"
    puts "== not have, and GEM3 may still be configured. The checks below will"
    puts "== say whether it is."
}

targets -set -nocase -filter {name =~ "*PSU*"}

puts [format "== GEM3_REF_CTRL %08X  RST_LPD_IOU0 %08X (bit3=gem3 rst)" \
      [read32 0xFF5E005C] [read32 0xFF5E0230]]

# The MDIO block is dead until the management port is enabled and the MDC
# divider is set. Do this BEFORE the first MDIO access or every register reads
# back 0x0000 and the PHY looks absent.
#   net_cfg[20:18] = MDC divider, 0b100 = pclk/64, safe for a 100 MHz pclk
#   net_ctrl[4]    = management port enable
mask_write [expr {$GEM + 0x004}] 0x001C0000 0x00100000
mask_write [expr {$GEM + 0x000}] 0x00000010 0x00000010
after 10
puts [format "== net_ctrl %08X  net_cfg %08X (management port up)" \
      [read32 [expr {$GEM + 0x000}]] [read32 [expr {$GEM + 0x004}]]]
puts [format "== PHY@%d  id2 0x%04X  BMCR 0x%04X  BMSR 0x%04X" \
      $PHY [mdio_read $PHY 2] [mdio_read $PHY 0] [mdio_read $PHY 1]]

mdio_write $PHY 9 0x0200                 ;# advertise 1000BASE-T full
mdio_write $PHY 0 0x9140                 ;# reset + restart autoneg, reloads straps
for {set i 1} {$i <= 20} {incr i} {
    after 1000
    if {([mdio_read $PHY 1] & 0x24) == 0x24} { puts "   link+autoneg up at t+${i}s"; break }
}
mdio_write $PHY 31 0xa43 ; set physr [mdio_read $PHY 26] ; mdio_write $PHY 31 0
mdio_write $PHY 31 0xd08 ; set r11 [mdio_read $PHY 0x11] ; mdio_write $PHY 31 0
puts [format "== link %s at %s   reg0x11 0x%04X (strapped 0x0109)   host link %s Mb/s" \
      [expr {($physr & 4) ? {up} : {down}}] [lindex {10Mb 100Mb 1000Mb ?} [expr {($physr >> 4) & 3}]] \
      $r11 [string trim [exec cat /sys/class/net/$NIC/speed]]]

# The MAC counts frames as transmitted long before anything reaches the wire.
# Three pieces of state decide whether it actually does: the DMA burst/buffer
# configuration, a MAC address, and a receive ring the DMA will not fault on.
# Leaving receive_q_ptr at its reset value with RX enabled is enough to wedge
# the controller, in the same way queue 1 does.
mwr [expr {$GEM + 0x010}] 0x00180710      ;# dma_cfg: INCR16, 8K rx buf, tx full store-and-forward
mwr [expr {$GEM + 0x088}] 0xDD27000A      ;# laddr1 low  -> MAC 0a:00:27:dd:35:00
mwr [expr {$GEM + 0x08C}] 0x00000035      ;# laddr1 high
for {set i 0} {$i < 4} {incr i} {
    mwr [expr {0xFFFC0300 + $i*8}] [expr {0xFFFC0800 + $i*0x800 | ($i == 3 ? 0x2 : 0)}]
    mwr [expr {0xFFFC0300 + $i*8 + 4}] 0x00000000
}
mwr [expr {$GEM + 0x018}] 0xFFFC0300      ;# receive_q_ptr

# queue 1 descriptor pointers reset to 0 and wedge the DMA; park them on
# dummy used descriptors so only queue 0 is live.
mwr 0xFFFC0200 0x00000000 ; mwr 0xFFFC0204 0xC0000000
mwr 0xFFFC0210 0x00000003 ; mwr 0xFFFC0214 0x00000000
mwr [expr {$GEM + 0x440}] 0xFFFC0200
mwr [expr {$GEM + 0x480}] 0xFFFC0210

set frame {}
foreach b {0xFF 0xFF 0xFF 0xFF 0xFF 0xFF 0x00 0x0A 0x35 0x00 0x27 0xDD 0x88 0xB5} { lappend frame $b }
foreach c [split "ZU27DR LINUX BRINGUP ETHERNET OK" ""] { lappend frame [scan $c %c] }
while {[llength $frame] < 60} { lappend frame 0 }
set len [llength $frame]
for {set i 0} {$i < $len} {incr i 4} {
    set w 0
    for {set b 0} {$b < 4} {incr b} {
        set idx [expr {$i+$b}]
        set byte [expr {$idx < $len ? [lindex $frame $idx] : 0}]
        set w [expr {$w | ($byte << (8*$b))}]
    }
    mwr [expr {$BUF + $i}] $w
}
mask_write [expr {$GEM + 0x010}] 0x40000000 0x00000000   ;# clear TX status
mask_write [expr {$GEM + 0x004}] 0x00000403 0x00000402   ;# net_cfg: 1000, full duplex
mask_write [expr {$GEM + 0x000}] 0x0000001C 0x0000001C   ;# net_ctrl: MDIO, TX+RX enable

set g0 [host rx_packets] ; set c0 [host rx_crc_errors] ; set t0 [read32 [expr {$GEM + 0x108}]]
set NF 8
for {set i 0} {$i < $NF} {incr i} {
    mwr [expr {$BDR + $i*8}] $BUF
    mwr [expr {$BDR + $i*8 + 4}] [expr {0x00008000 | $len | ($i == $NF-1 ? 0x40000000 : 0)}]
}
mwr [expr {$GEM + 0x01C}] $BDR
mask_write [expr {$GEM + 0x000}] 0x00000200 0x00000200   ;# start transmission
after 600
set sent [expr {[read32 [expr {$GEM + 0x108}]] - $t0}]
set good [expr {[host rx_packets] - $g0}]
set crc  [expr {[host rx_crc_errors] - $c0}]
puts [format "== MAC transmitted %d   host received %d good, %d CRC errors" $sent $good $crc]
puts [expr {($sent == $NF && $good == $NF && $crc == 0) ? "== ETHERNET PASS" : "!! ETHERNET MISMATCH"}]
exit 0
