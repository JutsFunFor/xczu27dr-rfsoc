#!/usr/bin/env python3
"""Plot the RF loopback capture: DAC tone out an SMA, back into an ADC SMA."""
import numpy as np, collections
import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt
import os
LABDIR = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(LABDIR, "out")
os.makedirs(OUT, exist_ok=True)
import sys
# loopback.tcl performs the capture and writes it to out/capture.txt
CAPTURE = sys.argv[1] if len(sys.argv) > 1 else os.path.join(OUT, "capture.txt")
CAPTURE = os.path.abspath(CAPTURE)
print(f"capture: {CAPTURE}")

FS = 4.0e9
# 14-bit left-aligned in 16 bits: full scale is 0x7FFC, not 0x7FFF.
FULL_SCALE = 32764.0
SURFACE, INK, INK2, GRID = "#fcfcfb", "#0b0b0b", "#52514e", "#dcdcd8"
SERIES = {"ADC0  VIN01 SMA": "#2a78d6", "ADC2  VIN23 SMA": "#eb6834"}
LABEL = {"ADC0_VIN01": "ADC0  VIN01 SMA", "ADC2_VIN23": "ADC2  VIN23 SMA"}

raw = collections.defaultdict(list)
for line in open(CAPTURE):
    if line.startswith("#"): continue
    name, _, hexw = line.split()
    w = int(hexw, 16)
    raw[name] += [w & 0xFFFF, (w >> 16) & 0xFFFF]
chans = {LABEL[k]: np.array([v - 65536 if v & 0x8000 else v for v in vs], float)
         for k, vs in raw.items()}

fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(11, 8.2), facecolor=SURFACE,
                               gridspec_kw={"height_ratios": [1, 1.25], "hspace": 0.34})
for ax in (ax1, ax2):
    ax.set_facecolor(SURFACE)
    ax.grid(True, color=GRID, lw=0.8, zorder=0)
    ax.set_axisbelow(True)
    for s in ("top", "right"): ax.spines[s].set_visible(False)
    for s in ("left", "bottom"): ax.spines[s].set_color(GRID)
    ax.tick_params(colors=INK2, labelsize=9)

N = 120
t = np.arange(N) / FS * 1e9
for name, x in chans.items():
    ax1.plot(t, x[:N], lw=2, color=SERIES[name], label=name, solid_capstyle="round")
ax1.set_xlabel("time (ns)", color=INK2, fontsize=9)
ax1.set_ylabel("ADC code", color=INK2, fontsize=9)
ax1.set_title("Captured waveform — first 30 ns of a 4096-sample buffer",
              color=INK, fontsize=11, loc="left", pad=10)
ax1.legend(frameon=False, labelcolor=INK2, fontsize=9, loc="upper right", ncol=2)

for (name, x), dy in zip(chans.items(), (16, 7)):
    n = len(x); win = np.hanning(n)
    sp = np.abs(np.fft.rfft((x - x.mean()) * win)) * 2 / win.sum()
    f = np.fft.rfftfreq(n, 1 / FS) / 1e6
    db = 20 * np.log10(np.maximum(sp, 1e-6) / FULL_SCALE)
    ax2.plot(f, db, lw=1.2, color=SERIES[name], label=name)
    k = int(np.argmax(sp))
    ax2.annotate(f"{f[k]:.0f} MHz   {db[k]:.1f} dBFS", xy=(f[k], db[k]),
                 xytext=(f[k] + 120, db[k] + dy), color=INK, fontsize=9.5,
                 va="center", arrowprops=dict(arrowstyle="-", color=SERIES[name],
                 lw=1.2, connectionstyle="angle,angleA=0,angleB=90,rad=3"))
ax2.set_xlim(0, 2000); ax2.set_ylim(-115, 14)
ax2.set_xlabel("frequency (MHz)   —   first Nyquist zone at 4.0 GSPS", color=INK2, fontsize=9)
ax2.set_ylabel("dBFS", color=INK2, fontsize=9)
ax2.set_title("Spectrum — each ADC sees exactly the tone loaded into the DAC it is cabled to",
              color=INK, fontsize=11, loc="left", pad=10)
ax2.legend(frameon=False, labelcolor=INK2, fontsize=9, loc="upper right", ncol=2)

fig.suptitle("XCZU27DR RF loopback:  DAC tile 229 → SMA → ADC tile 224",
             color=INK, fontsize=13, x=0.125, ha="left", y=0.975)
fig.savefig(os.path.join(OUT, "rf_loopback.png"), dpi=140, facecolor=SURFACE, bbox_inches="tight")
print("wrote out/rf_loopback.png")
for name, x in chans.items():
    n = len(x); win = np.hanning(n)
    sp = np.abs(np.fft.rfft((x - x.mean()) * win)) * 2 / win.sum()
    f = np.fft.rfftfreq(n, 1 / FS) / 1e6
    k = int(np.argmax(sp))
    others = np.where(np.abs(np.arange(len(sp)) - k) > 5, sp, 0)
    print(f"{name}: peak {f[k]:.1f} MHz at {20*np.log10(sp[k]/FULL_SCALE):.1f} dBFS, "
          f"SFDR {20*np.log10(sp[k]/others.max()):.1f} dB, pk-pk {x.max()-x.min():.0f} codes")
