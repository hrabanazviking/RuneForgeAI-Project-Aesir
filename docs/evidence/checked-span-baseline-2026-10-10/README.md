# Checked span construction baseline — 2026-10-10

## Scope

Read-only pre-implementation inventory for AES500-062. The target contract is
`TASK_checked_span_construction.md`. No shared span helper or caller migration
is present in this baseline.

## Source identity

- Repository revision: `f14352ca47d6c7f89c1681d47adc0ecb2fd9e4bb`
- Toolchain: Mojo 1.0.0 (`ed45d567`) from the Pixi environment.
- Platform: Linux x86_64 Pixi environment.

## Current focused behavior

The following existing owner tests pass under the pinned toolchain:

- `pixi run mojo run -I aesir_engine aesir_engine/tests/test_kv_cache.mojo`
- `pixi run mojo run -I aesir_engine aesir_engine/tests/test_dense_buffers.mojo`
- `pixi run mojo run -I aesir_engine aesir_engine/tests/test_turing_fixture_plan.mojo`

Directly invoking a test file without `-I aesir_engine` fails module resolution
for imports such as `loader.gguf`; the include path is required for these
focused commands. The output is preserved below.

## Current implementation inventory

- `RuneTensor.checked()` validates positive dimensions, detects wrapped shape
  products, and rejects null/address-1 pointers. It has no backing allocation
  capacity input.
- `KVCache` and `PagedKVCache` retain owner-specific shape/capacity checks.
- `dense_buffers.mojo` has local checked arithmetic for compact scratch spans.
- `fused_causal_attention.mojo`, packed matrix paths, and fixture-plan code
  retain independent span rules.
- This baseline does not assert these existing checks share identical
  semantics, and does not establish allocator ownership, pointer validity,
  lifetime, or sanitizer coverage.

## Source hashes

```text
0d1ac4f5fac973f84dd86275fc77205b982f4fcab1b6aae5537c8d10b520d614  aesir_engine/core/mimir_well.mojo
7bebf18d05b4e6a0466e7d27b9fcce396eca402f32cc324095192ebd51bdcce4  aesir_engine/core/dense_buffers.mojo
9764c988433d7c58527ca6b77f367f2ae2dce8cc3c50455a97438ce0183d6dc3  aesir_engine/core/fused_causal_attention.mojo
e40f5128ced8840f77b4526dbfaaf878fe04acf3ee16216ac01f901a1d522a9c  aesir_engine/core/packed_matrix.mojo
eda81b909789e9a55775cb130ef678f81152ae5c9b275e6911e375a636cf5dac  TASK_checked_span_construction.md
```

## Baseline command output

```text
Mojo 1.0.0 (ed45d567)
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
PASS: strict fixture identity, all layout fields, spans, padding and headroom
```

The failed invocation without an include path is recorded as a tool invocation
requirement, not as a source failure.
