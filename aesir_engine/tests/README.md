# Tests Domain: Verification & Invariant Rites

## Domain Overview
The `tests` domain holds the master test runner and domain-specific verification scripts.

- **`run_all.mojo`:** Master orchestrator for the repository's synthetic and unit proving domains.
- **`test_compute.mojo`:** Unit tests for GEMM, Flash Attention-2, SiLU, GeGLU, and Q4_K_M dequantization.
- **`test_gguf.mojo`:** Unit tests for malformed GGUF rejection and `GGMLType` constants.
- **`test_tokenizer.mojo`:** Unit tests for `RuneWeaver` token encoding/decoding.
- **`test_real_gguf.mojo`:** Opt-in external-fixture proof for metadata,
  zero-copy F16 mapping, F32 normalization conversion, tokenizer parity, and
  first-token inference parity. It is intentionally not part of `run_all.mojo`
  because model weights are not committed.

## How to Run
```bash
cd aesir_engine
pixi run mojo run tests/run_all.mojo
```

Run the real-model proof with the pinned fixture described in
`TASK_real_gguf_vertical_slice.md`:

```bash
pixi run mojo run tests/test_real_gguf.mojo /path/to/stories260K.F16.gguf
```
