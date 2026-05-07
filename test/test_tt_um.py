import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles

CLK_DIV = 434


def set_ctrl(dut, bank=0, debug=0, seq=0, clear=0, cmd=1):
    """
    ui_in mapping:

    bit0 : UART RX
    bit1 : cmd_enable
    bit2 : seq_enable
    bit3 : clear
    bit5:4 : bank_sel
    bit6 : debug_page
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

    dut.ui_in.value = int(dut.ui_in.value) | 0x01
    await ClockCycles(dut.clk, 2)

    # start bit
    dut.ui_in.value = int(dut.ui_in.value) & ~0x01
    dut.ui_in.value &= 0xFF

    await ClockCycles(dut.clk, CLK_DIV)

    # data bits
    for i in range(8):

        if (byte_val >> i) & 1:
            dut.ui_in.value = int(dut.ui_in.value) | 0x01
        else:
            dut.ui_in.value = int(dut.ui_in.value) & ~0x01

        dut.ui_in.value &= 0xFF

        await ClockCycles(dut.clk, CLK_DIV)

    # stop bit
    dut.ui_in.value = int(dut.ui_in.value) | 0x01
    dut.ui_in.value &= 0xFF

    await ClockCycles(dut.clk, CLK_DIV)


@cocotb.test()
async def test_pwm_banks_and_status(dut):

    cocotb.start_soon(
        Clock(dut.clk, 10, unit="ns").start()
    )

    dut.rst_n.value = 0
    dut.uio_in.value = 0

    set_ctrl(
        dut,
        bank=0,
        debug=0,
        seq=0,
        clear=0,
        cmd=1
    )

    await ClockCycles(dut.clk, 20)

    dut.rst_n.value = 1

    await ClockCycles(dut.clk, 20)

    #
    # configure prescaler
    #

    await uart_send_byte(dut, 0xC0)
    await uart_send_byte(dut, 0x00)

    #
    # PWM bank 0
    #

    await uart_send_byte(dut, 0x80)
    await uart_send_byte(dut, 0x00)

    await uart_send_byte(dut, 0x81)
    await uart_send_byte(dut, 0xFF)

    #
    # PWM bank 1
    #

    await uart_send_byte(dut, 0x88)
    await uart_send_byte(dut, 0x00)

    await uart_send_byte(dut, 0x89)
    await uart_send_byte(dut, 0xFF)

    await ClockCycles(dut.clk, 100)

    #
    # bank 0 on uo_out
    #

    out0 = int(dut.uo_out.value)

    assert (out0 & 0x01) == 0
    assert ((out0 >> 1) & 1) == 1

    #
    # next bank on uio_out
    #

    out1 = int(dut.uio_out.value)

    assert (out1 & 0x01) == 0
    assert ((out1 >> 1) & 1) == 1

    #
    # switch to bank 1
    #

    set_ctrl(
        dut,
        bank=1,
        debug=0,
        seq=0,
        clear=0,
        cmd=1
    )

    await ClockCycles(dut.clk, 100)

    out_bank1 = int(dut.uo_out.value)

    assert (out_bank1 & 0x01) == 0
    assert ((out_bank1 >> 1) & 1) == 1

    #
    # enable debug page
    #

    set_ctrl(
        dut,
        bank=0,
        debug=1,
        seq=0,
        clear=0,
        cmd=1
    )

    await ClockCycles(dut.clk, 100)

    dbg = int(dut.uio_out.value)

    #
    # debug mode should alter output muxing
    #

    assert dbg != out1
