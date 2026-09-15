#!/usr/bin/env python3
"""FFT the captured ADC buffers and report what is actually on each input."""
import numpy as np, sys, collections
import os
LABDIR = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(LABDIR, "out")
os.makedirs(OUT, exist_ok=True)
import sys
# dac_tone.tcl performs the capture and writes it into lab 40
CAPTURE = sys.argv[1] if len(sys.argv) > 1 else os.path.join(OUT, "capture.txt")
CAPTURE = os.path.abspath(CAPTURE)
print(f"capture: {CAPTURE}")

FS = 4.0e9
chans = collections.defaultdict(list)
for line in open(CAPTURE):
    if line.startswith("#"): continue
    name, idx, hexw = line.split()
    w = int(hexw, 16)
    chans[name].append(w & 0xFFFF)          # even sample
    chans[name].append((w >> 16) & 0xFFFF)  # odd sample

def s16(v): return v - 65536 if v & 0x8000 else v

for name, raw in chans.items():
    x = np.array([s16(v) for v in raw], dtype=float)
    n = len(x)
    lsb_mask = np.bitwise_or.reduce([v for v in raw])
    dc  = x.mean()
    ac  = x - dc
    rms = ac.std()
    win = np.hanning(n)
    sp  = np.abs(np.fft.rfft(ac * win))
    freqs = np.fft.rfftfreq(n, 1/FS)
    sp[0] = 0
    k = int(np.argmax(sp))
    peak_db = 20*np.log10(sp/ (sp[k] + 1e-30) + 1e-30)
    # next strongest bin at least 5 bins away
    mask = np.abs(np.arange(len(sp)) - k) > 5
    k2 = int(np.argmax(np.where(mask, sp, 0)))
    print(f"{name}: {n} samples")
    print(f"   sample range   {x.min():.0f} .. {x.max():.0f}   DC {dc:.1f}   AC rms {rms:.1f} LSB")
    print(f"   OR of all words 0x{lsb_mask:04X}  -> {'bits [1:0] always zero' if not lsb_mask & 3 else 'all bits used'}")
    print(f"   peak       {freqs[k]/1e6:8.2f} MHz   (bin {k}, amplitude {2*sp[k]/win.sum():.0f} LSB)")
    print(f"   next peak  {freqs[k2]/1e6:8.2f} MHz   {peak_db[k2]:.1f} dBc")
    print(f"   full scale {32767}, so peak is {20*np.log10((2*sp[k]/win.sum())/32767+1e-30):.1f} dBFS")
