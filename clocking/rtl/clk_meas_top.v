//=============================================================================
// clk_meas_top.v  --  measure the four GTY reference clocks
//
// PL-only: no Zynq PS block, no DDR, no boot image. Program it over JTAG and
// read four frequency counters from a Tcl console.
//
// WHY THIS EXISTS
//
// Both GTY quads take their reference from the on-board Renesas RC21008B
// VersaClock7, which is I2C programmable. The refclk frequency is therefore a
// configuration choice, not a board constant, and nothing on the board tells
// you what it currently is. This design counts it.
//
// HOW IT MEASURES
//
//   Each refclk pair -> IBUFDS_GTE4 -> ODIV2 (refclk / 2) -> BUFG_GT -> fabric.
//   A gate window 2^21 cycles long is generated from STARTUPE3's CFGMCLK. In
//   each refclk domain a counter runs for the duration of the gate and latches
//   its total when the gate falls.
//
//     f_refclk = 2 * count * f_cfgmclk / 2^21
//
//   CFGMCLK is an internal oscillator specified only as 30-65 MHz, so the
//   ABSOLUTE numbers carry that error. The RATIOS between the four channels do
//   not -- they share the same gate, so they are exact. clock_check.tcl uses
//   that: you tell it what one refclk is supposed to be, it back-solves
//   CFGMCLK from that channel, and every other channel then reads out
//   accurately.
//
//   A channel whose count stays at zero has no clock arriving at all.
//
// REGISTER MAP (behind a JTAG-to-AXI master)
//
//   0x44A0_0000  quad 128 refclk0 count    (pins M28 / M29)
//   0x44A0_0008  quad 128 refclk1 count    (pins K28 / K29)
//   0x44A1_0000  quad 129 refclk0 count    (pins H28 / H29)
//   0x44A1_0008  quad 129 refclk1 count    (pins F28 / F29)
//
// Quad 128 feeds the QSFP cage this BSP calls qsfp0, quad 129 feeds qsfp1.
//=============================================================================

