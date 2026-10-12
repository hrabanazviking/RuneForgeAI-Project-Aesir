# Hailo-10H campaign — prohibited inference paths

**Roadmap Slice 005 — complete**

## Absolute campaign boundary

This campaign does not develop or enable any LLM inference execution on the Raspberry Pi CPU. This prohibition includes:

- CPU-only or CPU-default model execution.
- CPU fallback when the Hailo device, transport, model, or operation is unavailable.
- CPU shadow execution to verify Hailo LLM results.
- CPU LLM serving, whether exposed through Æsir, Ollama, llama.cpp, Transformers, or another runtime.
- CPU performance optimization, benchmarking, model quantization, or pipeline completion whose purpose is LLM inference.
- A NO-GO branch that continues Æsir LLM development on the Pi CPU.

The host may run the operating system and ordinary application/control work such as request parsing, model metadata and weight-file reading, tokenization, sampling, result formatting, diagnostics, and device orchestration. Those responsibilities must not execute transformer/model inference operations.

## Failure behavior

When Hailo-10H execution is unavailable or unverified, Æsir returns a named, actionable error and performs no LLM inference. It does not silently switch devices or use a secondary backend. No Hailo blocker changes this rule.

## Scope evidence

This is the user's explicit campaign boundary, applied to the repository's Hailo mission and the existing docs/HAILO10H_INFERENCE_POLICY.md. The legacy roadmap's F1 CPU fallback, CPU shadow checks, CPU pipeline, and CPU soak/benchmark slices are explicitly excluded from this campaign.

## Acceptance

- CPU LLM inference and its fallback/serving/development tracks are explicitly prohibited.
- Non-LLM host orchestration is distinguished from model execution.
- Device failure behavior is fail-closed.
- No implementation or performance task in this campaign has CPU inference as its goal.
