# Tests Domain: Verification & Invariant Rites

## Domain Overview
The `tests` domain holds the master test runner and domain-specific verification scripts.

- **`run_all.mojo`:** Master orchestrator running all 8 unit tests across compute, GGUF, and tokenizer.
- **`test_compute.mojo`:** Unit tests for GEMM, Flash Attention-2, SiLU, GeGLU, and Q4_K_M dequantization.
- **`test_gguf.mojo`:** Unit tests for GGUFSeer mmap loading and `GGMLType` constants.
- **`test_tokenizer.mojo`:** Unit tests for `RuneWeaver` token encoding/decoding.

## How to Run
```bash
cd ~/AntiGravity_Viking_Longhall/Project_Aesir/aesir_engine
export PATH="$HOME/.pixi/bin:$PATH"
pixi run mojo run tests/run_all.mojo
```
