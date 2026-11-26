// Tb.sv -- single top for the DPI-C example.
//
// The testbench instantiates the DUT; IXCOM compiles Dut.sv to hardware and
// Xcelium compiles this file.  `+xcDesignTop+Tb.dut=Dut` links the instance
// `dut` inside Tb to the Dut module.
//
// All DPI imports here are compiled by Xcelium and execute on the simulator
// (plain Xcelium DPI; no IXCOM DPI options besides header generation).
// The one export is declared module-local, as required.

`timescale 1ns/1ps

module Tb;

  // ---- imports: executed on the simulator --------------------------------
  // Unidirectional: every argument is `input`; a function hands its result
  // back as the return value, never through an `output`/`inout` argument.
  // IXCOM allows output/inout arguments on tasks only -- a DPI function's
  // arguments must all be input ("Support for import Functions and Tasks",
  // Using IXCOM for SystemVerilog DPI, PLI, and VHPI Designs, 26.07).
  // This keeps every call one-way: SV -> C through the arguments, C -> SV
  // only through the return value.
  // Tasks can only be context; context functions are what the Cadence guide
  // uses in all of its examples.
  //
  // Declared inside the module on purpose: the scope of the import is the
  // "current scope" while C runs, and an exported routine is resolved only
  // in that scope (xmsim *E,NOTEXP).  With the import at $unit, fr_sw below
  // would have to be exported at $unit too.
  import "DPI-C" context function int to_sw  (input int data[800]);

  export "DPI-C" function fr_sw;
  function int fr_sw(input int to_display[800]);
	for (int i = 0; i < 800; i++)
    		$display("  From SW: %d: ", i, to_display[i]);
	return 0;
  endfunction

  //logic        clk   = 1'b0;
  wire        clk, clk2;

  // Only one base-clock module (IXCclkgen) is allowed in the whole design
  // (ILL_CLKGEN_INST).  clk is that base clock; clk2 is derived from it, as
  // the ixclkgen utility does for extra clocks: IXCcake1x #(FREQ, BFREQ,
  // DELAY) where FREQ/BFREQ is the output/base frequency ratio.
  // 67 MHz is the closest integer ratio to the original 71.4 MHz
  // (7 ns half period), which is not an integer multiple of 100 MHz.
  //always #5 clk = ~clk;                     // 100 MHz
  IXCclkgen #(5)           clk_i  (clk);            // 100 MHz base clock
  IXCcake1x #(67, 100, 0)  clk_i2 (clk2, clk);      // ~67 MHz, ~15 ns
  int array2sw[800];

  initial begin : main

    // ---- phase A: one DPI round trip per word --------------------------
    $display("Start the test");
    for (int i = 0; i < 800; i++) begin
      array2sw[i] = i;
      @(posedge clk);
    end
    to_sw(array2sw);
  end

  initial begin : second
    repeat (8) @(posedge clk2);
    for (int i = 0; i < 800; i++) begin
      array2sw[i] = i*5;
      @(posedge clk2);
    end
    to_sw(array2sw);
    $display("End the test");
    $finish;
  end
endmodule
