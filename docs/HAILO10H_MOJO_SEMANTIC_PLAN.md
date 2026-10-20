# Mojo source semantic graph

Date: 2026-10-19. Parent: `TASK_hailo10h_source_compiler_plan.md`.

## Implemented boundary

`smidr/semantic_plan.mojo` reads one live PackedGGUF mapping and returns an
owned source descriptor snapshot plus a typed graph. It imports no execution
backend, hardware registry, tensor allocation, numerical kernel or device API.
Production remains Mojo. The first semantic importer covers the dense Llama
RMSNorm/SwiGLU decoder skeleton; this is incremental compiler coverage, never
a permanent model allowlist or a statement about Hailo architecture support.

The graph has embedding gather; per-layer RMS normalization, Q/K/V linear
projections, query/key RoPE, key/value cache append views, GQA scaled dot,
causal mask, softmax, weighted values, attention output projection and residual;
then FFN normalization, gate/up projections, SiLU, product, down projection and
residual; final normalization and logits. Linear weights use source columns as
input width and rows as output width. All query-token logits are represented;
last-token selection/sampling is later work. No numerical model forward runs.

Source metadata supplies layer/hidden/FFN/head dimensions, rotary extent, base
and RMS epsilon. Optional key/value dimensions are separate; their specified
defaults require integral hidden/head division. KV head grouping must divide
query heads. Positive shape products are checked against signed Int64 overflow.
Context capacity is explicitly supplied, positive and bounded by source context;
query > 0, past >= 0, query + past <= capacity is checked without overflowing.
No machine memory capacity, numerical precision or hardware geometry is guessed.

Weights retain exact offset, shape, packed kind and byte extent. An absent
`output.weight` shares the existing embedding binding. A present output has its
own checked binding. Every source tensor must be accounted for: unknown biases,
Q/K normalization, rope factors or other tensors produce a named semantic
importer gap. Unknown architecture metadata modifiers and scaled RoPE also
produce named gaps instead of being silently discarded. Other architectures
remain importer work; they are accepted by the general tensor inventory.

Tensor IDs and operation order are explicit. Each value records producer and
inclusive last use. Persistent key and value storage spans the entire graph;
append outputs are views aliasing those bases, not separate cache allocations.
Residual edges keep their source values alive. Exported logits live through the
end sentinel. The graph contains 21 operations per layer plus three global
operations. It is a logical sequential schedule, not a chip schedule.

## Verification

Build with Mojo 1.1.0:

```sh
MODULAR_CACHE_DIR=../mojo-cache mojo build -I . -I aesir_engine smidr/tools/semantic_plan.mojo -o ../semantic-plan
python3 tests/test_hailo_semantic_plan.py --binary ../semantic-plan --strace /usr/bin/strace --evidence docs/evidence/semantic-plan-2026-10-19
```

Nine independent Python structural methods passed, **56 native fixture runs:
14 accepted and 42 refused**. Synthetic source bytes remain SHA-256 identical
before/after every child. The oracle checks exact operation ordering and named
edges, matrix orientation, every shape/product, every last-use index and cache
alias, prefill/decode/cached chunks, unequal key/value widths, two layers,
embedding sharing, MHA defaults, and F32/F16/BF16/Q4_K/Q5_K/Q6_K descriptors.
Overflowing context/head products, invalid metadata/session shapes, non-finite
parameters, unhandled semantics, missing/mismatched weights and truncation refuse.

The refactored inventory tool was rebuilt; its six methods/16 child runs pass.
A source-graph syscall trace confirms read-only private mapping and unmapping,
with no Hailo node, CUDA library or HailoRT library access. Initial ownership
compiler errors and the first narrower passing run are retained in evidence.
The final evidence is `docs/evidence/semantic-plan-2026-10-19/`.

## Open gates

The JSON explicitly reports executable_program, execution_tested,
hardware_fit_verified and source_fingerprint_verified as false. Source layout
text is preserved, including unfamiliar layout names. RoPE pairing/permutation,
layout normalization, packed quantization recipes, numerical precision and
activation layout still require implementation and verification. Required
runtime preconditions are in-vocabulary token IDs, positions past + query index,
and an initialized KV prefix. No runtime exists to enforce them yet.

Lifetimes do not establish memory bytes or resource fit. Allocator alignment,
workspace, weight conversion/duplication, precision, measured hardware budgets,
operation lowering, actual program encoding, upload and numerical hardware
acceptance remain open. No COMPUTE_UNKNOWN/SMIDR-CFG host data is executable or
submitted. The next slice applies checked storage/lifetime arithmetic with
explicit policy and budget provenance, then continues the actual program gap.

## Provenance

Original Aesir graph construction reuses project-owned source parsing only.
Public GGUF metadata/default facts were checked in the already MIT-licensed
specification pinned at `a05c9922613c6a2230dbb1d0de679519ecafb4f0`:
https://github.com/ggml-org/ggml/blob/a05c9922613c6a2230dbb1d0de679519ecafb4f0/docs/gguf.md
No external implementation, model program, runtime or numerical kernel was
copied, translated, linked or executed.
