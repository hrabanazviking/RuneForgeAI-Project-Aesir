# Hailo-10H initial performance hypotheses

**Roadmap Slice 008 — complete: provisional latency, throughput, and quality hypotheses**

These are planning hypotheses for a first Hailo-only text-generation profile,
not achieved Æsir results or a release claim. Qwen2-1.5B-Instruct is a
provisional workload reference only; no compiled artifact or Hailo-Ollama/
HailoRT path is approved for Æsir. Hailo's current GenAI model table reports a 2048-token context, 3.66 s
load time, 0.32 s time-to-first-token, and 8.06 tokens/s for that model. The
published table reflects Hailo's compiled/runtime path and does not establish
performance or feasibility for Æsir's native no-HEF path on this exact Pi.
Values are comparison context only; remeasure using Æsir's authorized Hailo
path before setting gates.

The hypothesis thresholds below are provisional goals, not extrapolations
claimed as achieved. If the native path cannot be established, record a Hailo
feasibility blocker; do not run an LLM on the CPU to fill the gap.

| Measure | Initial hypothesis | Measurement boundary |
|---|---:|---|
| Model load time | ≤ 5 s | From request to model-ready status; warm/cold conditions reported separately |
| Time to first token | ≤ 500 ms | Fixed short prompt after model is loaded |
| Decode throughput | ≥ 8 tokens/s | Greedy 128-token response; exclude prompt preparation and rendering |
| Supported context | 2048 tokens | Only if the exact artifact/runtime combination confirms it |
| Quality | No regression against a frozen task rubric | Same prompts and generation settings; score output from Hailo execution only |

Measure each value with the model, artifact hash, runtime version, prompt size,
Pi/HAT identity, Hailo device evidence, temperature, and power state recorded.
Do not compare these initial hypotheses to CPU LLM performance. No CPU LLM run
is part of this campaign.

## Sources

- [Hailo GenAI Model Zoo model and performance table](https://github.com/hailo-ai/hailo_model_zoo_genai/blob/main/docs/MODELS.rst)
- [Raspberry Pi AI HAT specifications](https://www.raspberrypi.com/documentation/accessories/ai-hat-plus.html)

## Slice 008 acceptance

- Proposed goals are identified as hypotheses, not measured AESIR results.
- Baselines include their model and measurement boundaries.
- Reproduction on the target Pi and Hailo-10H is required before these become
  release gates.
- No Pi CPU LLM comparison or run is introduced.
