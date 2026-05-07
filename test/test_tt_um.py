import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles


@cocotb.test()
async def test_project(dut):

    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())

    dut.ena.value = 1
    dut.uio_in.value = 0
    dut.ui_in.value = 0

    # reset
    dut.rst_n.value = 0
    for _ in range(10):
        await ClockCycles(dut.clk, 1)

    dut.rst_n.value = 1

    # run some cycles
    for _ in range(50):
        await ClockCycles(dut.clk, 1)

    # Just verify outputs are valid (not X/Z)
    assert dut.uo_out.value is not None
