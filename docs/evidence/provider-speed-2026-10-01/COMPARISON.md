# AESIR versus installed Ollama — measured 2026-10-01

Both run on the same RTX 2060 Max-Q. The actual Ollama runner points to the
same SHA-256 GGUF bytes as AESIR's loaded Llama 3.2 3B model. Context is 4096,
temperature 0 and repetition penalty 1. AESIR binary f3442a1e5915cb43ec4da8a0f885ff38710a02b6ef795515dbe1f72c36ceda2b,
revision 59094de4fdcd9f423c974043f802c295a217a533, prefill batch 4. The installed
Ollama service reports version 0.0.0 and uses its llama-server CUDA runner.
Both models reside on the GPU during the paired tests. All 40 requests complete.

## Repeated exact prompts

Median of three requests after one initial appearance per case. Whole HTTP wall
time, including prompt processing and generated output; not decode-only timing.

| Work | AESIR seconds | Ollama seconds | Observed faster service |
|---|---:|---:|---|
| One-word arithmetic answer | 0.094 | 0.329 | AESIR, 3.51x |
| Short input, 32 output tokens | 0.820 | 0.870 | AESIR, 1.06x |
| Longer input, 32 output tokens | 0.845 | 0.880 | AESIR, 1.04x |
| Long input, 128 output tokens | 3.557 | 2.869 | Ollama, 1.24x |
| Short input, 128 output tokens | 3.314 | 2.719 | Ollama, 1.22x |

The arithmetic answer text matches exactly (Four.), but AESIR counts 2 generated
tokens and Ollama 3. Other rows generate exactly 32 or 128 as labeled. Identical
requested user/system text yields different prompt token counts: native 30/37/237/
1070/52 versus Ollama 50/57/257/1090/72. Providers' chat templates differ.

## First appearance of new prompts

Both models are already loaded for these rows. Earlier requests can share framing
or input prefixes, so these are not strictly cache-disabled measurements.

| Work | AESIR seconds | Ollama seconds | Ollama speed ratio |
|---|---:|---:|---:|
| Short input, 32 output tokens | 1.057 | 0.904 | 1.17x |
| Longer input, 32 output tokens | 3.192 | 1.023 | 3.12x |
| Long input, 128 output tokens | 13.559 | 3.325 | 4.08x |
| Short input, 128 output tokens | 3.698 | 2.769 | 1.34x |

Ollama's first arithmetic call took 4.539 seconds, including reported 4.353 seconds
model load; AESIR was already resident. That pair is excluded from loaded-model
speed conclusions. Separate service startup cost was not controlled here.

## Scope and raw evidence

Ollama actually uses q8_0 K/V; AESIR uses F16 KV. The models share packed weight
bytes, but templates and KV precision differ. Longer completions are different
text across providers, though actual generated counts are equal. Ollama first and
repeat longer responses can also differ despite greedy settings. This compares
the installed usable services, not full numerical parity or a universal provider
ranking. Small samples, cache history, thermal/clock variation, provider grouping
and service overhead constrain the results. No configuration/code changes, model
replacement, corpus/embedding writes or service restarts were performed.

[32-token and arithmetic raw samples](paired-current.json).
[128-token raw samples](paired-long-output.json).
[Actual provider runtime](provider-runtime.json).
