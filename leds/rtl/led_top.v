//=============================================================================
// led_top.v  --  user LEDs and the J7 user header, driven over JTAG
//
// PL-only: no Zynq PS block, no DDR, no boot image, no SD card. Put the board
// in JTAG boot mode, program the bitstream and drive the pins from a Tcl
// console. Nothing on the PS side has to be alive.
//
// The clock is STARTUPE3's internal configuration oscillator (CFGMCLK). It is
// always there, needs no external source, and is specified only loosely
// (~50 MHz nominal, anywhere in 30-65 MHz). That is fine here -- nothing in
// this design cares about the exact rate.
//
//   led[0] = DT1 (A10)   led[1] = DT5 (D12)   led[2] = DT4 (H14)
//   j7_io4..j7_io9       = J7 header pins 4..9
//
// Both groups hang off one dual-channel AXI GPIO behind a JTAG-to-AXI master:
//
//   0x44A0_0000  channel 1 data  bits [2:0] = led[2:0]
//   0x44A0_0008  channel 2 data  bits [5:0] = j7_io9..j7_io4
//
// See led_test.tcl, which builds this, programs it and walks the pins.
//=============================================================================

`timescale 1ns / 1ps

module led_top (
  output wire [2:0] led,

  output wire       j7_io4,
  output wire       j7_io5,
  output wire       j7_io6,
  output wire       j7_io7,
  output wire       j7_io8,
  output wire       j7_io9
);

  //---------------------------------------------------------------------------
  // Free-running clock from the configuration oscillator.
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

  //---------------------------------------------------------------------------
  // Power-on reset: hold aresetn low for 128 clocks, then release for good.
  //---------------------------------------------------------------------------
  reg [7:0] rstcnt = 8'd0;
  always @(posedge clk) if (!rstcnt[7]) rstcnt <= rstcnt + 8'd1;
  wire aresetn = rstcnt[7];

  //---------------------------------------------------------------------------
  // JTAG-to-AXI master -> dual-channel AXI GPIO (see led_bd.tcl)
  //---------------------------------------------------------------------------
  wire [2:0] led_o;
  wire [5:0] j7_o;

  led_bd_wrapper bd_i (
    .aclk      (clk),
    .aresetn   (aresetn),
    .led_tri_o (led_o),
    .j7_tri_o  (j7_o)
  );

  assign led = led_o;

  assign j7_io4 = j7_o[0];
  assign j7_io5 = j7_o[1];
  assign j7_io6 = j7_o[2];
  assign j7_io7 = j7_o[3];
  assign j7_io8 = j7_o[4];
  assign j7_io9 = j7_o[5];

endmodule
