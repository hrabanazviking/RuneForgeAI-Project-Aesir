# Hailo-10H host and accelerator identity

**Roadmap Slice 014 — complete (observed 2026-10-12 14:52 UTC)**

## Live read-only observations

- Host model: Raspberry Pi 5 Model B Rev 1.1.
- CPU architecture: AArch64; 4 Cortex-A76 cores. Host CPU is outside this campaign's LLM inference target.
- Linux kernel: `6.12.112-v8-16k-hailo+`.
- Host memory: 15 GiB visible to Linux; `free -h` reported 11 GiB available at observation time. `lsmem` could not access `/sys/devices/system/memory` in this environment, so its failure is retained rather than inferred around.
- Hailo PCI function: BDF `0001:01:00.0`, vendor/device ID `1e60:45c4`, class `0b40` (coprocessor).
- Bound kernel driver: `hailo1x` (module version reports 5.3.0).
- `hailortcli fw-control identify`: device architecture `HAILO10H`, firmware `5.3.0 (release,app)`, control protocol v2.
- Negotiated PCIe link: 8.0 GT/s ×1. Endpoint-reported maximum: 8.0 GT/s ×4.
- Pi thermal zone: 42.2 °C at sample time; `vcgencmd get_throttled` returned `0x0`.

## Limits

These commands identify the host and accelerator and report current link/firmware state. They do not prove model loading, command completion through Æsir, Hailo LLM execution, device memory availability, or performance. Exact carrier/HAT identity, Hailo module part/serial number, and module memory capacity were not reported by the live identity command and remain separate inventory items.

No driver binding, device reset, firmware, or system configuration was changed. No inference workload was run.

## Reproduction commands

`uname -a`; `cat /proc/device-tree/model`; `lspci -nnk -s 0001:01:00.0`; `hailortcli fw-control identify`; read `current_link_speed`, `current_link_width`, `max_link_speed`, and `max_link_width` under `/sys/bus/pci/devices/0001:01:00.0/`; `free -h`; `vcgencmd measure_temp`; `vcgencmd get_throttled`.

## Slice 014 acceptance

- Pi and Hailo identities and current link/driver/firmware readings are recorded from live read-only output.
- Point-in-time health readings are clearly distinguished from sustained-load evidence.
- No claim of Hailo inference is made.
- No CPU LLM inference or device mutation occurred.
