#include "define.h"

extern void dut(data_t a[N], data_t b[N], out_t c[N]);
int main()
{
	data_t a[N], b[N];
	out_t c[N];
	for (int i=0; i<N; i++)
	{
		a[i] = (rand() % N + 1.0)/N;
		b[i] = (rand() % N + 1.0)/N;
	}
	dut(a,b,c);
	for (int i=0; i<N; i++)
	{
		std::cout << a[i] << " * " << b[i] << " = " << c[i] << std::endl;
	}
	return 0;
}
