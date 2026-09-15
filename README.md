# XCZU27DR RFSoC — Board Support Package

![The XCZU27DR RFSoC board](board.jpg)

*The board as everything here was tested on it: SMA coax looping the DAC
outputs back into the ADC inputs, both QSFP28 cages in the middle, gigabit
Ethernet and the USB-C console down the left side, and a rather serious fan
over the RFSoC itself.*

This is the documentation for a **Xilinx Zynq UltraScale+ RFSoC XCZU27DR**
board (`xczu27dr-fsve1156-1-i`, revision v1.1). It's a genuinely capable piece
of hardware that arrives with a schematic and not much else. No manual, no pin
list, no worked examples. If you own one, you've probably already found that
out the hard way.

So this repository is the manual. It was written by bringing the board up one
interface at a time and writing down what actually happened.

**The important part: every folder has a script you can just run.** Not a
fragment to adapt to your setup — a Tcl script that builds whatever it needs,
programs the board over JTAG, exercises the interface, and tells you whether it
worked. Next to each script there's a page explaining the pins, the registers,
and the things that'll cost you an afternoon if nobody warns you first.

Everything here was derived from the schematic and from the hardware itself.
The pin map was read off the schematic and checked against a routed build. The
processor configuration is written out from board parameters in plain Tcl. The
RF and transceiver designs are generated from AMD's IP. All you need is the
board, a JTAG cable, and Vivado.

---

## What's on the board

```mermaid
flowchart LR
  subgraph PS["Processing System — quad A53 + dual R5"]
    DDR["DDR4<br/>4 GB"]
    GEM["GEM3 → RTL8211FD<br/>Gigabit Ethernet"]
    SD["SD1 → microSD"]
    UART["UART0 → CH340E<br/>USB-C console"]
  end
  subgraph PL["Programmable Logic"]
    RF["RF converters<br/>8 ADC in / 8 DAC out"]
    GTY["8 GTY lanes"]
    IO["LEDs, J7 header,<br/>QSFP sidebands"]
  end
  CLK["RC21008B<br/>clock synthesiser"] -->|200 MHz| RF
  CLK -->|156.25 MHz| GTY
  GTY --> Q["2 × QSFP28 cages"]
  IO --> Q
  JTAG["JTAG<br/>Platform Cable USB II"] --> PS
  JTAG --> PL
```

| | |
|---|---|
| Device | XCZU27DR-FSVE1156-1-I, RFSoC Gen 1 |
| RF ADC | 4 dual tiles — ADC224/225/226/227, 8 inputs |
| RF DAC | 2 quad tiles — DAC228/229, 8 outputs |
| Memory | 4 GB DDR4, 4 × MT40A512M16JY, DDR4-2400P |
| Ethernet | GEM3 → RTL8211FD, RGMII, PHY at MDIO address 7 |
| Transceivers | 8 GTY lanes, 2 quads → 2 × QSFP28 |
| Reference clock | RC21008B, I²C programmable |
| Console | UART0 on MIO42/43 → CH340E on USB-C **JT9**, 115200 8N1 |
| Boot | SD1, `BOOT.BIN` from the first FAT partition |

---

## The folders

| Folder | Interface | Run this | Status |
|---|---|---|---|
| [`jtag/`](jtag/) | JTAG chain, DAP, register access | `xsdb jtag_check.tcl` | ✅ working |
| [`leds/`](leds/) | 3 user LEDs and the J7 header | `vivado -mode batch -source led_test.tcl` | ✅ working |
| [`ddr4/`](ddr4/) | PS DDR4, calibration and memory test | `xsdb ddr4_test.tcl` | ✅ working |
| [`ethernet/`](ethernet/) | Gigabit Ethernet, GEM3 + RTL8211FD | `xsdb eth_verify.tcl` | ✅ working |
| [`clocking/`](clocking/) | RC21008B and the GTY reference clocks | `vivado -mode batch -source clock_check.tcl` | ✅ working |
| [`qsfp/`](qsfp/) | QSFP28 cages, module I²C, GTY lanes | `vivado -mode batch -source qsfp_test.tcl` | ✅ working |
| [`adc-dac/`](adc-dac/) | RF converters, tone out and capture back | `vivado -mode batch -source loopback.tcl` | ✅ working |

