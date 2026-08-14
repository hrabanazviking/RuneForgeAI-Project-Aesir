# Bug Report: SIMD Vector Loops Out-of-Bounds on Unaligned Dimension Tails

**Bug ID**: 0009
**Title**: `silu`, `geglu`, and `rmsnorm` SIMD loops load/store past buffer size when dimensions are not multiples of SIMD width
**Component**: `core/compute.mojo`
**Status**: Resolved

## Description
In `core/compute.mojo`:
- `silu`: `for i in range(0, T.size, simd_w_f16): var x = T.data.unsafe_load[width=simd_w_f16](i)`
- `geglu`: `for i in range(0, half_size, simd_w_f16): ...`
- `rmsnorm`: `for c in range(0, hidden_dim, simd_w_f16): ...`

When `T.size`, `half_size`, or `hidden_dim` was not an exact integer multiple of `simd_w_f16` (32 elements = 64 bytes), the final iteration read and wrote memory past the allocation boundary of the `RuneTensor`.

## Recommendation for the Forge Worker
Add scalar tail-handling loops after the vectorized main loop (e.g. `for i in range(vector_end, total_size): scalar_op(...)`), or mask the final SIMD load/store when processing unaligned dimensions.

## Mythic Engineering Rite Completed
Resolved by Forge Worker: Added scalar tail loops following the SIMD loops in `silu`, `geglu`, `rmsnorm`, `gemm_f16`, and `flash_attention_2` in `core/compute.mojo`. Unaligned tail elements are processed elementwise to prevent out-of-bounds loads/stores. Added unaligned shape test coverage in `tests/test_compute.mojo`.

