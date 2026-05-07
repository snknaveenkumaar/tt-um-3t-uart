## How it works

This design is a UART-controlled smart I/O hub.

A UART receiver listens on `ui_in[0]` and accepts simple command bytes at 115200 baud using a standard 8N1 format. The design uses a small command decoder to update internal registers and drive several hardware blocks in parallel.

The project includes:
- a 16-channel PWM bank for steady or dimmable outputs
- an 8-channel timer bank for delays, pulse generation, and periodic events
- a small command interface that can update duty cycles, prescaler values, and timer registers

The PWM block compares each channel’s duty register against a shared counter. When the counter is below the duty value, the output is high. Otherwise it is low. This creates independent PWM outputs that can be used for LEDs, control signals, or simple timing outputs.

The timer block counts down configurable values and can generate timeout pulses. These can be used to trigger periodic changes or hardware events. The design also supports a simple sequencer mode so output patterns can be loaded and stepped through automatically.

The goal of the design is to provide a practical on-chip control hub that can be configured over UART while still being large enough to make good use of multiple Tiny Tapeout tiles.

---

## How to test

1. Connect a UART source to `ui_in[0]`
2. Set `ui_in[1] = 1` to enable command handling
3. Apply reset using `rst_n`
4. Send a command byte followed by data bytes

Example commands:
- `0x80` + duty byte → set PWM channel 0
- `0x81` + duty byte → set PWM channel 1
- `0x90` + prescaler byte → set the PWM prescaler
- `0xC0` + timer bytes → configure timer 0
- `0xD0` + control byte → control the sequencer

The PWM outputs appear on `uo_out[7:0]` and `uio_out[7:0]`.

**Expected output:** PWM waveforms whose duty cycles and timing behavior change according to the received UART commands.

---

## External hardware

- USB-to-UART adapter or microcontroller for sending commands
- Oscilloscope or logic analyzer for checking PWM outputs and timer pulses

No additional external hardware is required for basic operation.
