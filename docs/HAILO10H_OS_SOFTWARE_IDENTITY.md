# Hailo campaign software and OS baseline

**Roadmap Slice 016 — complete (observed 2026-10-12)**

## Live system observations

- Distribution: Debian GNU/Linux 12 (Bookworm), AArch64.
- Kernel: `6.12.112-v8-16k-hailo+` (`#1 SMP PREEMPT`, build date 2026-10-10).
- Raspberry Pi firmware utility reports firmware date `2025/06/13`, version `5855b10b` release.
- Bootloader utility reports version `5855b10b2bd22b2a116dc91f6b5b1bc4b2ea849f` (release), timestamp `1749807566`.
- Hailo firmware: `5.3.0 (release,app)`; control protocol v2; device architecture `HAILO10H`.
- Hailo PCI driver: `hailo1x`; sysfs module version `5.3.0`.

These are live identity/version observations only. The specific Hailo GenAI package inventory from the software baseline is not repeated here; package presence does not approve those components for Æsir's runtime.

## Official platform guidance comparison

Raspberry Pi's current AI software documentation says its supported Pi 5 AI setup uses 64-bit Raspberry Pi OS Trixie. Its AI HAT+ 2 LLM route installs the Hailo GenAI Model Zoo and Hailo Ollama stack, while the AI HAT+ 2 base software prerequisites include Hailo driver/firmware and HailoRT. That documented vendor route conflicts with Æsir's current no-HEF/no-DFC/no-vendor-runtime architecture and is not being adopted.

The target currently runs Debian 12 Bookworm, not Raspberry Pi OS Trixie. This is a compatibility gap against current Raspberry Pi guidance for the supported vendor AI workflow. It does **not** establish that the project's independent native Mojo path is unsupported, and this slice makes no OS change recommendation until Mojo/Hailo feasibility and project policy are evaluated.

## Sources

- [Raspberry Pi AI software documentation](https://www.raspberrypi.com/documentation/computers/ai.html) — current OS prerequisites and separate Hailo-10H LLM setup path.
- Live read-only output collected on 2026-10-12; reproduction includes `cat /etc/os-release`, `uname -a`, `vcgencmd version`, `vcgencmd bootloader_version`, and `hailortcli fw-control identify`.

## Slice 016 acceptance

- Distribution, kernel, Pi firmware/bootloader, Hailo driver, firmware, and architecture are recorded.
- Observed versions are distinguished from the vendor-supported workflow.
- Bookworm versus current Trixie guidance is identified as a compatibility question, not silently changed.
- Vendor stack requirements are not treated as approval to alter Æsir's architecture.