`timescale 1ns / 1ps

module clk_meas_top (
  input wire [1:0] gty_refclk0p_i,
  input wire [1:0] gty_refclk0n_i,
  input wire [1:0] gty_refclk1p_i,
  input wire [1:0] gty_refclk1n_i
);

  // Gate is 2^GATE_BITS CFGMCLK cycles long. At a nominal 50 MHz that is 42 ms,
  // and a 156.25 MHz refclk accumulates about 3.3 million counts.
  //
  // Each readback word is  {7-bit capture sequence, 25-bit count}. 25 bits caps
  // the measurable reference at roughly 1.5 GHz, which is far above anything
  // this board's synthesiser will produce, and leaves room for the sequence
  // number -- see the comment on `seq` below for why that matters.
  localparam integer GATE_BITS = 21;

  //---------------------------------------------------------------------------
  // Timebase: the configuration oscillator.
  //---------------------------------------------------------------------------
  wire clk;

  STARTUPE3 #(
    .PROG_USR      ("FALSE"),
    .SIM_CCLK_FREQ (0.0)
  ) startup_i (
    .CFGCLK    (),
    .CFGMCLK   (clk),
    .DI        (),
    .EOS       (),
    .PREQ      (),
    .DO        (4'b0000),
    .DTS       (4'b1111),
    .FCSBO     (1'b1),
    .FCSBTS    (1'b1),
    .GSR       (1'b0),
    .GTS       (1'b0),
    .KEYCLEARB (1'b1),
    .PACK      (1'b0),
    .USRCCLKO  (1'b0),
    .USRCCLKTS (1'b1),
    .USRDONEO  (1'b1),
    .USRDONETS (1'b1)
  );

  reg [7:0] rstcnt = 8'd0;
  always @(posedge clk) if (!rstcnt[7]) rstcnt <= rstcnt + 8'd1;
  wire aresetn = rstcnt[7];

  // Square wave: high for 2^GATE_BITS clocks, then low for the same.
  reg [GATE_BITS:0] win = 0;
  always @(posedge clk) win <= win + 1'b1;
  wire gate = win[GATE_BITS];

  reg gate_d = 1'b0;
  always @(posedge clk) gate_d <= gate;
  wire gate_rise = gate & ~gate_d;

  //---------------------------------------------------------------------------
  // Reference clock buffers. REFCLK_HROW_CK_SEL = 2'b01 makes ODIV2 = O / 2,
  // which halves what the fabric has to keep up with. The maths upstairs puts
  // the factor of two back.
  //---------------------------------------------------------------------------
  wire [3:0] refclk;

  genvar q;
  generate
    for (q = 0; q < 2; q = q + 1) begin : QUAD
      wire o0, odiv2_0, o1, odiv2_1;

      IBUFDS_GTE4 #(
        .REFCLK_EN_TX_PATH  (1'b0),
        .REFCLK_HROW_CK_SEL (2'b01),
        .REFCLK_ICNTL_RX    (2'b00)
      ) ibuf0 (
        .I     (gty_refclk0p_i[q]),
        .IB    (gty_refclk0n_i[q]),
        .CEB   (1'b0),
        .O     (o0),
        .ODIV2 (odiv2_0)
      );

      IBUFDS_GTE4 #(
        .REFCLK_EN_TX_PATH  (1'b0),
        .REFCLK_HROW_CK_SEL (2'b01),
        .REFCLK_ICNTL_RX    (2'b00)
      ) ibuf1 (
        .I     (gty_refclk1p_i[q]),
        .IB    (gty_refclk1n_i[q]),
        .CEB   (1'b0),
        .O     (o1),
        .ODIV2 (odiv2_1)
      );

      BUFG_GT bufg0 (
        .I (odiv2_0), .CE (1'b1), .CEMASK (1'b0),
        .CLR (1'b0),  .CLRMASK (1'b0), .DIV (3'd0),
        .O (refclk[2*q + 0])
      );

      BUFG_GT bufg1 (
        .I (odiv2_1), .CE (1'b1), .CEMASK (1'b0),
        .CLR (1'b0),  .CLRMASK (1'b0), .DIV (3'd0),
        .O (refclk[2*q + 1])
      );
    end
  endgenerate

  //---------------------------------------------------------------------------
  // One counter per reference clock.
  //
  // `gate` is synchronised into each refclk domain with two flip-flops. The
  // total is latched into `hold` on the falling edge of the synchronised gate,
  // and sampled back into the CFGMCLK domain on the NEXT rising edge -- a
  // whole gate period later, when `hold` has been static for millions of
  // cycles. No handshake needed and no chance of catching a half-written value.
  //---------------------------------------------------------------------------
  // Flattened rather than a wire array -- one 32-bit slice per channel.
  wire [127:0] hold;

  genvar c;
  generate
    for (c = 0; c < 4; c = c + 1) begin : CH
      reg        g_meta = 1'b0, g_sync = 1'b0, g_prev = 1'b0;
      reg [31:0] cnt = 32'd0;
      reg [31:0] latched = 32'd0;

      always @(posedge refclk[c]) begin
        g_meta <= gate;
        g_sync <= g_meta;
        g_prev <= g_sync;

        if (g_sync & ~g_prev)      cnt <= 32'd1;        // gate opened
        else if (g_sync)           cnt <= cnt + 32'd1;  // counting

        if (~g_sync & g_prev)      latched <= cnt;      // gate closed
      end

      assign hold[32*c +: 32] = latched;
    end
  endgenerate

  // All four counts are captured on the same edge, but the host reads them one
  // AXI transaction at a time and those are milliseconds apart over JTAG. With
  // a new capture every gate period, a set of four reads can straddle a capture
  // boundary and mix two different measurement windows -- which shows up as a
  // frequency ratio error of a tenth of a percent that moves every run.
  //
  // So every word carries the sequence number of the capture it came from. The
  // host checks all four match and re-reads if they do not, which makes the
  // ratios exact instead of merely close.
  reg [6:0]  seq = 7'd0;
  reg [31:0] cap0 = 0, cap1 = 0, cap2 = 0, cap3 = 0;
  always @(posedge clk) begin
    if (gate_rise) begin
      seq  <= seq + 7'd1;
      cap0 <= {seq + 7'd1, hold[  0 +: 25]};
      cap1 <= {seq + 7'd1, hold[ 32 +: 25]};
      cap2 <= {seq + 7'd1, hold[ 64 +: 25]};
      cap3 <= {seq + 7'd1, hold[ 96 +: 25]};
    end
  end

  //---------------------------------------------------------------------------
  // JTAG-to-AXI master -> two dual-channel AXI GPIOs, all inputs.
  //---------------------------------------------------------------------------
  clk_meas_bd_wrapper bd_i (
    .aclk     (clk),
    .aresetn  (aresetn),
    .cnt0_tri_i (cap0),
    .cnt1_tri_i (cap1),
    .cnt2_tri_i (cap2),
    .cnt3_tri_i (cap3)
  );

endmodule
