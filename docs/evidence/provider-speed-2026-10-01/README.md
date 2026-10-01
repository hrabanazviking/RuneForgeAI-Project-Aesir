# Installed-provider speed evidence — 2026-10-01

Owner: measurement domain. Purpose: preserve the observed AESIR/Ollama baseline
used by [the speed roadmap](../../../ROADMAP_AESIR_SPEED_LEAD.md). This directory
contains public synthetic-request measurements, not production corpus data,
credentials, model weights, generated executables or runtime configuration.
The roadmap and capability ledger remain the consumers and status authorities.

## Provenance and measurement boundary

These reports were generated locally against runtime revision
`59094de4fdcd9f423c974043f802c295a217a533` on the same physical RTX 2060 Max-Q.
[COMPARISON.md](COMPARISON.md) explains observed results and policy differences.
The paired JSON files are preserved byte-for-byte from the measurement run.
The summary has only a spacing correction. Project-authored reports inherit the
repository license; model bytes and third-party source are not included.

The 32-token series used [benchmark_second_brain.py](../../../scripts/benchmark_second_brain.py)
from the baseline revision with three measured samples after one initial request
per provider/case. Its `short`, `passage` and `longer_prompt` inputs are defined in
that source. The 128-token series used an isolated measurement harness with
`EXTENDED_PROMPTS` from [benchmark_native.py](../../../scripts/benchmark_native.py):
`long_context`, then `sustained_generation`. For each case the order was AESIR
first, Ollama second; each provider received one first appearance and three
identical repeats. No provider-order randomization or isolated-residency test
was performed. Both models were resident during loaded-model comparisons.

Both series sent system text `You are concise.`. Native requests used
`/v1/generate`, the exact user prompt, temperature 0 and the declared output
ceiling. Ollama requests used `/api/chat`, `stream: false`, model `llama3.2:3b`,
separate system/user messages, and options `temperature: 0`, `num_ctx: 4096`,
`num_predict: 32` or `128`, `top_k: 40`, `top_p: 1`, `repeat_penalty: 1`,
`seed: 42`. Native greedy service policy had repetition penalty 1.
The 128-token harness required exactly 128 returned tokens and complete replies.
It is not checked in as a portable production tool; SPD-00 owns that integration.

A runtime-process/API observation produced [provider-runtime.json](provider-runtime.json).
Its observed model path is represented by the weight SHA-256, preserving identity
without publishing a machine-local path. Ollama's API model digest is a manifest
identity and differs from the GGUF byte digest. Weight equality uses the latter.

Archived samples contain completion hashes/counts, not complete text, token IDs,
all raw responses or isolated first-token/prefill/decode timings. They cannot
establish full numerical parity, a controlled cache-disabled comparison or a
statistically certified lead. SPD-00 requires fuller evidence for future claims.
Reproduction is described in the roadmap; live measurements will vary.

## Data schema and validation

The JSON reports are standalone UTF-8 objects read by Python `json` and the
roadmap auditor. `paired-current.json` has 24 samples, output ceiling 32 and
`warmup`/`warm` phases; `paired-long-output.json` has 16 samples, ceiling 128 and
`first`/`repeat` phases. Each successful sample records provider, case, phase,
positive seconds, prompt/generated counts, finish reason and text SHA-256.
Provider-supplied load/decode durations can be null. Median fields summarize only
the three measured repeats for each provider/case. Failure fields/counts remain
visible and must be checked before computing ratios. No failures occurred here.
The runtime report records observed runner flags, API residency, same-host
observation and the expected weight digest.

Before reusing this snapshot, verify checksums, parse all JSON, require 40
successful samples, recompute per-provider/case repeat medians, and compare
model/context/output ceilings with the stated policies. Missing/malformed data,
nonfinite durations, unequal required output counts or failure records invalidate
a speed claim; they must not be discarded to produce a ratio. These documents
are evidence, not an inference entry point or a live service configuration.

| Artifact | SHA-256 |
|---|---|
| `COMPARISON.md` | `9573dc50e91b72da4288eea7f6b9b4a53cf0ccb8e444699394a00c668e665e8c` |
| `paired-current.json` | `7d44069f6c37fe5b43baa14a4d3aacb61d36198b64ccc8b6e7b8cade6d0e658c` |
| `paired-long-output.json` | `61c9d7c3b38cc61b61fc6917a7ce1da83f4bd43f9daeab9d4f2b27ad164b29d3` |
| `provider-runtime.json` | `1fe85b1853aefe847ca73d6de2291ab51e610a9f186d1d6ffe1b9812be7478fa` |
