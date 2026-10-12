# Hailo-10H software baseline

**Roadmap Slice 009 — installed versions and compatibility status**

## Observed on the target host (2026-10-12)

| Layer | Observed value |
|---|---|
| OS | Debian GNU/Linux 12 (Bookworm) |
| Kernel | `6.12.112-v8-16k-hailo+` |
| HailoRT package | `5.3.0` |
| Hailo PCIe driver package | `5.3.0` |
| Hailo GenAI Model Zoo package | `5.3.0` |
| Device firmware | `5.3.0 (release, app)` |
| Device architecture | `HAILO10H` |
| `hailo-ollama` service | Active; local model endpoint returned an empty model list |

This establishes package/device presence only. It does not establish that a
model is installed, that the Bookworm combination is supported by the current
Raspberry Pi GenAI guide, or that AESIR can use the Hailo service.

## Compatibility status

Raspberry Pi's current AI software guide identifies 64-bit Raspberry Pi OS
Trixie as its prerequisite for the AI HAT+ 2 LLM instructions and documents a
Hailo GenAI Model Zoo package workflow. The target host is Bookworm, with Hailo
GenAI packages at 5.3.0. This discrepancy is an open compatibility check. Do
not upgrade, reinstall, or alter the host as part of this documentation slice.
Before implementation, verify the supported OS/runtime/driver/firmware/model
matrix against current Hailo and Raspberry Pi release material.

## Provisional model candidate

Qwen2-1.5B-Instruct is a provisional workload reference because Hailo lists a
compiled model and 2048-token context for its own GenAI path. That compiled
artifact is not approved for Æsir under the current no-HEF constraint. The
installed 5.3.0 packages and active Hailo-Ollama service are environment facts,
not approval to use that stack. No model is installed and no Hailo inference
has been run. A native source-model-to-Hailo execution path remains unproven.

## Slice 009 acceptance

- OS, kernel, Hailo runtime/driver/model-zoo, firmware, and device versions are
  recorded from the host.
- Empty model inventory is distinguished from a successful inference result.
- Bookworm versus documented Trixie support is tracked as an open compatibility
  question, not silently assumed safe or unsupported.
- No system packages, firmware, models, or configuration were changed.

## References

- [Raspberry Pi AI software guide](https://www.raspberrypi.com/documentation/computers/ai.html)
- [Hailo GenAI model catalog](https://github.com/hailo-ai/hailo_model_zoo_genai/blob/main/docs/MODELS.rst)
