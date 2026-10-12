# Hailo-10H module and memory capacity evidence

**Roadmap Slice 015 — complete with a hardware-identity limitation (2026-10-12)**

## Live identity versus product specification

- Live device identity is `HAILO10H` at PCI `0001:01:00.0` (PCI ID `1e60:45c4`). The live `hailortcli fw-control identify` output does not report carrier/HAT model, module part number, serial number, or onboard RAM capacity.
- Raspberry Pi's official AI HAT+ 2 documentation identifies the HAT+ 2 accelerator as Hailo-10H and specifies dedicated onboard memory of 8 GB. Raspberry Pi describes this as capacity intended for local generative AI workloads.
- Hailo's official Hailo-10H M.2 product brief lists module configurations with 4 GB or 8 GB LPDDR4/4X. The chip identity alone therefore does not establish which memory variant is physically installed.
- The current system has not been physically inspected to establish that the installed carrier is specifically Raspberry Pi AI HAT+ 2 or which module-memory SKU is present. For this machine, **Hailo-10H is verified; exact board and RAM SKU remain unverified**.

## Planning rule

Use 8 GB only as the AI HAT+ 2 product-spec reference, not as a live memory measurement or a claim about this particular card. Keep model fit, usable accelerator memory, and context capacity unverified until a permitted Hailo execution interface can report them. Do not infer that an LLM can run just because the product is marketed for GenAI.

## Sources

- [Raspberry Pi AI HATs documentation](https://www.raspberrypi.com/documentation/accessories/ai-hat-plus.html) — AI HAT+ 2 model table specifies Hailo-10H and 8 GB dedicated onboard memory.
- [Hailo-10H M.2 product brief](https://hailo.ai/hailo-files/hailo-10h-m-2-et-product-brief-en/) — lists 4/8 GB LPDDR4/4X configurations.
- Live identity snapshot: `docs/HAILO10H_HOST_DEVICE_IDENTITY.md`.

## Slice 015 acceptance

- Hailo silicon identity is supported by live device output.
- Vendor/product memory specifications are separate from the unknown installed SKU and usable-memory measurement.
- No unsupported claim about the physical HAT/module or model capacity is made.
- No CPU inference or hardware modification was performed.
