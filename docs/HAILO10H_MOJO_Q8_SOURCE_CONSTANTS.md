# Original Q8_0 source representation and byte tiles

Date: 2026-10-22. Pre-code contract: TASK_hailo10h_q8_source_constants.md,
published as `9b69894` before production edits. Source field qualification:
HAILO10H_Q8_SOURCE_LAYOUT.md. Production is original Mojo; no external
implementation is copied, translated or introduced as a runtime dependency.

## What changed

The packed loader now recognizes GGUF source tag 8 and checks 32-element row
alignment before calculating 34 bytes per block. Existing source kinds retain
their arithmetic and diagnostics. The current importer admits dense vectors and
matrices; other ranks and architecture layouts remain implementation work.
Tagged storage preserves original axes, paths, spans and dtype namespace.

The new source_q8_constants reader returns bounded, owned windows containing
the original binary16 scale word, its exact binary32 representation and signed
quant byte. Integer decoding preserves signed zeros, subnormals, infinities
and NaN payloads. The production reader evaluates no floating source product,
layer, attention or model. Source payload representation is actually decoded;
this is more than header inventory, but remains distinct from model execution.

The byte-tile consumer now selects Q8_0's 32-element/34-byte geometry. Partial
contractions include only touched source blocks, with exact unused prefix and
suffix counts. All spans are validated before payload copying. These are file
offsets and source bytes, not accelerator addresses, packing or resource fit.

## Completed verification

| Gate | Recorded result |
|---|---|
| Native rebuild | 76 Mojo entrypoints, zero compiler diagnostics; 640 actual source snapshots/hashes. Of 637 prior Mojo files, only the loader and byte-tile consumer changed; 635 remain unchanged. |
| Targeted suites | 30 suites, 200 methods, 9,309 recorded primary child calls. These include unchanged compiler/control tests and their existing independent oracles. |
| New Q8_0 tests | 10 methods, 137 native calls: 78 accepted and 59 expected refusals. Ownership, recovery, mutable descriptors, malformed headers, bounds, original names and actual graph metadata pass. |
| Complete component comparisons | 1,321 component records, including all 256 signed quant-byte values and scale special cases, block/row boundaries and final bytes. |
| Exhaustive scale coverage | All 65,536 binary16 scale words across 2,097,152 synthetic component records, compared through an independently computed integer digest. This is digest coverage, not 2,097,152 individual output comparisons. |
| Static constant reference | 256 synthetic constant values match exact binary32 results from the pinned isolated ggml-base reference. Its CPU backend is disabled; no model, graph, context or forward API runs. |
| Source byte tiles | 3,774 byte comparisons across partial blocks, rows and contraction tails; actual Q8_0 graph bindings and owned byte reads pass. |
| Legacy behavior | All 74 frozen controls covered by 4,308 complete successful stdout pairs and 4,023 nonzero exit/stdout/handled-error pairs. The storage API control is mutation-only; 73 controls have successful cases. |
| Source ownership | Ten new traces show 13 fixture opens, closes, read-only shared whole-file maps and matching unmaps. Source hashes are unchanged; zero target-device, network, ioctl or inference-runtime access. |

The primary-call total includes test-only native object oracles reused by
existing control suites. Those oracles were not rebuilt as part of the 76-Mojo
build count. All 62 prior Python test files and 74 control binaries remain
unchanged. An additional repeated four-method context run contributes 122
primary calls and 122 frozen comparisons, recorded separately from the table.

Whole GGUF mapping includes synthetic payload bytes; it is not header-only
access. Requested payload fields and byte tiles are read for compilation.
No physical numerical operation or source-model execution is claimed.

## Preserved failures and reporting corrections

The first API build rejected closing a borrowed owner inside the digest helper.
The corrected helper lets its local caller destroy the owner; final native
builds and cleanup traces pass. The original source and diagnostic remain.

A preliminary trace parser missed a split `strace -f` unmap. The retained raw
trace shows successful resumed cleanup. The corrected auditor joins syscalls
by PID and accounts for emitted whitespace; it verifies both selected and final
traces. The final original auditor also passed its unsplit traces. No native
source or build input changed for this audit correction.

The runner reused context-result.json for a status capsule, overwriting that
standalone test report. The capsule remains intact. A targeted repeat saves the
full transcript separately, and every native argument, status, stdout hash and
handled error matches the original 122 frozen-pair records. No complete suite
rerun or fabricated original transcript is claimed.

Evidence: docs/evidence/q8-source-constants-2026-10-22. It includes completed
build/test/source identities, census, byte/reference/trace evidence, exact
runners, audit review and retained outside-archive identities. The original
frozen drivers are historical reproductions; use the reviewed auditor for
split syscall traces. No vendor source, runtime binary or raw trace is vendored.

## Remaining target

Numerical Hailo precision/conversion/packing, instruction and register fields,
placement, original program upload, activation, results and cleanup remain open.
The Pi's control boundary is unchanged. Continue original compiler work and
bounded license-first physical configuration/transport research toward broad
ordinary unmodified source-model support. Other formats and architectures remain
implementation work. No DFC, outside model compiler/machine, precompiled model
prerequisite, inference proxy or CPU/CUDA/cloud LLM inference is introduced.

Documentation consistency retains 23,296 historical diagnostics with zero
normalized added or removed lines. Ledger: 118 verified / 163 unique IDs; nine
historical strict schema diagnostics remain. No whole-repository or hosted-CI
pass is claimed.
