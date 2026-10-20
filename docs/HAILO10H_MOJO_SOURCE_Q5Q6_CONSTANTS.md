# Original Q5_K and Q6_K source components

Date: 2026-10-20. Contract: `TASK_hailo10h_q5q6_source_constants.md`.
Field schema/provenance was published first in `HAILO10H_Q5Q6_SOURCE_LAYOUT.md`
at4f65e40. Original `smidr/source_q5q6_constants.mojo` interprets the published
fields through Aesir's existing bit-field and binary16 representation helpers.
No external decoder implementation is copied/translated or linked in production.

`read_q5k_constants` returns owned affine components with raw d/dmin words,
exact binary32 representation bits, unsigned0..31 q and unsigned0..63 scale/min
factors. `read_q6k_constants` returns raw d, exact binary32 bits, centered q
(-32..31) and signed scale (-128..127). No floating arithmetic is evaluated in
production. NaN payloads, infinities, signed zero and subnormal scale patterns
remain representation data, never device numerical admission.

Both APIs borrow a live read-only PackedGGUF owner and require explicit
first/count/positive host element bound. Source kind, positive shape, complete
packed row, exact tensor/file/data extent and checked window range are validated
before allocation/read. Path wrappers destroy their mapping before returning
owned `Q5KConstantWindow` / `Q6KConstantWindow`. The inspector's4096-element
output cap is a host diagnostic bound, not a model support restriction.

## Acceptance

Warning-free Mojo1.1.0 builds and independent static checks:

```sh
MODULAR_CACHE_DIR=../mojo-cache mojo build -I . -I aesir_engine smidr/tools/source_q5q6_constants.mojo -o ../source-q5q6-constants
MODULAR_CACHE_DIR=../mojo-cache mojo build -I . -I aesir_engine tests/hailo_source_q5q6_api.mojo -o ../source-q5q6-api
python3 tests/test_hailo_source_q5q6_constants.py --binary ../source-q5q6-constants --api-binary ../source-q5q6-api --reference-library ../ggml-format-study/build/src/libggml-base.so --strace /usr/bin/strace --evidence docs/evidence/source-q5q6-constants-2026-10-20
```

Seven methods/88 native calls pass (40 accepted,48 refused), with94416 exact
component comparisons. Q5 fixtures span every q0..31 and each six-bit factor
in every group. Q6 fixtures span every centered quant and every signed scale
in all16 groups. Special scale words, group/block/row crossings, full bounded
windows and final file bytes are checked. Invalid kinds, missing/truncated
sources, closed owners, changed source extents/shapes, overflow, invalid bounds
and indices refuse without success output. Owned windows survive closing and
destroying source mappings; returned arrays do not alias other windows.
Read-only traces preserve source hashes and show no device/ioctl/model runtime.

The frozen MIT ggml-base reference library's expected hash is checked before
loading. Only dequantize_row_q5_K and dequantize_row_q6_K evaluate isolated
synthetic static constants; no context/graph/backend/model/forward API runs.
All4096 constants for each kind agree in exact binary32 bits after explicit
F32 reconstruction from returned fields. Build/CPU-backend-disabled/dependency
provenance is retained from the prior Q4 static study; no external source or
binary is shipped. Evidence: `docs/evidence/source-q5q6-constants-2026-10-20/`.

## Remaining device compiler gaps

These readers implement source representation, not selected Hailo weight
precision/packing, immutable source identity, physical placement, executable
numerical CCWs or model execution. Public numerical encoding and original-
program leads are next under `TASK_hailo10h_numerical_encoding_sources.md`.
No DFC/outside compiler or specially compiled model becomes a prerequisite.
Actual architecture/format gaps remain implementation work toward broad
ordinary-model support; only the owner can change that target.
