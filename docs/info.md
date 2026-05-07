## How it works

This design implements a UART-controlled smart I/O hub.

A UART receiver listens on `ui_in[0]` and receives command bytes using a standard 8N1 protocol. A small command decoder updates internal registers and drives several hardware blocks.

The design includes:

- A 32-channel PWM generator
- A lookup table (LUT) waveform generator
- A simple arithmetic logic unit (ALU)
- A command interface over UART

The PWM block compares a shared counter against 32 duty-cycle registers to generate independent PWM outputs.

A LUT generates periodic waveforms, which are automatically applied to some PWM channels. This enables dynamic signal generation without continuous UART input.

The ALU performs addition and multiplication operations. Its outputs are mapped to PWM channels, allowing dynamic waveform modulation.

This combination of parallel logic blocks increases utilization and demonstrates a practical configurable hardware controller.

---

## How to test

1. Connect UART RX to `ui_in[0]`
2. Set `ui_in[1] = 1` to enable command input
3. Apply reset using `rst_n`
4. Send command bytes over UART

Example:

- `0x80` + value → set PWM channel
- `0x90` + value → set prescaler
- `0xA0` + value → set ALU input A
- `0xB0` + value → set ALU input B

The PWM outputs can be observed on `uo_out` and `uio_out`.

Expected behavior:

Outputs produce PWM signals that vary based on UART commands, LUT patterns, and ALU results.

---

## External hardware

- USB-to-UART adapter or microcontroller
- Optional oscilloscope or logic analyzer

No additional hardware is required.
