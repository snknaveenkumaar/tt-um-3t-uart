import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles

CLK_DIV = 434


def set_ctrl(dut, bank=0, debug=0, seq=0, clear=0, cmd=1):
    """
    Matches the current RTL:
      ui_in[0] = UART RX
      ui_in[1] = cmd_enable
      ui_in[2] = seq_enable
      ui_in[3] = clear
      ui_in[5:4] = bank_sel
      ui_in[6] = debug_page
      ui_in[7] = unused
    """
    value = (
        ((debug & 1) << 6) |
        ((bank & 0x3) << 4) |
        ((clear & 1) << 3) |
        ((seq & 1) << 2) |
        ((cmd & 1) << 1) |
        1
    )
    dut.ui_in.value = value


async def uart_send_byte(dut, byte_val):
    current = int(dut.ui_in.value)
    dut.ui_in.value = current | 0x01
    await ClockCycles(dut.clk, 2)

    dut.ui_in.value = (int(dut.ui_in.value) & ~0x01) & 0xFF
    await ClockCycles(dut.clk, CLK_DIV)

    for i in range(8):
        if (byte_val >> i) & 1:
            dut.ui_in.value = int(dut.ui_in.value) | 0x01
        else:
            dut.ui_in.value = int(dut.ui_in.value) & ~0x01
        dut.ui_in.value &= 0xFF
        await ClockCycles(dut.clk, CLK_DIV)

    dut.ui_in.value = int(dut.ui_in.value) | 0x01
    dut.ui_in.value &= 0xFF
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
    await uart_send_byte(dut, 0x00)

    await uart_send_byte(dut, 0x81)
    await uart_send_byte(dut, 0xFF)

    await uart_send_byte(dut, 0x88)
    await uart_send_byte(dut, 0x00)

    await uart_send_byte(dut, 0x89)
    await uart_send_byte(dut, 0xFF)

    for _ in range(30):
        await ClockCycles(dut.clk, 1)

    out0 = int(dut.uo_out.value)
    assert (out0 & 0x01) == 0
    assert ((out0 >> 1) & 1) == 1

    out1 = int(dut.uio_out.value)
    assert (out1 & 0x01) == 0
    assert ((out1 >> 1) & 1) == 1

    set_ctrl(dut, bank=1, debug=0, seq=0, clear=0, cmd=1)
    for _ in range(30):
        await ClockCycles(dut.clk, 1)

    out_bank1 = int(dut.uo_out.value)
    assert (out_bank1 & 0x01) == 0
    assert ((out_bank1 >> 1) & 1) == 1

    set_ctrl(dut, bank=0, debug=1, seq=0, clear=0, cmd=1)
    for _ in range(10):
        await ClockCycles(dut.clk, 1)

    dbg = int(dut.uio_out.value)
    assert ((dbg >> 6) & 1) == 1
