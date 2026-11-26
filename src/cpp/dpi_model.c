/* dpi_model.c -- C reference model and scoreboard for the single-top
 * DPI-C example.
 *
 * Build with the Cadence gcc so the ABI matches Xcelium:
 *   $GCCHOME/bin/gcc -fPIC -shared -I$XLMHOME/tools.lnx86/include -I. \
 *                    -o lib/libdpi.so dpi_model.c
 *
 * svdpi.h comes from $XLMHOME/tools.lnx86/include (symlink into inca/include).
 */

#include <stdio.h>

#include "dpi_import.h"   /* -dpiimpheader: prototypes of the import routines
                             this file implements                        */
#include "dpi_export.h"   /* -dpiheader: prototype of tb_report, which is
                             called from this file                        */
int to_sw(int data[800])
{
    printf("Got data from HW\n");
    fr_sw(data);
    for (int i = 0; i < 800; i++)
	    printf("Data %d: %d\n", i, data[i]);
    return 0;
}
