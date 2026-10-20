# Native ordinary safetensors source inventory

Date: 2026-10-20. Contract: `TASK_hailo10h_safetensors_inventory.md`.
Canonical format facts and reader audit were published before code in
`HAILO10H_SAFETENSORS_SOURCE_FACTS.md`.

## Connected source boundary

`smidr/safetensors_inventory.mojo` reuses the existing project reader in
`armvegr/safetensors.mojo`. It returns copied tensor names, source dtype IDs,
all shape axes, checked element counts and actual file spans, plus source size,
data origin and owned metadata. It closes the source mapping before returning.
This is an ordinary-file metadata path, with no model registry/allowlist,
conversion workflow or device call. Architecture is not present in the weight
file and is not invented by the adapter. The GGUF matrix binding type is not
misused for arbitrary-rank/scalar/empty tensors.

The existing parser now uses checked length-aware UTF-8 strings, preserves
escaped NUL, validates JSON integers/numbers/escapes and duplicate keys, requires
all descriptor fields, validates metadata string maps and rejects trailing
commas. Shape multiplication checks before multiplying, with empty axes handled
as mathematical zero. Relative extents are checked before adding the data
origin. Nonoverlapping spans must cover the entire payload; empty spans must
sit at tensor boundaries. No tensor data value is read or converted by this
metadata path. Existing static conversion bodies and CPU inference guards are
preserved; the loader's value method gains a closed-owner refusal.

## Bounds and ownership

The new adapter requires explicit positive header-byte, tensor-count, rank,
descriptor-work and depth bounds. Header limits precede JSON parsing; tensor/
rank limits precede container growth. The work policy bounds4*n*n for n tensor
descriptors before appending, conservatively covering descriptor pair checks;
header size separately bounds text work. It is not a wall-clock deadline or
physical resource-discovery result. Recursive unknown-field skipping currently
has a maximum host stack policy64; this is an implementation guard, not a model
or hardware capability limit. Deeper extension JSON needs subsequent iterative
parser work if required. Standard metadata values are strings, not nested JSON.

Default `SafetensorsLoader.open(path)` stays available with default policies:
100000000 header bytes,100000 tensor count,64 rank,100000000 work and64 depth.
The work bound can bind before the count bound. `element_count` now raises on
invalid/overflowed nonempty products. `close` clears descriptors, metadata and
extents and denies subsequent mapped range access. The adapter copies before
closing and cleans up parsing/snapshot failures. It does not certify immutable
file identity or protect a mapping against another process truncating/replacing
its backing file; that remains a separate source-ownership task. Cleanup syscall
failure injection is not claimed by the focused normal/error-path evidence.

## Verification

**Eleven methods/219 native calls pass:109 accepted,110 refused.**
The final metadata diagnostic and API checker build without warnings on Mojo
1.1.0. An unchanged legacy H043 header-only checker also builds and passes five
ordinary fixture calls without its `load` flag. Its compilation retains one
pre-existing unused-initialization warning in the static BF16 conversion body;
that conversion is not executed by these checks.

Independent synthetic struct/JSON fixtures and isolated Apache-2.0 safetensors
0.7.0 format oracle compare names/dtypes/shapes/byte widths. Exact spans,
metadata and elements are checked independently. Coverage includes all three
current floating dtypes, Unicode/NUL/escapes, empty names/maps/files/tensors,
scalars, arbitrary axes, huge zero-axis shapes,60 seeded tensor collections,
strict JSON/UTF-8/duplicates, all policy boundaries, product/byte/offset overflow,
overlap/holes/trailing data and empty-boundary behavior. Unknown-field skipping
checks valid JSON values, invalid numeric grammar and exact nesting bounds.

Three API processes run20 invalid-open → valid-open → already-open-refusal →
close/reclose cycles each, validate cleared state and closed range refusal, and
verify copied snapshots/shapes/metadata remain independent. A syscall trace
matches every fixture open with a close in the traced cycle case. The source
trace confirms read-only, nonblocking open and read-only private mapping; no
model/device write, ioctl, external format runtime, HailoRT/CUDA/ggml/Torch call
occurs. FIFO admission refuses without blocking. Input bytes remain unchanged.
The initial failing assertion expected an empty metadata map to reject; the
format permits it. Only that test expectation was corrected. All initial/final
results and build evidence remain preserved in
`docs/evidence/safetensors-inventory-2026-10-20/`.

Reproduce from the repository root, providing an installed strace explicitly:

```sh
MODULAR_CACHE_DIR=../mojo-cache mojo build -I . -I aesir_engine smidr/tools/safetensors_inventory.mojo -o ../safetensors-inventory
MODULAR_CACHE_DIR=../mojo-cache mojo build -I . -I aesir_engine tests/hailo_safetensors_inventory_api.mojo -o ../safetensors-inventory-api
MODULAR_CACHE_DIR=../mojo-cache mojo build -I . -I aesir_engine tests/h043_st_check.mojo -o ../safetensors-header-regression
python3 tests/test_hailo_safetensors_inventory.py --binary ../safetensors-inventory --api ../safetensors-inventory-api --legacy ../safetensors-header-regression --strace "$AESIR_STRACE" --evidence ../safetensors-inventory-recheck
```

## Remaining broad-model work

Initial inventory dtype coverage is F16/BF16/F32 from the existing reader.
Other dtype/quantization formats, shard/index/config interpretation, architecture
semantics and actual weight-window consumption remain implementation work, not
permanent model restrictions. Continue static source windows under
`TASK_hailo10h_safetensors_constants.md` alongside actual numerical CCW,
precision/packing/placement/program upload/activation/result/cleanup work.
Neither this inventory nor the format oracle proves source-model execution.
No outside compiler, specially compiled user model or host LLM forward is
introduced; the owner's full broad target and Hailo-only LLM execution remain.
