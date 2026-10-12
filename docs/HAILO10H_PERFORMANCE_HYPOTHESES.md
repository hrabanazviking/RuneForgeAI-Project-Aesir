# Hailo-10H initial performance hypotheses

**Roadmap Slice 007 — provisional latency, throughput, and quality goals**

These are planning hypotheses for a first Hailo-only text-generation profile,
not achieved Æsir results or a release claim. The reference candidate is
Qwen2-1.5B-Instruct using a Hailo-10H-compatible artifact and the Hailo-Ollama
API. Hailo's current GenAI model table reports a 2048-token context, 3.66 s
load time, 0.32 s time-to-first-token, and 8.06 tokens/s for that model. The
published table does not establish performance on this exact Pi/AESIR setup;
all values must be reproduced on the target hardware before they become gates.

| Measure | Initial hypothesis | Measurement boundary |
|---|---:|---|
| Model load time | ≤ 5 s | From request to model-ready status; warm/cold conditions reported separately |
| Time to first token | ≤ 500 ms | Fixed short prompt after model is loaded |
| Decode throughput | ≥ 8 tokens/s | Greedy 128-token response; exclude prompt preparation and rendering |
| Supported context | 2048 tokens | Only if the exact artifact/runtime combination confirms it |
| Quality | No regression against a frozen task rubric | Same prompts, template, and generation settings; score on Hailo output only |

Measure each value with the model, artifact hash, runtime version, prompt size,
Pi/HAT identity, Hailo device evidence, temperature, and power state recorded.
Do not compare these initial hypotheses to CPU LLM performance. No CPU LLM run
is part of this campaign.

## Sources

- [Hailo GenAI Model Zoo model and performance table](https://github.com/hailo-ai/hailo_model_zoo_genai/blob/main/docs/MODELS.rst)
- [Raspberry Pi AI HAT specifications](https://www.raspberrypi.com/documentation/accessories/ai-hat-plus.html)

## Slice 007 acceptance

- Proposed goals are identified as hypotheses, not measured AESIR results.
- Baselines include their model and measurement boundaries.
- Reproduction on the target Pi and Hailo-10H is required before these become
  release gates.
- No Pi CPU LLM comparison or run is introduced.
