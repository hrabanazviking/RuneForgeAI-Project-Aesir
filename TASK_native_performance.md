# Native inference performance and efficiency — 2026-10-01

Volmarr authorizes broad Aesir performance, efficiency and reliability improvements,
and publication to the owning GitHub project. Architect, Forge Worker, Auditor
and Scribe operate sequentially using Mythic Engineering and reality-first law.

## Current truth

main is clean at 501a728. Native Llama 3.2 3B Q4_K_M generation is physically
verified on a 6 GiB RTX 2060 (sm_75). Last warm 32-token passage cost about 8.1 s;
237-token prompt cost about 30.2 s. This is slower than local Ollama. The current
forward pass rebuilds layer names, decodes packed values individually, launches
many small kernels, and synchronizes each prefill token. No all-model or all-GPU
speed claim is justified. Bifröst uses working Ollama chat and original embeddings.

## Ownership and execution

Compute owns numerical kernels and session plans; tokenization owns encoded
prompts; generation owns KV/state/control; tooling owns reproducible profiling
and measurement. First preserve a baseline binary and exact public-prompt results,
then profile real native CUDA work. Implement measured bottlenecks in vertical
slices: packed projection decoding, repeated host planning/launch overhead,
attention/prefill scheduling where supported by measurements. Shared kernels may
benefit other admitted profiles but only exercised paths gain verified status.
Keep reference implementations and explicit rejection/fallback boundaries.

## Invariants and gates

Same GGUF bytes, tensor validation, quantization equations, reduction order where
possible, context bounds, finite checks, sampler semantics, UTF-8, cancellation,
reset, authentication and fail-closed behavior. No source corpus or embedding
changes. No driver churn, hidden Ollama substitution, speculative compatibility,
user data deletion or Git settings changes. Record any numerical drift explicitly.

For each slice: build exact locked Mojo/sm_75, independent real Q4/Q6 dot-product
oracle and reference comparison, representative whole-model deterministic outputs,
actual HTTP deadlines and next-request recovery, measured warm varied queries.
Run counted master, negative control and documentation/fixture checks on final
code; verify exact pushed CI. Restore the supervised service with a fresh manifest.
Update core/test interfaces, README_AI, capability ledger, TODO, DEVLOG, native
manual and portable measured report. Evidence must retain failures and limitations.

## Completion boundary

Publish and deploy validated improvements with baseline/comparison artifacts and
reproducible commands. Performance is an ongoing engineering objective: report
measured achieved gains and precise remaining bottlenecks rather than claiming
universal optimality or parity with Ollama without evidence.
