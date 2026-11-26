#-----------------------------------------------------------------------------
# NCO_dpi -- DPI-C single-top Palladium SA-mode environment
#
# Adapted from /project/dv-cpu/josephdv/top1-DPI/example/Makefile.
#
#   hdl_top.sv  (single top, compiled by Xcelium at elaborate)
#     +- hw_if  (DPI exports/imports, host-side DPI)
#     +- clk_gen.v
#     +- memory dut  -> compiled by IXCOM as the hardware partition
#
#   src/cpp/mem_model.c : C reference model + scoreboard, linked as
#                         emu_64/libdpi_emu.so
#
# Source the VSI Cadence environment first:
#     source ~/settings_cadence_wxe_22102026.sh
#
# Targets:
#   make sac / sa_comp   vlan -> ixcom -> xrun -elaborate (DPI headers)
#   make sarun / sa_run  xeDebug --xmsim with emu_64/libdpi_emu.so
#   make libdpi_emu      build the C shared library only
#   make clean
#-----------------------------------------------------------------------------
SHELL            = /bin/sh
BITS            ?= 64
CURDIR           = ${PWD}
PLAT             = tools.lnx86
# Xcelium is built with the Cadence gcc; use it for the DPI library.
ifeq ($(GCCHOME),)
#CC               = gcc
CC               = g++
CC_ENV           =
else
# The Cadence gcc driver needs its own binutils libraries on the path
# (as: libopcodes-2.34.so); prepend them only for the compile.
#CC               = $(GCCHOME)/bin/gcc
CC               = $(GCCHOME)/bin/g++
CC_ENV           = LD_LIBRARY_PATH=$(GCCHOME)/lib64:$$LD_LIBRARY_PATH
endif
CFLAGS           = -g
EMU_DEBUGGER     = xeDebug
XECOM_VER        = $(shell xeCompile -v | awk -F'.' '{if(($$2>=5)||($$1>=19)) {print "1";} else {print "0";}}')
FOUND_XLM        = $(shell which xrun > /dev/null; if [ "$$?" -eq "0" ]; then echo 1; else echo 0;fi)
ifeq (1, $(XECOM_VER))
SIMULATOR        = xrun
SIM_LOGFILE      = xrun.log
EMU_SIM          = xmsim
IGNSIMCHK        = +ignoreSimVerCheck
else
SIMULATOR        = irun
SIM_LOGFILE      = irun.log
EMU_SIM          = ncsim
IGNSIMCHK        = +ignoreNCVerCheck
endif
SMLT             = $(SIMULATOR)
STOP_COMP        = -nccompile
SIMTOOL_HOME     = $(shell cds_root $(SMLT))
IXCOM_HOME       = $(shell cds_root ixcom)
VXE_HOME         = $(shell cds_root xeCompile)

ROOT=..
SIM="$(ROOT)/sim_hls"
RTL="$(ROOT)/wdir/hls/impl/verilog"

#HWFILES          = -f ../scripts/hw.list
HWFILES          = -f ../scripts/hw_hls.list
SWFILES          =
TBA_SIMFILES     =

#directories
DIR_EMU          = emu_$(BITS)
DIR_SIM          = sim_$(BITS)
DIR_SRC          = src/cpp
# memory is the hardware partition; hdl_top is the single software top
HWTOP            = TbHls
TBTOP            = TbHls
#TB_SIM_FILES     = ../src/v/$(TBTOP).sv
TB_SIM_FILES     = $(ROOT)/src/v/Tb_hls.sv $(RTL)/dut.v $(RTL)/dut_mul_11s_11s_22_1_1.v \
		   $(RTL)/dut_flow_control_loop_pipe_no_ap_cont.v
TARG_SIM         = $(DIR_SIM)/xrun.ok.log
TARG_VLAN        = $(DIR_EMU)/vlan.ok.log
TARG_IXCOM       = $(DIR_EMU)/ixcom.ok.log
TARG_COMPTB      = $(DIR_EMU)/ixcom_$(SMLT).ok.log
TARG_EMU         = $(DIR_EMU)/sac.ok.log
EMU_LOGFILE      = xc_work/xc_make.log
DPILIB           = libdpi.so
#DPILIB_SIM       = libdpi_sim.so
DPILIB_SIM       = libdpi_hls.so
DPILIB_EMU       = libdpi_emu.so
GUI              =