There's also **[`ZU27DR_v1.1.xdc`](ZU27DR_v1.1.xdc)** at the top level, which is
the full board constraint file. It covers every programmable-logic pin the
board actually connects: 136 I/O across banks 65, 66, 88 and 89, the eight GTY
reference clock balls, and the GTY quad placement. Every line carries the
schematic net name, the Xilinx pin name and the destination connector in a
comment, so you can check any of it against the schematic without hunting.

A ✅ means that interface was brought up on this board, using the script in
that folder, and the numbers it produced are on that folder's page.

You'll notice there's no "untested" row, and that's deliberate. USB,
DisplayPort, SD-FEC, the I²C power tree and the SD card boot flow are all real
parts of this board, and none of them has been exercised here yet. Rather than
write pages guessing at them from the schematic, they're simply absent. They
get folders when they've been made to work, not before.

### What was actually measured

| | |
|---|---|
| JTAG | full chain, DAP read/write across OCM, boot mode reads `0x5` = SD1 |
| LEDs A10 / D12 / H14 | lit in sequence, confirmed as silkscreen **DT1 / DT5 / DT4** |
| Banks 88 / 89 rail | **3.3 V**, traced on the schematic and confirmed on silicon |
| DDR4 | **12 of 12** PHY training stages, `PGSR0 0x80004FFF`, patterns hold, no aliasing |
| Ethernet | 1000 Mb full duplex, PHY@7, 8 frames sent, **8 received good, 0 CRC errors** |
| GTY reference clocks | **156.2500 MHz** on refclk0 of both quads, identical counts |
| QSFP cages | both `ModPrsL` and `IntL` correct, all 6 control outputs, **both I²C buses read their module** |
| QSFP GTY lanes | **all 8 links at 10.3125 Gbps, PRBS-31, zero bit errors** |
| RF loopback | 125.00 MHz at −21.2 dBFS, SFDR **53.0 dB**; 375.00 MHz at −21.2 dBFS, SFDR **61.1 dB** |

Every one of those numbers came from a design this repository builds itself.

---

## Getting started

Here's what you need:

- **Vivado and Vitis 2025.2**, with `vivado`, `xsdb` and `xsct` on your `PATH`.
  2021.2 works too.
- **A JTAG cable.** These pages assume a Xilinx Platform Cable USB II, which is
  what the board was brought up with.
- **The board in JTAG boot mode.** Almost everything here either runs purely in
  the programmable logic or drives the processor directly over the debug port,
  so you need no SD card, no boot image and no serial console to follow along.

Begin with [`jtag/`](jtag/). If that doesn't pass then nothing else will, and
it's written to tell you why rather than just failing.

```bash
cd jtag && xsdb jtag_check.tcl
```

After that, take the folders in whatever order interests you. Each one stands
alone, with its own RTL, its own constraints and its own build. The first run
of a folder that needs a bitstream takes a few minutes; after that it reuses
what it built.

One thing worth knowing up front: if you're heading for the transceivers or the
RF converters, read [`clocking/`](clocking/) first. There's a programmable
clock chip on this board that has to be set up before either of those will do
anything at all, and the failure mode looks alarmingly like dead silicon.

## A word on the family resemblance

This board isn't a ZCU111 and it isn't a ZCU208. It's close enough to both that
their documentation is genuinely useful, and different enough that following it
blindly will cost you time.

The differences that bite are things like the Ethernet PHY address, which
converter tiles actually reach connectors, and which SD controller is wired up.
Wherever one of those matters, the relevant page says so explicitly instead of
leaving you to find out.
