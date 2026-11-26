#include "define.h"

void dut(data_t a[N], data_t b[N], out_t c[N])
{
#pragma HLS INTERFACE ap_fifo port=a,b,c
#pragma HLS INTERFACE ap_ctrl_none port=return
#pragma HLS PIPELINE

	for (int i=0; i<N; i++)
#pragma HLS UNROLL off
		c[i] = a[i] * b[i];
}
