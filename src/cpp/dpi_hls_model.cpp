/* dpi_hls_model.cpp -- DPI-C stimulus generator and scoreboard for the
 * Vitis HLS ap_fixed DUT.
 *
 * The SV testbench (src/v/Tb_hls.sv) imports:
 *
 *   tb_gen_stim(output int a[1024], output int b[1024])
 *   tb_check   (input  int a[1024], input  int b[1024], input int c_hw[1024])
 *
 * DPI-C has no fixed-point data type, so the boundary carries raw
 * two's-complement words:
 *
 *   ap_fixed<11,1>  -> bits [10:0]  of an int (a and b)
 *   ap_fixed<21,1>  -> bits [20:0]  of an int (c)
 *
 * Vitis HLS 2025.2 C simulation has no public set_raw(); the raw bits live in
 * the ap_private member V of the ap_fixed object, so the conversions below
 * assign/read V directly.  get_VAL() is sign-extended, hence the masks.
 *
 * Build together with the HLS model:
 *   $(GCCHOME)/bin/g++ -m64 -fPIC -shared \
 *       -I$(XLMHOME)/tools.lnx86/include \
 *       -I/system/EDA/Xilinx/2025.2/Vitis/include -I../hls \
 *       -o libdpi_hls.so ../hls/dut.cpp dpi_hls_model.cpp
 */

#include "define.h"                 /* W, N, data_t, out_t */

#include <cstdint>
#include <cstdio>
#include <cstdlib>

/* The HLS C model, compiled from hls/dut.cpp into the same shared library. */
extern void dut(data_t a[N], data_t b[N], out_t c[N]);

/* ---- raw-bit helpers --------------------------------------------------- */

static inline unsigned raw_bits(const data_t& x)
{
    return (unsigned)((unsigned long long)x.V.get_VAL()
                      & ((1ULL << (W + 1)) - 1));
}

static inline int sign_extend(unsigned v, int bits)
{
    const long long m   = 1LL << (bits - 1);
    const long long val = (long long)(v & ((1u << bits) - 1));
    return (int)((val & m) ? val - (1LL << bits) : val);
}

static inline data_t from_bits(int v)
{
    data_t x;
    x.V = ap_private<W + 1, true>((unsigned long long)(uint32_t)v);
    return x;
}

/* ---- imported routines ------------------------------------------------- */

/* Imported tasks compile to C functions returning int unless the tool is told
 * they are void.  The project Makefile already passes -dpi_void_task, so keep
 * the signature in sync with the generated dpi_import.h prototype. */
extern "C" void tb_gen_stim(int* a, int* b)
{
    /* Same algorithm and rand() sequence as hls/tb.cpp. */
    for (int i = 0; i < N; ++i) {
        data_t va = (std::rand() % N + 1.0) / N;
        data_t vb = (std::rand() % N + 1.0) / N;
        a[i] = (int)raw_bits(va);
        b[i] = (int)raw_bits(vb);
    }
}

extern "C" int tb_check(int* a, int* b, int* c_hw)
{
    static data_t aa[N];
    static data_t bb[N];
    static out_t  cc[N];

    for (int i = 0; i < N; ++i) {
        aa[i] = from_bits(a[i]);
        bb[i] = from_bits(b[i]);
    }

    dut(aa, bb, cc);                    /* reference: the HLS C model */

    int errs = 0;
    for (int i = 0; i < N; ++i) {
        const int exp = sign_extend((unsigned)cc[i].V.get_VAL(), 2 * W + 1);
        const int got = sign_extend((unsigned)(uint32_t)c_hw[i], 2 * W + 1);
        if (exp != got) {
            ++errs;
            if (errs <= 10)
                std::printf("MISMATCH[%d]: a=%d b=%d exp=%d got=%d\n",
                            i, a[i], b[i], exp, got);
        }
    }

    std::printf("tb_check: %d/%d mismatches\n", errs, N);

    /* A short sample, similar to the printout in hls/tb.cpp. */
    for (int i = 0; i < 5 && i < N; ++i)
        std::printf("  ref: %.10f * %.10f = %.10f  (raw %d)\n",
                    (double)aa[i], (double)bb[i], (double)cc[i],
                    sign_extend((unsigned)cc[i].V.get_VAL(), 2 * W + 1));

    return errs;
}
