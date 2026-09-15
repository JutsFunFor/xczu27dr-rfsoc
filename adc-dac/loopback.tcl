# =============================================================================
# loopback.tcl - play two tones out of the DACs and capture both ADC channels
#
#   cd adc-dac
#   vivado -mode batch -source build.tcl        # once, builds the bitstream
#   python3 gen_waveform.py                     # writes out/waveform.tcl
#   vivado -mode batch -source loopback.tcl     # plays and captures
#   python3 analyze.py out/capture.txt          # FFT and report
#   python3 plot_capture.py out/capture.txt     # picture
#
# WIRING
#
#   An SMA cable from a DAC output to an ADC input. Only DAC12 (VOUT2) and
#   DAC13 (VOUT3) of tile 229 reach connectors on this board, and the ADC side
#   brings out VIN01 and VIN23 of tile 224.
#
#   Two different tones are played, so one cable identifies itself: whichever
#   tone turns up on whichever ADC channel tells you which pair you cabled.
#
# SAMPLE FORMAT - the thing that trips people up
#
#   ADC samples are 14-bit, LEFT-aligned in a 16-bit word. The bottom two bits
#   are always zero and full scale is 0x7FFC, not 0x1FFF. Read them as
#   right-aligned 14-bit and everything looks 12 dB too quiet.
#
# MEMORY MAP, confirmed by probing rather than from any document
#
#   dac_source window, 32 KB block stride:
#     +0x00000 cfg   +0x08000 DAC10  +0x10000 DAC11  +0x18000 DAC12  +0x20000 DAC13
#   cfg words: 0x00 id  0x04 start  0x08 enable  0x0C tile_enable
#              0x10 + 4n  num_samples[n]
#
#   adc_sink window, same 32 KB stride:
#     +0x00000 cfg   +0x08000 ADC0 (VIN01)   +0x10000 ADC2 (VIN23)
# =============================================================================
set LABDIR [file dirname [file normalize [info script]]]
file mkdir [file join $LABDIR out]
source [file join $LABDIR out waveform.tcl]

# Offsets move between IP versions, so prefer the map build.tcl wrote.
array set ADDR {}
set SRC   0xC0000000
set SINK  0xE0000000
if {[file exists [file join $LABDIR build addrmap.tcl]]} {
    source [file join $LABDIR build addrmap.tcl]
    foreach {k v} [array get ADDR] {
        if {[string match "*dac_source*" $k]} { set SRC  $v }
        if {[string match "*adc_sink*"   $k]} { set SINK $v }
    }
}
puts [format "== dac_source 0x%08X  adc_sink 0x%08X" $SRC $SINK]
set NCAP  4096
set NCAPW [expr {$NCAP/2}]

open_hw_manager
connect_hw_server -allow_non_jtag
foreach t [get_hw_targets] { if {[string match "*Xilinx*" $t]} { set tgt $t } }
open_hw_target $tgt
set dev [lindex [get_hw_devices xczu27dr*] 0]
current_hw_device $dev
refresh_hw_device -update_hw_probes false $dev
set axi [lindex [get_hw_axis -quiet] 0]

proc wr {axi addr data} {
    catch { delete_hw_axi_txn [get_hw_axi_txns -quiet w] }
    create_hw_axi_txn w [get_hw_axis $axi] -address [format %08X $addr] -len 1 \
        -type write -data [format %08X $data]
    run_hw_axi -quiet [get_hw_axi_txns w]
}
proc rd {axi addr} {
    catch { delete_hw_axi_txn [get_hw_axi_txns -quiet r] }
    create_hw_axi_txn r [get_hw_axis $axi] -address [format %08X $addr] -len 1 -type read
    run_hw_axi -quiet [get_hw_axi_txns r]
    return [string toupper [get_property DATA [get_hw_axi_txns r]]]
}
proc wrburst {axi addr words reversed} {
    set n [llength $words]
    if {$reversed} { set words [lreverse $words] }
    catch { delete_hw_axi_txn [get_hw_axi_txns -quiet wb] }
    create_hw_axi_txn wb [get_hw_axis $axi] -address [format %08X $addr] -len $n \
        -type write -data [join $words ""]
    run_hw_axi -quiet [get_hw_axi_txns wb]
}
proc rdburst {axi addr len} {
    catch { delete_hw_axi_txn [get_hw_axi_txns -quiet rb] }
    create_hw_axi_txn rb [get_hw_axis $axi] -address [format %08X $addr] -len $len -type read
    run_hw_axi -quiet [get_hw_axi_txns rb]
    set data [get_property DATA [get_hw_axi_txns rb]]
    set chars [string length $data]
    set out {}
    for {set w 0} {$w < $len} {incr w} {
        lappend out [string toupper [string range $data [expr {$chars-($w+1)*8}] [expr {$chars-$w*8-1}]]]
    }
    return $out
}

