SIM ?= icarus
TOPLEVEL_LANG ?= verilog

TOPLEVEL = tt_um_snk_smart_io_hub
COCOTB_TEST_MODULES = test_tt_um

COCOTB_RESULTS_FILE = results.xml
COCOTB_HDL_TIMEUNIT = 1ns
COCOTB_HDL_TIMEPRECISION = 1ps

VERILOG_SOURCES = \
    $(PWD)/../src/uart_rx.v \
    $(PWD)/../src/pwm_bank.v \
    $(PWD)/../src/tt_um_snk_smart_io_hub.v

COMPILE_ARGS += -g2012

include $(shell cocotb-config --makefiles)/Makefile.sim
