# RuneTensor 2D layout baseline — 2026-10-10

## Scope and identity

AES500-072 captures the existing two-dimensional descriptor and indexing
behavior before any layout implementation change.

- Baseline revision: `e09a53b860410753b3fa2abfd5d61bd397fce62b`
- Toolchain: Mojo 1.0.0 (`ed45d567`), Pixi environment, Linux x86_64.
- No model or GPU is required for these CPU-only cases.

## Commands and results

```sh
pixi run mojo run -I aesir_engine aesir_engine/tests/test_rune_tensor_layout.mojo
pixi run mojo run -I aesir_engine aesir_engine/tests/test_kv_cache.mojo
pixi run mojo run -I aesir_engine aesir_engine/tests/test_dense_buffers.mojo
```

Observed output:

```text
PASS: RuneTensor 3x4 contiguous row-major indexing baseline
--- Testing KVCache (The Waters of Mímisbrunnr) ---
--- Testing KVCache Ring-Buffer Rotation ---
KVCache ring-buffer rotation: PASS
PagedKVCache multi-sequence allocation, exhaustion, and reuse: PASS
KVCache instantiation: PASS
KVCache token append: PASS
MimirWell memory exhaustion error: PASS
KVCache slice bounds: PASS
KVCache state accumulation: PASS
test_kv_cache: PASS
PASS: compact tile spans, byte counts, bounds, defaults and overflow
```

The dedicated layout baseline allocates a checked 3x4 `RuneTensor`, writes
unique values through raw `(row, column)` indexing, reads them through checked
indexing, and rejects a negative row and endpoint column. The observed mapping
is contiguous row-major (`row * cols + col`). This proves the test's CPU-local
behavior only; it does not establish backing allocation-size proof, pointer
provenance, arbitrary strides, or memory safety for raw invalid coordinates.

## Source hashes

```text
0d1ac4f5fac973f84dd86275fc77205b982f4fcab1b6aae5537c8d10b520d614  aesir_engine/core/mimir_well.mojo
0d4019e202cd7d83e0a0913b52466aeb100186a2e522e0dccd506a76599d5993  aesir_engine/core/INTERFACE.md
7b02c6032b442e01bf2da3a1e0a93e8510626cf81f1326a631448eacc7743b94  aesir_engine/tests/test_rune_tensor_layout.mojo
1c626a072503be4eecc1308d35aa29694a3e599571163e3bcdfef3e3c682cc7d  TASK_rune_tensor_2d_layout.md
```
