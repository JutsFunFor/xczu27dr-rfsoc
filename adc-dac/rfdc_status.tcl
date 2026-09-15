# =============================================================================
# rfdc_status.tcl - program the RF Data Converter example design and read back
# the state of every ADC and DAC tile.
#
#   cd adc-dac
#   vivado -mode batch -source build.tcl        # once, builds the bitstream
#   vivado -mode batch -source rfdc_status.tcl
#
# Board in JTAG boot mode, JTAG cable connected, board powered.
#
# No MicroBlaze software, no RF Analyzer GUI, no Windows. The example design
# carries a JTAG-to-AXI master that reaches the whole AXI map, so the Vivado
# hardware manager can read the converter status registers directly.
#
# WHAT THE RESULT MEANS
#
#   Each tile reports a restart-state machine value and a status word. State 15
#   with POWERED_UP and PLL_LOCKED set is a tile that is running. A tile that
#   stalls below state 15 has not got its reference clock -- which on this
#   board means the RC21008B was never programmed, because that is the FSBL's
#   job and not the PL's. See ../clocking/.
#
# Tiles 225, 226, 227 and DAC 228 report powered but unlocked, and that is
# correct: this design only enables ADC tile 224 and DAC tile 229, the two the
# board brings out to SMA connectors.
# =============================================================================
set LABDIR [file dirname [file normalize [info script]]]
set BUILD  [file join $LABDIR build]
set BIT    [file join $BUILD rfdc_example.bit]
file mkdir [file join $LABDIR out]

if {![file exists $BIT]} {
    puts "== ERROR: $BIT does not exist."
    puts "== Build it first:   vivado -mode batch -source build.tcl"
    exit 1
}

# Slave offsets in the example design move between IP versions, so build.tcl
# writes out the map it actually generated. These defaults are what the 2021.2
# example design uses and what this BSP was brought up against.
array set ADDR {}
set RFDC 0x44B00000
set SRC  0xC0000000
set SINK 0xE0000000
if {[file exists [file join $BUILD addrmap.tcl]]} {
    source [file join $BUILD addrmap.tcl]
    foreach {k v} [array get ADDR] {
        if {[string match "*rf_data_converter*" $k]} { set RFDC $v }
        if {[string match "*dac_source*"        $k]} { set SRC  $v }
        if {[string match "*adc_sink*"          $k]} { set SINK $v }
    }
}
puts [format "== rfdc 0x%08X  dac_source 0x%08X  adc_sink 0x%08X" $RFDC $SRC $SINK]

proc hx {v} { return [format 0x%08X $v] }

# --- connect ------------------------------------------------------------
open_hw_manager
connect_hw_server -allow_non_jtag
set tgts [get_hw_targets]
puts "== targets: $tgts"
set tgt ""
foreach t $tgts { if {[string match "*Xilinx*" $t]} { set tgt $t } }
if {$tgt eq ""} { puts "!! no Xilinx Platform Cable target found"; exit 1 }
open_hw_target $tgt
puts "== opened $tgt"

set dev [lindex [get_hw_devices xczu27dr*] 0]
if {$dev eq ""} { puts "!! no xczu27dr in the chain: [get_hw_devices]"; exit 1 }
current_hw_device $dev
refresh_hw_device -update_hw_probes false $dev
puts "== device: $dev"

# --- program ------------------------------------------------------------
puts "== programming [file tail $BIT] (about 34 MB, expect roughly 75 s)"
set t0 [clock seconds]
set_property PROGRAM.FILE $BIT $dev
program_hw_devices $dev
puts "== load took [expr {[clock seconds]-$t0}] s"

# program_hw_devices returns before the debug-hub BSCAN slaves have settled;
# refreshing too soon gives "not a valid CseXsdb Slave core". Retry.
proc settle_refresh {dev {tries 6}} {
    for {set i 1} {$i <= $tries} {incr i} {
        after 3000
        if {![catch {refresh_hw_device $dev} err]} {
            puts "== refresh ok on attempt $i"
            return 1
        }
        puts "== refresh attempt $i failed, retrying"
        catch {disconnect_hw_server}
        catch {connect_hw_server -allow_non_jtag}
        catch {open_hw_target [current_hw_target]}
        catch {current_hw_device $dev}
    }
    return 0
}
if {![settle_refresh $dev]} { puts "!! debug hub never came up"; exit 1 }

