#!/usr/bin/env python3
"""Generate the DAC playback tables for the RFDC example design.

Two different tones so a single loopback cable identifies itself: whichever
tone shows up on whichever ADC channel tells us which SMA pair is cabled.

DAC tile 1 (229) runs at 4.0 GSPS, interpolation 1x, 16 samples per AXI-Stream
beat, so num_samples must be a multiple of 16. Samples are 16-bit signed,
full scale 0x7FFF (the example design's own sine LUT uses the full range).
"""
import numpy as np, sys
import os
LABDIR = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(LABDIR, "out")
os.makedirs(OUT, exist_ok=True)

FS       = 4.0e9      # DAC sample rate
NSAMP    = 1024       # samples in the playback loop, multiple of 16
AMPL     = 0.5        # fraction of full scale, leaves ADC headroom
CHANNELS = {2: 32, 3: 96}   # dac channel -> cycles in the buffer

lines = []
for ch, cycles in CHANNELS.items():
    n = np.arange(NSAMP)
    s = np.round(AMPL * 32767 * np.sin(2*np.pi*cycles*n/NSAMP)).astype(np.int32)
    u = (s.astype(np.int64) & 0xFFFF).astype(np.uint64)
    # two 16-bit samples per 32-bit AXI word, even sample in the low half
    words = (u[1::2] << 16) | u[0::2]
    lines.append(f"set DAC{ch}_NSAMP {NSAMP}")
    lines.append(f"set DAC{ch}_FREQ_HZ {int(FS*cycles/NSAMP)}")
    lines.append("set DAC%d_WORDS {%s}" % (ch, " ".join(f"{w:08X}" for w in words)))
    print(f"ch{ch}: {cycles} cycles in {NSAMP} samples -> {FS*cycles/NSAMP/1e6:.1f} MHz, "
          f"{len(words)} AXI words, peak {int(AMPL*32767)}", file=sys.stderr)

open(os.path.join(OUT, "waveform.tcl"), "w").write("\n".join(lines) + "\n")
