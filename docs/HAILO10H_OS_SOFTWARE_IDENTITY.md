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

Raspberry Pi's current AI software documentation describes a Trixie-based vendor workflow. Æsir's direct in-process HailoRT GenAI route is separately verified on this host's Bookworm installation; do not treat Hailo-Ollama as Æsir's target or upgrade the OS absent a concrete incompatibility.

The target currently runs Debian 12 Bookworm and completed a direct HailoRT GenAI generation with the installed 5.3.0 stack and matching model artifact. Preserve this exact host profile in compatibility evidence.

## Sources

- [Raspberry Pi AI software documentation](https://www.raspberrypi.com/documentation/computers/ai.html) — current OS prerequisites and separate Hailo-10H LLM setup path.
- Live read-only output collected on 2026-10-12; reproduction includes `cat /etc/os-release`, `uname -a`, `vcgencmd version`, `vcgencmd bootloader_version`, and `hailortcli fw-control identify`.

## Slice 016 acceptance

- Distribution, kernel, Pi firmware/bootloader, Hailo driver, firmware, and architecture are recorded.
- Observed versions are distinguished from the vendor-supported workflow.
- Bookworm versus current Trixie guidance is identified as a compatibility question, not silently changed.
- Vendor stack requirements are not treated as approval to alter Æsir's architecture.