# Vivado 2025.2 dropped REGISTER.CONFIG_STATUS.* on this device; the
# "End of startup status: HIGH" line from program_hw_devices is the
# authoritative DONE indication, and the debug cores enumerating below
# confirms the fabric is live.
puts "== DONE check skipped (property absent in 2025.2)"

# --- what debug cores turned up -----------------------------------------
puts "== hw_axi cores : [get_hw_axis -quiet]"
puts "== ila cores    : [get_hw_ilas -quiet]"

set axi [lindex [get_hw_axis -quiet] 0]
if {$axi eq ""} { puts "!! no JTAG-to-AXI master detected — cannot talk to the RFDC"; exit 1 }

proc rd {axi addr} {
    set a [format %08X $addr]
    catch { delete_hw_axi_txn [get_hw_axi_txns -quiet rd_$a] }
    create_hw_axi_txn rd_$a [get_hw_axis $axi] -address $a -len 1 -type read
    if {[catch { run_hw_axi [get_hw_axi_txns rd_$a] } e]} { return "ERR:$e" }
    return 0x[get_property DATA [get_hw_axi_txns rd_$a]]
}

# --- RFDC common block ---------------------------------------------------
puts "\n== RFDC common (base [hx $RFDC])"
foreach {off name} {0x0000 IP_version 0x0004 master_reset 0x0008 common_0x08
                    0x000C common_0x0C 0x0080 clock_detect 0x0100 common_intr_sts} {
    puts [format "   +%-8s %-16s %s" $off $name [rd $axi [expr {$RFDC + $off}]]]
}

# --- per-tile control/status --------------------------------------------
# DAC tile N ctrl/stats = 0x4000 + N*0x4000 ; ADC tile N = 0x14000 + N*0x4000
# within a tile: 0x04 restart  0x08 restart_state  0x0C current_state
#                0x80 clock_detect  0x228 status (b2 PWR_UP, b3 PLL_LOCKED)
proc tile_report {axi base label} {
    set st  [rd $axi [expr {$base + 0x228}]]
    set cs  [rd $axi [expr {$base + 0x00C}]]
    set rs  [rd $axi [expr {$base + 0x008}]]
    set cd  [rd $axi [expr {$base + 0x080}]]
    set flags ""
    if {[string match "0x*" $st]} {
        set s [expr {$st}]
        append flags [expr {($s & 0x1) ? "supplies_up " : ""}]
        append flags [expr {($s & 0x4) ? "POWERED_UP " : ""}]
        append flags [expr {($s & 0x8) ? "PLL_LOCKED " : ""}]
    }
    set state "?"
    if {[string match "0x*" $cs]} { set state [expr {$cs & 0xF}] }
    puts [format "   %-10s status %s  state %-2s  restart_state %s  clkdet %s   %s" \
          $label $st $state $rs $cd $flags]
}

puts "\n== ADC tiles (tile 0 is the one this design enables: 4.0 GSPS, 200 MHz ref, PLL on)"
for {set t 0} {$t < 4} {incr t} {
    tile_report $axi [expr {$RFDC + 0x14000 + $t*0x4000}] "ADC$t"
}
puts "\n== DAC tiles (tile 1 is the one this design enables: 4.0 GSPS, 200 MHz ref, PLL on)"
for {set t 0} {$t < 4} {incr t} {
    tile_report $axi [expr {$RFDC + 0x4000 + $t*0x4000}] "DAC$t"
}

# --- do the exdes data generator / capture blocks answer? ----------------
puts "\n== example-design blocks"
puts "   dac_source 0xC0000000 : [rd $axi 0xC0000000]  +4 [rd $axi 0xC0000004]  +8 [rd $axi 0xC0000008]"
puts "   adc_sink   0xE0000000 : [rd $axi 0xE0000000]  +4 [rd $axi 0xE0000004]  +8 [rd $axi 0xE0000008]"
puts "   clk_wiz_dac0 0x44C10000 +0x04 [rd $axi 0x44C10004]"
puts "   clk_wiz_adc0 0x44C40000 +0x04 [rd $axi 0x44C40004]"

puts "\n== done"
close_hw_manager
exit 0
