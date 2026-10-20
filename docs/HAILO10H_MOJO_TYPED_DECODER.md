# Owned typed decoder inputs and compatible semantic graph construction

Date: 2026-10-20. Contract: `TASK_hailo10h_source_neutral_semantics.md` and
`HAILO10H_SOURCE_NEUTRAL_SEMANTIC_AUDIT.md`, published before implementation.
Scope: `HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md`.

## Connected implementation

`smidr/semantic_plan.mojo` now exposes owned `DenseDecoderParameters` for
layer/hidden/feed-forward/head/KV/key/value/rotary/vocabulary/context dimensions,
exact Float32 RoPE base/RMS epsilon and the source layout annotation.
`gguf_dense_decoder_parameters` validates and decodes the existing live GGUF
metadata recipe, including types, defaults, optional vocabulary, unknown
modifiers and scaled-RoPE refusal. A closed metadata owner is rejected.

`build_dense_semantic_plan` consumes an owned existing source inventory and typed
parameters plus query/past/capacity. It rechecks positive dimensions, products,
finite positive numerical parameters, session/context extents, vocabulary and
the exact consumed weight set/shapes. Mutable descriptive GGUF bindings are
checked for valid packed kind/row size, positive rows, exact byte counts, file
extents, aggregate bytes and overlap. An original paired heapsort uses linear
scratch metadata and O(n log n) work; it does not reorder the actual bindings.
This is descriptive validation, not an immutable backing-file certificate.

The existing `read_dense_semantic_plan` delegates to the adapter and builder.
Its mapping is closed before mathematical graph construction; exceptions also
close the source. The graph is built entirely from owned values. Existing
operation/tensor ordering, edges, producers, lifetimes, cache aliases, weights,
tied output, numerical values, layout annotation and unresolved gates are
preserved. The inspector shares `describe_semantic_plan` with the typed
inspector so the whole graph can be compared without a lossy summary.

Storage remains explicitly **GGUF-specific**: current source-kind values and
packed row widths have not been cast into the safetensors namespace. The typed
configuration boundary alone does not connect safetensors to the graph. The
current Llama recipe is incremental implementation coverage, never a permanent
model eligibility rule. Full source tags, shapes, original names, backing-file
provenance and ordinary config/index/alias facts are the next dependencies.

## Independent verification on this Pi

All **54 methods / 1933 native child calls** passed. These are structural and
static source checks; no model/layer/attention forward or device call occurred.

| Suite | Methods | Calls | Accepted / expected refusal |
|---|---:|---:|---:|
| New typed decoder | 7 | 493 | 243 / 250 |
| Existing semantic graph | 9 | 56 | 14 / 42 |
| Primitive recipes | 7 | 44 | 27 / 17 |
| Expanded graph | 5 | 45 | 32 / 13 |
| Semantic storage | 7 | 61 | 32 / 29 |
| Expanded storage | 7 | 88 | 34 / 54 |
| Matrix schedules | 7 | 860 | 799 / 61 |
| Source weight byte tiles | 5 | 286 | 256 / 30 |

Thirty positive fixtures compare the **complete decoded graph** from the frozen
pre-refactor binary, compatible GGUF entry point and direct typed builder.
They include session shapes,1/2/4 layers, tied output, unequal value width,
explicit non-integral hidden/head defaults, MHA defaults, F32/F16/BF16 and all
three existing K-quant kinds, exact numerical settings and an unfamiliar Unicode
layout annotation. The old binary was built from published `6ec0593` before
editing the implementation; its SHA-256 is
`74eea76b3d596f841098ddf04a81f9910bfcc622698fd5e66d71e44dbf1775cd`.
An independent test-owned edge/shape/lifetime oracle checks every accepted graph.

Direct API checks cover invalid dimensions/products/head divisibility/vocabulary,
context/session overflow, both signs of zero, infinities and several NaN words;
native assertions verify twenty positive Float32 parameter words exactly,
including subnormals and the maximum finite word. Owned graph values survive
input mutation and independent graphs do not share mutable storage. A synthetic
inventory builds without opening any model file. Span checks compare hundreds
of permutations/seeded collections, equal/contained/touching/extreme endpoints
and2000-span probes against an independent sorted-interval oracle.

The tile regressions retain6672 coordinate and88368 exact source-byte checks.
The existing recipe suite interprets isolated tiny mathematical primitives in
test tooling only; it does not run a model, layer or attention forward. Syscall
traces show read-only mappings/cleanup for file paths and no Hailo, CUDA,
HailoRT, GGML or ioctl access. The typed source mapping is unmapped before the
returned graph is printed. Evidence is under
`evidence/typed-decoder-2026-10-20/`.

Initial compile failures (missing raises, ownership moves, decimal parsing) are
preserved. An initial test harness import exposed the imported unittest class
to discovery; all seven new methods passed but that unrelated class setup
failed without its own arguments. The harness now imports its oracle module
rather than exposing that test class; the complete rerun passes. Final builds
are warning-free. No historical failure was relabeled as a pass.

## Remaining execution work

This verifies the typed configuration/graph boundary. It does not verify ordinary
safetensors/config/shard semantic integration, immutable source identity,
physical precision/packing/placement, numerical Hailo instructions, original
program upload/activation/results/cleanup or broad model execution. Unknown
layouts and actual operation encoding remain unresolved. No external compiler,
vendor-precompiled artifact, special user conversion or host inference route
was introduced. The owner's full broad ordinary-model target remains open.

Hosted CI still has the previously observed historical-master compilation
failure on `8d134c0`; subsequent gates were skipped. This local evidence is not
a full CI pass. The repository consistency checker also retains its78 historical
issues (including its obsolete requirement to run CPU model forwards); none
references the new typed implementation. No gate was weakened. Observe the
new published SHA separately after publication.