SIM_MACRO        =
NUM              =
DEBUG_SIM        =
DEBUG_SIM        = -linedebug
SIM_OPTS         = -c +incdir+../src/v -v ${IXCOM_HOME}/share/etc/ixcom/IXCclkgen.sv \
                   +access+rwc \
				   -sv \
                   +vtimescale+1ns/1ps \
				   $(DEBUG_SIM) \
                   $(SIM_MACRO)

#PT_OPTS          = +pt_import_async_task
PT_OPTS          =

VLAN_MACRO       =
#VLAN_MACRO       = +define+DEBUG_BFM
# memory.v has no `timescale; match the TB (1ns/1ps) so the DUT
# precision is not coarser than the TB precision (+xcDesignTop rule).
VLAN_OPTS        = -sv -incdir ../src/v -vtimescale 1ns/1ps -v ${IXCOM_HOME}/share/etc/ixcom/IXCclkgen.sv $(VLAN_MACRO)
#MCCONF           = +mc_gsfifo_config+./mc.conf
MCCONF           =
COMPILER_OPTIONS = -xecompile compilerOptions=../scripts/compilerOptions.qel -z3_Lsystem
IXCOM_OPTS       = -ua  $(IGNSIMCHK) +gfifoDisp $(MCCONF) ${COMPILER_OPTIONS}
COMPTB_OPTS      =

SIMRUN_OPTS      = +xcprof -sv_lib $(DPILIB_EMU) $(NUM)

#DEBUG_PROXY      = -DDEBUG_PROXY
DEBUG_PROXY      =
GDB              =
#CFILES           = $(DIR_SRC)/dpi_model.c
CFILES           = hls/dut.cpp src/cpp/dpi_hls_model.cpp
CINC             = -I. -I${IXCOM_HOME}/share/uxe/etc/ixcom -I${SIMTOOL_HOME}/${PLAT}/include
CDEF             = $(DEBUG_PROXY)

CTB_LIBS         = -I${IXCOM_HOME}/tools.lnx86/etc/ixcom \
                -I${IXCOM_HOME}/tools.lnx86/include \
                -I${SIMTOOL_HOME}/tools.lnx86/include  \
                -L${IXCOM_HOME}/tools.lnx86/lib/64bit \
                -L${VXE_HOME}/tools.lnx86/lib/64bit \

help:
	@echo "make sa_comp / sac   compile for acceleration"
	@echo "make sa_run  / sarun acceleration run (needs Palladium)"
	@echo "make simrun          pure Xcelium run (no Palladium)"
	@echo "make clean           remove emu_64/sim_64 and generated DPI headers"

plat:
	@echo "Make-> Platform : $(PLAT)"

################################# EMU ######################################
sarun sa_run emu_run uxe_run vxe_run xe_run: $(TARG_EMU) | $(DIR_EMU)/$(DPILIB_EMU)
	@cd $(DIR_EMU) && \
	$(EMU_DEBUGGER) $(GUI) --$(EMU_SIM) $(SIMRUN_OPTS) $(PT_OPTS) -- -init ../scripts/xe_init.tcl -input ../scripts/xe_run.tcl

sac sa_comp uxe vxe xe $(TARG_EMU): $(TARG_COMPTB) | $(DIR_EMU)
	@cp $(TARG_COMPTB) $(TARG_EMU)
	@echo "Make-> EMU database ready"

vlan $(TARG_VLAN): | $(DIR_EMU)
	@cd $(DIR_EMU) && \
	vlan -$(BITS) $(VLAN_OPTS) $(HWFILES) -l vlan.log && \
	mv vlan.log $(notdir $(TARG_VLAN))

