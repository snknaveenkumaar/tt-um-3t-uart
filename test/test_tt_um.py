import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles


CLK_DIV = 434


def set_ctrl(dut, bank=0, debug=0, seq=0, clear=0, cmd=1):
    value = (
        (debug & 1) << 7
        | (bank & 0x7) << 4
        | (clear & 1) << 3
        | (seq & 1) << 2
        | (cmd & 1) << 1
        | 1
    )
    dut.ui_in.value = value


async def uart_send_byte(dut, byte_val):
    dut.ui_in.value = int(dut.ui_in.value) | 0x01  # keep RX idle high
    await ClockCycles(dut.clk, 2)

    dut.ui_in.value = int(dut.ui_in.value) & ~0x01  # start bit
    await ClockCycles(dut.clk, CLK_DIV)

    for i in range(8):
        if (byte_val >> i) & 1:
            dut.ui_in.value = int(dut.ui_in.value) | 0x01
        else:
            dut.ui_in.value = int(dut.ui_in.value) & ~0x01
        await ClockCycles(dut.clk, CLK_DIV)

    dut.ui_in.value = int(dut.ui_in.value) | 0x01  # stop bit
    await ClockCycles(dut.clk, CLK_DIV)


@cocotb.test()
async def test_pwm_banks_and_status(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())

    dut.rst_n.value = 0
    dut.uio_in.value = 0
    set_ctrl(dut, bank=0, debug=0, seq=0, clear=0, cmd=1)

    for _ in range(10):
        await ClockCycles(dut.clk, 1)

    dut.rst_n.value = 1
    for _ in range(10):
        await ClockCycles(dut.clk, 1)

    await uart_send_byte(dut, 0xC0)
    await uart_send_byte(dut, 0x00)

    await uart_send_byte(dut, 0x80)
    await uart_send_byte(dut, 0x00)  # PWM0 = 0

    await uart_send_byte(dut, 0x81)
    await uart_send_byte(dut, 0xFF)  # PWM1 = 255

    await uart_send_byte(dut, 0x88)
    await uart_send_byte(dut, 0x00)  # PWM8 = 0

    await uart_send_byte(dut, 0x89)
    await uart_send_byte(dut, 0xFF)  # PWM9 = 255

    for _ in range(30):
        await ClockCycles(dut.clk, 1)

    # bank 0 appears on uo_out
    out0 = int(dut.uo_out.value)
    assert (out0 & 0x01) == 0
    assert ((out0 >> 1) & 1) == 1

    # next bank appears on uio_out
    out1 = int(dut.uio_out.value)
    assert (out1 & 0x01) == 0
    assert ((out1 >> 1) & 1) == 1

    # switch bank selector to 1; channel 8/9 should now be on uo_out
    set_ctrl(dut, bank=1, debug=0, seq=0, clear=0, cmd=1)
    for _ in range(30):
        await ClockCycles(dut.clk, 1)

    out_bank1 = int(dut.uo_out.value)
    assert (out_bank1 & 0x01) == 0
    assert ((out_bank1 >> 1) & 1) == 1

    # debug page should show status on uio_out, bit 6 is debug_page = 1
    set_ctrl(dut, bank=0, debug=1, seq=0, clear=0, cmd=1)
    for _ in range(10):
        await ClockCycles(dut.clk, 1)

    dbg = int(dut.uio_out.value)
    assert ((dbg >> 6) & 1) == 1
