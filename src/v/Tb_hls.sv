// Tb_hls.sv -- SystemVerilog testbench for the Vitis HLS ap_fixed DUT.
//
// Mirrors hls/tb.cpp:
//   * stimulus is generated on the C side (same rand() algorithm as tb.cpp)
//   * the HLS C model computes the reference result
//   * the generated RTL (wdir/hls/impl/verilog/dut.v) is the DUT
//   * tb_check() compares the raw 21-bit fixed-point words
//
// DPI-C has no fixed-point type.  ap_fixed<11,1> and ap_fixed<21,1> cross the
// boundary as one int per element holding the raw two's-complement bits
// (width <= 32).  See src/cpp/dpi_hls_model.cpp.
//
// The HLS DUT was generated with:
//   #pragma HLS INTERFACE ap_fifo port=a,b,c
//   #pragma HLS INTERFACE ap_ctrl_none port=return
// so it is a free-running stream: read a[i]/b[i] when a_read/b_read, write
// c[i] when c_write.  c_din is combinational, valid in the c_write cycle.

`timescale 1ns/1ps

module TbHls;

  localparam int N = 1 << 10;          // 1024, matches define.h

  // ---- DPI imports ------------------------------------------------------
  // A task may have output/inout arguments; a DPI function may not (IXCOM
  // restriction).  Both are context routines.
  import "DPI-C" context task tb_gen_stim(output int a[N], output int b[N]);

  import "DPI-C" context function int tb_check(input int a[N],
                                               input int b[N],
                                               input int c_hw[N]);

  // ---- stimulus / result storage ---------------------------------------
  int a_data[N];
  int b_data[N];
  int c_hw[N];

  // ---- clock / reset ----------------------------------------------------
  wire clk;
  IXCclkgen #(5) clk_i (clk);          // 10 ns period, 100 MHz
  logic rst = 1'b1;

  // ---- ap_fifo-side glue ------------------------------------------------
  // Present one element per cycle; no backpressure on c.
  int rd_idx = 0;
  int wr_idx = 0;

  wire [10:0] a_dout    = (rd_idx < N) ? a_data[rd_idx][10:0] : 11'd0;
  wire [10:0] b_dout    = (rd_idx < N) ? b_data[rd_idx][10:0] : 11'd0;
  wire        a_empty_n = (rd_idx < N);
  wire        b_empty_n = (rd_idx < N);
  wire        c_full_n  = 1'b1;

  wire        a_read, b_read, c_write;
  wire [20:0] c_din;

  dut u_dut (
    .ap_clk   (clk),
    .ap_rst   (rst),
    .a_dout   (a_dout),    .a_empty_n(a_empty_n), .a_read(a_read),
    .b_dout   (b_dout),    .b_empty_n(b_empty_n), .b_read(b_read),
    .c_din    (c_din),     .c_full_n (c_full_n),  .c_write(c_write)
  );

  always @(posedge clk) begin
    if (!rst) begin
      if (a_read) rd_idx <= rd_idx + 1;     // a_read and b_read are in lockstep
      if (c_write && wr_idx < N) begin
        c_hw[wr_idx] <= $signed(c_din);     // sign-extend the 21-bit raw word
        wr_idx       <= wr_idx + 1;
      end
    end
  end

  // ---- test -------------------------------------------------------------
  int n_err;

  initial begin : main
    tb_gen_stim(a_data, b_data);

    repeat (5) @(posedge clk);
    rst <= 1'b0;

    wait (wr_idx == N);
    @(posedge clk);

    n_err = tb_check(a_data, b_data, c_hw);

    if (n_err == 0)
      $display("TEST PASSED (%0d vectors)", N);
    else
      $display("TEST FAILED: %0d mismatches", n_err);

    $finish;
  end

  // ---- watchdog ---------------------------------------------------------
  initial begin
    #1ms;
    $display("TEST FAILED: timeout (rd_idx=%0d wr_idx=%0d)", rd_idx, wr_idx);
    $finish;
  end

endmodule
