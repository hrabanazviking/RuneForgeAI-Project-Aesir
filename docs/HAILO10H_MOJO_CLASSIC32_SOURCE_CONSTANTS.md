# Original classic Q4/Q5 source conversion and shared block geometry

Date: 2026-10-22. Pre-code contract:
TASK_hailo10h_classic32_source_constants.md, published at `5b8c132` before
production edits. Qualified source fields: HAILO10H_CLASSIC32_SOURCE_LAYOUT.md.
Production is original Mojo; no external implementation is copied, translated
or introduced as a runtime dependency.

## Implementation

The packed GGUF loader admits source kinds 2/3/6/7 for Q4_0, Q4_1, Q5_0 and
Q5_1. PackedBlockGeometry supplies exact elements and bytes per block for these
and every previously supported format. Row limits, alignment and unrelated
unknown-kind diagnostic routing remain preserved. The lazy source byte-tile
consumer uses the shared geometry while retaining its existing owner, binding,
schedule, span and host-bound guards. Partial tiles copy whole touched source
blocks and retain exact row offsets and unused prefix/suffix elements.

The new source_classic32_constants reader infers the source kind and returns
bounded owned windows of scale/bias binary16 words, exact binary32 bit
representations, bias presence and quant components. An absent bias remains
distinct from a present zero or negative zero. Live ownership, exact axes,
kind, checked products, data-origin bounds, complete source spans, selection
and explicit host bounds are validated before component allocation or decoding.
Production evaluates no floating tensor product or addition.

These are source-format fields and file offsets. They establish no accelerator
precision, physical packing, memory fit or numerical instruction. The current
importer handles dense vectors/matrices; remaining formats, ranks, architectures
and operations remain implementation work toward the full broad target.

## Completed acceptance

| Gate | Recorded result |
|---|---|
| Current native rebuild | 81 Mojo entrypoints with zero diagnostics: the original 78-entrypoint closure plus three source-storage consumers added during coverage review. All 643 current source snapshots/hashes match. Only two of 640 prior Mojo sources changed; 638 remain unchanged. |
| Additional baseline builds | Three clean Mojo builds from the actual preserved 640-file pre-code snapshot. These were built after implementation, with the snapshot as working directory and import roots; they are not described as binaries frozen before production. |
| Final targeted acceptance | 32 suites, 219 methods, 10,549 recorded primary child calls. Existing test-only C++ oracle calls are included in the primary-call census; those binaries were reused, not counted as Mojo builds. |
| New classic-format suite | 12 methods, 788 calls: 488 accepted and 300 expected refusals. All quant values, every Q5 high-plane bit, nibble halves, special scale/bias words, original names, boundaries, malformed inputs, mutations, ownership and recovery are covered. |
| Complete component comparisons | 26,611 records against independent synthetic byte writers, including seeded combinations. No digest-only coverage is counted as complete comparisons. |
| Source byte tiles | 11,322 byte comparisons across actual graph bindings, source rows, partial blocks and tails. |
| Static reference | 2,048 synthetic constants match exact binary32 results from the pinned isolated ggml-base static decoders. These are a subset of component comparisons. The CPU backend is disabled; none of that library's model/context/graph/forward APIs is called. |
| Public-header object oracle | A separate clean C++ build/execution checks all four block sizes and scale/bias/high-plane/nibble offsets against the pinned public header. |
| Preserved behavior | 4,753 complete successful stdout pairs and 4,167 nonzero exit/stdout/handled-error pairs cover 79 controls. Of these, 76 binaries were frozen before production and three were subsequently built from frozen pre-code sources. One original storage-scenario API is mutation-only; 78 controls have successful cases. No unrelated comparison is skipped. |
| Changed legacy storage test | All seven methods pass, adding 452 primary calls and their complete baseline comparisons. The source-storage API's real GGUF kind-2 case changes from unsupported type to 256 elements/144 bytes. |
| Source ownership | 45 new trace files contain 60 opens, closes, read-only shared whole-fixture maps and matching unmaps. Source bytes remain unchanged; zero target-device, network, ioctl or inference-runtime access occurs in these native traces. |

The build total is 81 current plus three pre-code-snapshot baseline Mojo builds,
not 84 current entrypoints. The selected preliminary six builds and 12-method /
788-call run are retained separately from final acceptance. Aesir constructs
source-bound compiler graphs; no layer, attention or model forward runs.
Whole GGUF mapping includes synthetic payload bytes, and requested fields and
tiles are actually decoded/read. This is source conversion, not model execution.

## Intentional admission change and preserved failures

One legacy negative arithmetic case used GGUF kind 2 with shape [256] as an
unsupported sentinel. Its original Python contents remain preserved. The
negative sentinel now uses still-unsupported kind 9; other formats remain work.
Safetensors dtype 2 retains its independent F32 meaning. Valid independent
source bytes and the corrected direct API comparison prove the new admission.

Coverage review found that the inherited suite list omitted the changed
source-storage test. The original runner's final extra proof also selected
`tests/hailo_storage_api.mojo`, a different scenario API. Its earlier
former-sentinel.json is a usage failure, not evidence of unsupported kind 2.
All 31 inherited suites and 76 control comparisons passed, but the runner's
last wiring assertion failed. The original runner, failure and misdirected
baseline result remain intact. The added three current/three snapshot-baseline
builds and full seven-method storage suite close that gap; the actual
`tests/hailo_source_storage_api.mojo` supplies the successful corrected proof.
No production or frozen test/build input changed to make this correction.

The selected trace parser rejected spacing between a resumed mmap's closing
parenthesis and return equals sign. Raw traces show the successful operation.
A separate corrected auditor retains PID-scoped unfinished/resumed joins and
all access/lifetime assertions. Both original final audits passed; the corrected
auditor also passes, with originals retained. The evidence recorder initially
assumed 50 trace files; the actual census is 45 files and 60 balanced lifecycles.
That recorder failure and its correction are retained. Native results did not
change. Status and report filenames remain distinct.

## Evidence and remaining work

Evidence: docs/evidence/classic32-source-constants-2026-10-22. It records actual
source/input/binary/fixture identities, suite census, complete additional-storage
transcripts, original runners, wiring/audit corrections and outside archive
hashes. Original runners are historical reproductions, including the failed
last probe; the supplemental build/verification scripts supply its correction.
Source snapshots, raw traces and binaries remain outside the repository; no
vendor source or reference binary is vendored. Portable JSON replaces only the
absolute workspace prefix, with original/published document identities recorded.

Numerical Hailo precision/conversion/packing, operation/register/configuration
fields, placement, valid original program delivery, activation, results and
cleanup remain open. Bounded license-first physical-interface research and
original compiler work continue automatically toward broad ordinary unmodified
source-model support. No DFC, outside model compiler/machine, precompiled
prerequisite, inference proxy or CPU/CUDA/cloud LLM inference is introduced.
No numerical Hailo/source-model execution or whole-repository/hosted-CI pass
is claimed. Historical and concurrent work remains preserved.

Documentation consistency retains 23,296 historical diagnostics with zero
normalized added or removed lines. Ledger: 119 verified / 164 unique IDs; nine
historical strict schema diagnostics remain. No whole-repository pass is claimed.
