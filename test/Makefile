SIM ?= icarus
TOPLEVEL_LANG ?= verilog

TOPLEVEL = tt_um_snk_smart_io_hub
MODULE   = test_tt_um

VERILOG_SOURCES = $(PWD)/../src/uart_rx.v \
                  $(PWD)/../src/pwm_bank.v \
                  $(PWD)/../src/timer_bank.v \
                  $(PWD)/../src/tt_um_snk_smart_io_hub.v

include $(shell cocotb-config --makefiles)/Makefile.sim
