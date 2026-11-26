#include <ap_fixed.h>
#include <cmath>
#include <iostream>
#define W 10
#define N (1 << W)
typedef ap_fixed<W+1,1,AP_RND,AP_SAT> data_t;
typedef ap_fixed<2*W+1,1,AP_RND,AP_SAT> out_t;
