# Æsir direct Hailo-10H backend recovery

**Status:** active implementation path, 2026-10-12.

## Owner requirements

- Project Æsir LLM inference executes on the Hailo-10H.
- Pi CPU LLM inference, fallback, shadow execution, and serving are prohibited.
- Hailo-Ollama is not the target. Do not use an inference proxy/service in its place.
- Keep working through failures by repairing the direct Hailo path or choosing another supported Hailo runtime/model combination.

## Correction to earlier campaign documents

Earlier campaign documents imposed pure-Mojo, no-HEF, no-DFC, and no-HailoRT constraints. Those restrictions were added by the roadmap author; they were not the owner's stated target. They forced the plan onto an undocumented raw-mailbox path whose historical probe did not complete. Retire those constraints for this mission. This correction changes the implementation route while preserving the target: Æsir calls HailoRT GenAI directly in-process, and HailoRT runs the LLM pipeline on Hailo-10H.

Hailo-Ollama and REST/service alternatives are expressly excluded. The system under development is Æsir itself, integrating the native HailoRT C++ GenAI API behind an Æsir-owned narrow C ABI bridge callable from Mojo.

## Current machine evidence

- Device: Hailo-10H at PCI `0001:01:00.0`.
- Firmware and HailoRT: 5.3.0.
- Installed headers expose `hailort::genai::LLM` and document that the LLM pipeline executes on the Hailo device.
- An exact-version Qwen2.5-1.5B-Instruct HEF is being fetched from the official Hailo public artifact host for a direct backend smoke run; no inference has run yet.
- No CPU LLM inference or Hailo-Ollama call is part of this recovery.

## Implementation sequence

1. Finish and verify the version-matched model artifact transfer and integrity.
2. Build an Æsir-owned C++ bridge around HailoRT GenAI open/generate/clear/close operations; keep HailoRT's model execution in process and on device.
3. Link the bridge to a minimal Mojo caller and establish prompt/result/error ownership.
4. Run one small generation through this direct caller on the attached Hailo-10H and retain runtime/device evidence.
5. Integrate the proven bridge behind Æsir's Hailo backend and CLI. Ensure selecting Hailo cannot enter CPU/CUDA code.
6. Add lifecycle, context, cancellation, diagnostics, and packaging after the vertical slice works.

If a step fails, capture the exact compiler/runtime/device error, inspect installed HailoRT headers and matching official examples, correct the bridge or choose another officially supported Hailo-10H artifact/version, then repeat the direct device run. A failure does not authorize CPU inference, Hailo-Ollama, or a target change.

## Sources

- [HailoRT GenAI LLM implementation](https://github.com/hailo-ai/hailort/blob/master/hailort/libhailort/src/genai/llm/llm.cpp)
- [HailoRT C++ examples](https://github.com/hailo-ai/hailort/blob/master/hailort/libhailort/examples/README.md)
- [Official Hailo GenAI model catalog](https://github.com/hailo-ai/hailo_model_zoo_genai/blob/main/docs/MODELS.rst)
