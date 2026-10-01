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

## Next measured slice: exact prefix reuse

The block reader completed 15 real HTTP samples with replies/counts identical to
the archived binary and 2.95–3.00x faster warm medians. Physical reference blocks
and 35 independent real-weight rows passed. The prepared layer plan compiles.
Next add single-session bounded exact-token prefix reuse across reset, with a
disable switch for fresh-prefill measurements. Rebuild sampler history and leave
at least the final prompt token for fresh logits. Reuse only healthy synchronized
KV from the same model/session; mismatches stop reuse immediately. Preserve
token-boundary cancellation and poisoned-session behavior. Test diverging input,
sampling-policy changes, timeout/reset and independent fresh-session equivalence.
Cached and uncached measurements must remain separately identified.

## Measured result and follow-through

Final cache-disabled medians improve 2.97–3.02x; repeated exact prefixes improve
5.56–21.11x over the archived uncached binary. All 30 final replies match baseline
text/counts/finish state. Physical independent rows, reference blocks, sampled/
greedy prefix equivalence, deadline/reset, native HTTP faults, 29 API fixtures
and two persistent chat turns pass. Source/build identities and every raw sample
are published with the performance manual and evidence report. Supervised native,
Bifröst and watcher services are restored; Bifröst keeps faster Ollama for its
usual 32-token workload. New benchmarks are standalone supervisor/measurement
tools and never substitute provider inference. Fresh final CI remains a gate.

Publication corrections preserve runtime code: synchronize E-MASTER to total187
and give new hosted probes the explicit package search root used locally. Context
recreation stalled in a two-context harness; retain process replacement and leave
its runtime/vendor investigation open. Batched prefill/full logits/broader models,
long-context attention and devices remain future acceptance work.
