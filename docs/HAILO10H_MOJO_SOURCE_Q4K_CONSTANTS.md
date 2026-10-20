# Owned Q4_K source affine constants

Date: 2026-10-20. Contract: `TASK_hailo10h_q4k_constants.md`.
The bit-field facts and license were published before implementation in
`HAILO10H_Q4K_SOURCE_LAYOUT.md`.

## Compiler interface

Original Mojo `smidr/source_q4k_constants.mojo` interprets the published group
descriptors with a generic integer bit-field reader. `read_q4k_constants`
borrows a live PackedGGUF owner, validates source kind 12, checked shape/packed
extent, source data boundary and explicit first/count/host bound, then returns
an owned `Q4KConstantWindow`. Its path wrapper destroys the mapping before
returning. No source pointer escapes. Complete 256-element blocks retain
source group/block/row order; the last nibble is read through the final aligned
half-word without crossing the 144-byte block boundary.

Each selected constant retains unsigned q, six-bit scale/min factors, raw
binary16 d/dmin words and their exact binary32 representation bits. Production
evaluates no floating arithmetic. The mathematical source expression remains
`(d * scale_factor) * q - dmin * min_factor`; a device rounding, packing,
quantization or layout policy has not been chosen. Special scale patterns,
including signed zero, subnormals and NaN payloads, stay representation data.
No finite-value/numerical device admission follows from successful decoding.

The diagnostic inspector caps a window at 4096 constants for host allocation;
the borrowed API requires the caller's explicit positive bound. This is neither
a model-size limit nor a hardware-format allowlist. Unsupported conversions
remain further compiler work toward the owner's same broad model objective.

## Acceptance

Warning-free Mojo 1.1.0 builds and targeted tests:

```sh
MODULAR_CACHE_DIR=../mojo-cache mojo build -I . -I aesir_engine smidr/tools/source_q4k_constants.mojo -o ../source-q4k-constants
MODULAR_CACHE_DIR=../mojo-cache mojo build -I . -I aesir_engine tests/hailo_source_q4k_api.mojo -o ../source-q4k-api
python3 tests/test_hailo_source_q4k_constants.py --binary ../source-q4k-constants --api-binary ../source-q4k-api --strace /usr/bin/strace --reference-library ../ggml-format-study/build/src/libggml-base.so --evidence docs/evidence/source-q4k-constants-2026-10-20
```

Eight methods pass, **57 native calls: 28 accepted, 29 refused**. Independently
packed fixtures cover every factor value 0–63 in each of eight groups, every
nibble 0–15, asymmetric low/high bit planes, group/block/row crossings, full
multirow windows and the final byte at exact file end. Repeated windows are
deterministic. Host-bound refusal is checked against a source large enough to
hold the otherwise valid request. Missing/wrong-format/truncated sources,
closed owners, invalid shapes/overflow, mismatched extents/data boundaries and
zero/negative/narrow host bounds are refused. Owned arrays survive mapping
destruction and do not alias another returned window. Source hashes remain
unchanged. The read-only trace opens no Hailo node or CUDA/HailoRT/ggml library.

The test-only frozen MIT ggml reference at revision
`a05c9922613c6a2230dbb1d0de679519ecafb4f0` independently dequantizes 16 synthetic
blocks / 4096 constants. Its exact binary32 bits match isolated reconstruction
from returned components with explicit F32 steps. Only this static reference
routine is called: no ggml context, compute graph, backend or model API runs.
The reference uses finite scales; special scale words are checked separately
as raw representations, without evaluating NaNs. This oracle certifies source
interpretation for those constants, not Hailo numerical behavior.

The external archive is SHA-256
`c36f8ae9c99cf933839aff890db7af1ae73baf8d2b34d6cfb7b4c4b030b1be9e`.
Its root MIT license was read before use. Source and reference binary stay
outside Git. Build only ggml-base with CPU backend, OpenMP, examples and tests
disabled; no dependencies are fetched. Installed GCC/glibc runtime licenses
were inspected and dependency facts recorded before reference execution.
`reference-provenance.json` records options, revision, runtime licenses and
library hash. Production does not import/link ggml. No external decoder
implementation is copied or translated into production or tests.

The unchanged floating decoder regression also passes six methods/64 calls,
including all 131,072 F16/BF16 patterns. Evidence:
`docs/evidence/source-q4k-constants-2026-10-20/`. These targeted checks are not
a full hosted-CI certification.

## Remaining work

The inspector reports device_weight_format, source_fingerprint_verified and
execution_tested false. A returned window observes one mapping, with no promise
against concurrent file mutation or later reopening of different bytes. Graph
binding/identity, other quantized formats, source permutations, actual device
precision/weight layout, physical resource placement, operation CCWs,
upload/activation and numerical hardware proof remain required. No model,
layer or attention forward runs on the host, and no device is opened here.
Next, continue bounded public interface study of original program delivery and
activation so source conversion advances alongside the real backend gap.
