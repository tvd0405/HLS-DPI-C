#!/bin/bash
# run_hls_sim.sh -- pure-Xcelium smoke test of Tb_hls.sv against the
# Vitis-HLS-generated RTL, with the HLS C model linked as the DPI reference.
#
# Source the Cadence environment first:
#   source ~/settings_cadence_wxe_22102026.sh
#
# Usage: scripts/run_hls_sim.sh

set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
SIM="$ROOT/sim_hls"
RTL="$ROOT/wdir/hls/impl/verilog"

: "${XLMHOME:?source the Cadence environment first (XLMHOME is unset)}"

CXX=${GCCHOME:+$GCCHOME/bin/g++}
CXX=${CXX:-g++}
IXCOM_HOME=$(cds_root ixcom)

rm -rf "$SIM"
mkdir -p "$SIM"

echo "==> building DPI-C reference model"
LD_LIBRARY_PATH=${GCCHOME:+$GCCHOME/lib64:}${LD_LIBRARY_PATH:-} \
"$CXX" -m64 -fPIC -g -shared \
    -I"$XLMHOME/tools.lnx86/include" \
    -I/system/EDA/Xilinx/2025.2/Vitis/include \
    -I"$ROOT/hls" \
    -o "$SIM/libdpi_hls.so" \
    "$ROOT/hls/dut.cpp" \
    "$ROOT/src/cpp/dpi_hls_model.cpp"

echo "==> compiling + running Xcelium"
cd "$SIM"
xrun -64 -sv -vtimescale 1ns/1ps -top TbHls \
    -v "$IXCOM_HOME/share/etc/ixcom/IXCclkgen.sv" \
    -dpiheader dpi_export.h -dpiimpheader dpi_import.h -dpi_void_task \
    "$ROOT/src/v/Tb_hls.sv" \
    "$RTL/dut.v" \
    "$RTL/dut_mul_11s_11s_22_1_1.v" \
    "$RTL/dut_flow_control_loop_pipe_no_ap_cont.v" \
    -sv_lib "$SIM/libdpi_hls.so" \
    -l xrun.log

echo "==> done (log: $SIM/xrun.log)"
