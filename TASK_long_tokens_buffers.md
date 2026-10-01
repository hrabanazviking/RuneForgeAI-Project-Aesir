# Long-token throughput and bounded buffers — 2026-10-01

Volmarr explicitly authorizes further long-token, memory-speed, buffer-design and
robustness work, continuing the authorized GitHub publication workflow. Mythic
Engineering roles operate sequentially under reality-first law. Start from clean
main 05a7a1b and preserve its measured binary/manifest before implementation.

## Current truth and ownership

Native Llama 3.2 3B on sm_75 needs about 30.17 seconds for 1070 input tokens and
128 output tokens. Prefill processes every token through all layers separately,
reading packed matrices again and synchronizing after every token. Attention's
value reduction also walks history serially. KV stays F16 and context4096 requires
469762048bytes. Original scalar kernels and the working service remain references.

Compute owns packed batched projections, attention kernels and checked buffer
layout. Session owns causal KV ordering, sampler history and commit boundaries.
CLI/tooling own explicit controls, actual loaded capabilities and measurements.
Implement a bounded four-token layer-major prefill for the exercised 3B profile:
reuse each decoded weight across four independent accumulations, write each
position's KV and admit attention only through its causal position. Keep final
prompt logits fresh. Other profiles preserve their previous default until proved.

Give the tile a checked compact activation layout: per-token intermediates,
shared sequential attention scores and one logits region. Account for extra
capacity before CUDA admission. Preserve a batch-one control/reference and original
memory/reduction paths. Optimize long attention scheduling only after physical
reference/oracle checks and measurements support the change.

## Invariants and verification

Unchanged model bytes, quantization equations, tokenization, sampling, F16 KV,
context/security/resource ceilings, original embeddings and source corpus.
No hidden provider substitution, data/code deletion or new dependency. Every
buffer offset/span is checked before allocation; no overlapping live token data.
Commit an entire synchronized prefill tile or poison the session after GPU failure.
Control checks occur at bounded tile boundaries of at most four input tokens;
deadline/reset and cancellation recovery must execute, with any changed polling
granularity documented. Never promote GPU fault recovery from catching errors.

Before deployment prove synthetic projection/attention tails and independent
equations, real-model sequential/batched full-logit and completion equivalence,
seeded replay, cache divergence and deadline/reset recovery. Compare old/new
standard and extended public HTTP workloads, explicit prefill policy, memory,
actual counts and all failures. Distinguish long fresh prefill from cached work.
Run final master, negative control, real service/API gates, documentation/fixture
checks and exact pushed CI. Rebuild after final Mojo edits and restore the native
service. Verify database/embedding/corpus health without modifying production data.

## Completion boundary

Publish and deploy physically validated long-token/buffer improvements with
reproducible raw evidence, updated core/CLI/test interfaces, README_AI, ledger,
TODO, DEVLOG and human/AI manuals. Keep broad models/devices, full independent
external model logits, quantized KV and in-process context recreation unverified
until their own gates pass. Numerical equivalence to Aesir's sequential reference
is distinct from an independent external whole-model oracle.

## Implemented outcome and evidence

Four-token prefill, checked compact spans, shared logits/scores, chronological
attention scheduling and explicit observed batch controls are implemented.
Physical gates, exact native full logits, independent long-attention math,
real weights and service/API recovery pass. Fresh long-prompt requests improve
1.82–1.85x in this controlled subset; cached requests remain roughly flat.
Scratch adds396KiB and KV is unchanged. Source/scalar references are preserved.
See docs/NATIVE_LONG_TOKENS.md and docs/evidence/native-long-tokens-2026-10-01.md
for actual checksums, measurements, development failures, limits and commands.
Final remote CI and live deployment are separately verified by exact publication
revision and binary checksum; they are not inferred from the local gates.
