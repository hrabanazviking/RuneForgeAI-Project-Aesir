# Hailo-10H resource envelope

**Roadmap Slice 009 — complete: initial memory, power, and thermal baseline**

## Observed on the target host (2026-10-12)

- Host identifies as Raspberry Pi 5 Model B Rev 1.1, AArch64, with 16 GiB
  installed system memory (15 GiB reported by Linux).
- PCIe enumerates Hailo at `0001:01:00.0`; `hailortcli scan` detects it and
  `hailortcli fw-control identify` reports `HAILO10H`.
- HailoRT CLI and device firmware both report version 5.3.0.
- Pi thermal zone reported 44.65 °C at the baseline read; `vcgencmd get_throttled`
  returned `0x0` at that moment.
- The current single reading is an idle snapshot, not a sustained-load or
  ambient-adjusted thermal result. Hailo device temperature, board power,
  supply margin, and thermal behavior under inference remain unmeasured.

Raspberry Pi documents AI HAT+ 2 as providing 8 GB of dedicated onboard memory
for Hailo-10H workloads. Treat this as the board specification; actual
available memory for each model/context must be measured through the selected
runtime.

## Initial operating assumptions

- Limit the first acceptance profile to one loaded LLM and one active
  generation until device memory and scheduling behavior are measured.
- Do not admit a model/context combination that exceeds documented Hailo
  memory/runtime limits.
- Set thermal and power release thresholds only after collecting sustained
  target-device measurements with the official supported telemetry paths.
- The host's 16 GiB is for OS and ordinary app orchestration; it is not an
  alternate LLM memory pool or permission to run LLM inference on the CPU.

## Slice 009 acceptance

- Target host and accelerator identity are backed by live device output.
- Installed memory, Hailo software versions, and a dated thermal snapshot are
  recorded separately from board-spec values.
- Unmeasured Hailo power/thermal limits remain explicitly open.
- The resource policy keeps all LLM inference on Hailo-10H.

## Reference

- [Raspberry Pi AI HAT+ 2 specifications](https://www.raspberrypi.com/documentation/accessories/ai-hat-plus.html)
