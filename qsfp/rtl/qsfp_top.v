//=============================================================================
// qsfp_top.v  --  QSFP28 cage sidebands and module I2C, driven over JTAG
//
// PL-only: no Zynq PS block, no DDR, no boot image. Put the board in JTAG boot
// mode, program the bitstream, and talk to both cages from a Tcl console.
//
// The clock is STARTUPE3's CFGMCLK, the internal configuration oscillator.
// Nominally 50 MHz but specified only as 30-65 MHz, which is why the I2C
// controllers below end up somewhere between 70 and 130 kHz. QSFP modules are
// specified for 400 kHz, so that range is comfortably legal.
//
// EACH CAGE HAS SEVEN SIDEBAND PINS
//
//   ModSelL   out, active low   drive LOW to address this module over I2C
//   ResetL    out, active low   drive LOW to hold the module in reset
//   LPMode    out, active high   HIGH = low power mode
//   ModPrsL   in,  active low   LOW = a module is plugged in   (4k7 pull-up)
//   IntL      in,  active low   LOW = the module wants attention (4k7 pull-up)
//   SCL, SDA  bidirectional, open drain, 4k7 pull-ups to QSFP_VCCT
//
// The two cages have SEPARATE I2C buses, so there are two controllers.
//
// REGISTER MAP (behind a JTAG-to-AXI master)
//
//   0x44A0_0000  GPIO ch1, control, write only in practice
//                  bit 0  qsfp0 reset    1 = assert  (drives ResetL low)
//                  bit 1  qsfp0 modsel   1 = select  (drives ModSelL low)
//                  bit 2  qsfp0 lpmode   1 = low power
//                  bit 3  qsfp1 reset
//                  bit 4  qsfp1 modsel
//                  bit 5  qsfp1 lpmode
//   0x44A0_0008  GPIO ch2, status, read only -- RAW PIN LEVELS, active low
//                  bit 0  qsfp0 ModPrsL     bit 1  qsfp0 IntL
//                  bit 2  qsfp1 ModPrsL     bit 3  qsfp1 IntL
//   0x44A1_0000  AXI IIC for cage 0
//   0x44A2_0000  AXI IIC for cage 1
//
// The control bits are inverted here rather than in software so that the
// power-on state of the GPIO -- all zeros -- parks the cages safely:
// ResetL high, ModSelL high, LPMode low. Nothing is driven into a module
// before you ask for it.
//
// See qsfp_test.tcl, which builds this, programs it and exercises all of it.
//=============================================================================

`timescale 1ns / 1ps

module qsfp_top (
  // cage 0
  inout  wire qsfp0_scl,
  inout  wire qsfp0_sda,
  output wire qsfp0_modsel_l,
  output wire qsfp0_reset_l,
  output wire qsfp0_lpmode,
  input  wire qsfp0_modprs_l,
  input  wire qsfp0_int_l,

  // cage 1
  inout  wire qsfp1_scl,
  inout  wire qsfp1_sda,
  output wire qsfp1_modsel_l,
  output wire qsfp1_reset_l,
  output wire qsfp1_lpmode,
  input  wire qsfp1_modprs_l,
  input  wire qsfp1_int_l
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

  reg [7:0] rstcnt = 8'd0;
  always @(posedge clk) if (!rstcnt[7]) rstcnt <= rstcnt + 8'd1;
  wire aresetn = rstcnt[7];

  //---------------------------------------------------------------------------
  // Block design: JTAG-to-AXI -> smartconnect -> GPIO + two IIC controllers.
  // The IIC scl/sda inouts come straight out of the wrapper; Vivado puts the
  // open-drain IOBUFs in for us because they are declared as IIC interfaces.
  //---------------------------------------------------------------------------
  wire [5:0] ctl;
  wire [3:0] sts;

  qsfp_bd_wrapper bd_i (
    .aclk         (clk),
    .aresetn      (aresetn),
    .ctl_tri_o    (ctl),
    .sts_tri_i    (sts),
    .iic0_scl_io  (qsfp0_scl),
    .iic0_sda_io  (qsfp0_sda),
    .iic1_scl_io  (qsfp1_scl),
    .iic1_sda_io  (qsfp1_sda)
  );

  //---------------------------------------------------------------------------
  // Control: assert-high in software, active-low on the wire.
  //---------------------------------------------------------------------------
  assign qsfp0_reset_l  = ~ctl[0];
  assign qsfp0_modsel_l = ~ctl[1];
  assign qsfp0_lpmode   =  ctl[2];
  assign qsfp1_reset_l  = ~ctl[3];
  assign qsfp1_modsel_l = ~ctl[4];
  assign qsfp1_lpmode   =  ctl[5];

  //---------------------------------------------------------------------------
  // Status: raw pin levels, two flip-flops deep because these come off a
  // connector and are asynchronous to everything.
  //---------------------------------------------------------------------------
  reg [3:0] sync0 = 4'b1111;
  reg [3:0] sync1 = 4'b1111;
  always @(posedge clk) begin
    sync0 <= {qsfp1_int_l, qsfp1_modprs_l, qsfp0_int_l, qsfp0_modprs_l};
    sync1 <= sync0;
  end
  assign sts = sync1;

endmodule