ixcom $(TARG_IXCOM): $(TARG_VLAN)
	#ixcom -$(BITS) $(IXCOM_OPTS) $(STOP_COMP) -top $(HWTOP) +dut+$(HWTOP) +xcDesignTop+$(TBTOP).dut=$(HWTOP) -l ixcom.log &&
	@cd $(DIR_EMU) && \
	ixcom -$(BITS) $(IXCOM_OPTS) $(STOP_COMP) -top $(HWTOP) +dut+$(HWTOP) -l ixcom.log && \
	mv ixcom.log $(notdir $(TARG_IXCOM))

# Xcelium compiles the single top (hdl_top + hw_if + clk_gen) and emits the
# DPI headers.  memory comes from the IXCOM snapshot via xc_work/xrun.f.
comptb ixcom_$(SMLT) $(TARG_COMPTB): $(TARG_IXCOM)
	@cd $(DIR_EMU) && \
	$(SMLT) -elaborate -f xc_work/$(SMLT).f -vtimescale 1ns/1ps -dpiheader ../dpi_export.h -dpiimpheader ../dpi_import.h -dpi_void_task $(COMPTB_OPTS) $(SWFILES) -l ixcom_$(SMLT).log && \
	mv ixcom_$(SMLT).log $(notdir $(TARG_COMPTB))

################################# SIM ######################################
# Pure Xcelium run of the same single top -- no Palladium involved.  Useful
# to validate the DPI-C model/scoreboard when no emulator is attached.
simrun sim_run sim: $(TARG_SIM) | $(DIR_SIM)/$(DPILIB_SIM)
	@cd $(DIR_SIM) && \
	$(SMLT) -$(BITS) -R -sv_lib $(DPILIB_SIM) -l sim_run.log -input ../scripts/sim_run.tcl

simc sim_comp $(TARG_SIM): | $(DIR_SIM)
	@cd $(DIR_SIM) && \
	$(SMLT) -$(BITS) $(SIM_OPTS) -top $(TBTOP) $(TB_SIM_FILES) \
		-dpiheader ../dpi_export.h -dpiimpheader ../dpi_import.h -dpi_void_task \
		-l sim.log && \
	mv sim.log $(notdir $(TARG_SIM))

$(DIR_SIM)/$(DPILIB_SIM) libdpi_hls: $(CFILES) | $(DIR_SIM) $(TARG_SIM)
	$(CC_ENV) $(CC) -m$(BITS) -fPIC -g ${CINC} ${CDEF} -shared \
		-Ihls -I/system/EDA/Xilinx/2025.2/Vitis/include \
		-o $(DIR_SIM)/$(DPILIB_SIM) $(CFILES) -lm

################################# CTB ######################################

# The headers are produced by the elaborate step above, hence the order-only
# prerequisite on $(TARG_COMPTB).
$(DIR_EMU)/$(DPILIB_EMU) libdpi_emu: $(CFILES) | $(DIR_EMU) $(TARG_COMPTB)
	$(CC_ENV) $(CC) -m$(BITS) -fPIC -g ${CINC} -DIXCOM_COMPILE ${CDEF} -shared \
		-Ihls -I/system/EDA/Xilinx/2025.2/Vitis/include \
		-o $(DIR_EMU)/$(DPILIB_EMU) $(CFILES) -lm

################################# MISC #####################################
$(DIR_EMU) $(DIR_SIM):
	@mkdir $@

clean : distclean
	@echo "cleaning done"

cleanemu:
	-rm -rf $(DIR_EMU)

distclean:
	-rm -rf $(DIR_EMU) $(DIR_SIM)
	-rm -f dpi_export.h dpi_import.h *.log *.duna *.shm *.vcd
	-rm -rf xc_work WORK QTDB tmp

.PHONY: clean cleanemu distclean sac sarun simrun simc libdpi_emu libdpi_sim

check:
	@ if [ "$(SMLT)" == "xrun" ] && [ "$(FOUND_XLM)" -eq "0" ]; then \
	echo "XCELIUM is not found"; \
	fi

echo:
	@echo "FOUND_XLM    = $(FOUND_XLM)_"
	@echo "XECOM_VER    = $(XECOM_VER)_"
	@echo "SIMTOOL_HOME = $(SIMTOOL_HOME)_"
	@echo "CC           = $(CC)"
	@echo "CFILES       = $(CFILES)"