# --- which way round does a burst write lay its words down? -----------------
# num_samples[0..3] at +0x10..+0x1C are four adjacent writable registers, so
# they answer the question without touching anything that matters.
wrburst $axi [expr {$SRC+0x10}] {AAAA0001 BBBB0002 CCCC0003 DDDD0004} 0
set probe [list [rd $axi [expr {$SRC+0x10}]] [rd $axi [expr {$SRC+0x14}]] \
                [rd $axi [expr {$SRC+0x18}]] [rd $axi [expr {$SRC+0x1C}]]]
puts "== burst-write probe (as written, in order): $probe"
if {[lindex $probe 0] eq "AAAA0001"} {
    set REV 0
} elseif {[lindex $probe 0] eq "DDDD0004"} {
    set REV 1
} else {
    puts "!! burst write order not recognised: $probe"; exit 1
}
puts "== burst word order: [expr {$REV ? {reversed} : {in order}}]"

# --- load the two playback tables -------------------------------------------
foreach {ch base words nsamp freq} [list \
        2 [expr {$SRC+0x18000}] $DAC2_WORDS $DAC2_NSAMP $DAC2_FREQ_HZ \
        3 [expr {$SRC+0x20000}] $DAC3_WORDS $DAC3_NSAMP $DAC3_FREQ_HZ] {
    set n [llength $words]
    puts "== DAC$ch: writing $n words ([expr {$freq/1000000}] MHz tone) to [format 0x%08X $base]"
    for {set i 0} {$i < $n} {incr i 256} {
        set chunk [lrange $words $i [expr {$i+255}]]
        wrburst $axi [expr {$base + $i*4}] $chunk $REV
    }
    wr $axi [expr {$SRC + 0x10 + 4*$ch}] $nsamp
}
wr $axi [expr {$SRC+0x10}] 0
wr $axi [expr {$SRC+0x14}] 0
puts "== num_samples ch0..ch3: [rd $axi [expr {$SRC+0x10}]] [rd $axi [expr {$SRC+0x14}]] [rd $axi [expr {$SRC+0x18}]] [rd $axi [expr {$SRC+0x1C}]]"

# --- start the generators ----------------------------------------------------
wr $axi [expr {$SRC+0x08}] 0x0C          ;# enable DAC12 and DAC13
wr $axi [expr {$SRC+0x04}] 0x1           ;# start (self-clearing)
after 100
puts "== dac enable [rd $axi [expr {$SRC+0x08}]]  start/status [rd $axi [expr {$SRC+0x04}]]"

# --- capture both ADC channels ----------------------------------------------
wr $axi [expr {$SINK+0x08}] 0x3
wr $axi [expr {$SINK+0x10}] $NCAP
wr $axi [expr {$SINK+0x14}] $NCAP
wr $axi [expr {$SINK+0x04}] 0x1
after 300
puts "== adc working flag: [rd $axi [expr {$SINK+0x04}]] (0 = done)"

set fh [open [file join $LABDIR out capture.txt] w]
puts $fh "# rfsoc adc capture, 4.0 GSPS, decimation 1, $NCAP samples per channel"
puts $fh "# channel word_index hex32 (two 16-bit signed samples, even sample in low half)"
foreach {off name} [list 0x8000 ADC0_VIN01 0x10000 ADC2_VIN23] {
    set words {}
    for {set i 0} {$i < $NCAPW} {incr i 256} {
        set n [expr {min(256, $NCAPW-$i)}]
        set words [concat $words [rdburst $axi [expr {$SINK + $off + $i*4}] $n]]
    }
    puts "== $name: [llength $words] words captured, first 6: [lrange $words 0 5]"
    set i 0
    foreach w $words { puts $fh "$name $i $w"; incr i }
}
close $fh
puts "== wrote out/capture.txt"
exit 0
