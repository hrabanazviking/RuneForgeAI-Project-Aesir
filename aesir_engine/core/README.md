# Core Domain: The Forge of Nidavellir & The Waters of Mímisbrunnr

## Domain Overview
The `core` domain houses the mathematical engine room and memory management layer of Project Aesir. The legacy host primitives remain useful for the CPU slice; the native Gemma and Llama 3 CUDA sessions are separate, bounded runtime paths.

- **`mimir_well.mojo` (The Waters of Mímisbrunnr):** Manages the CPU workspace and lightweight borrowed tensor descriptors. Generic NPU/GPU buffers remain host descriptors.
- **`PagedKVCache` in `mimir_well.mojo`:** Provides a bounded multi-sequence host page table and physical K/V pool with checked release and reuse. Model attention sessions do not use it yet.
- **`gemma4_cuda.mojo` / `gemma4_kernels.mojo`:** Own the supported CUDA profile's device buffers, packed weights, KV cache, and transformer kernels for dense text-only Gemma 4 E4B Q4_K_M.
- **`llama3_cuda.mojo` / `llama3_kernels.mojo`:** Own dense Llama 3 8B Stheno CUDA inference, F16 KV, adjacent-pair RoPE, SiLU and scaled GQA. Reuse packed matvec/norm primitives; cap output by remaining 8K context without truncating history.
- **`compute.mojo` (The Forge of Nidavellir):** Executes host Mojo SIMD primitives. Its generic NPU/GPU gateways remain bounded and do not replace the specialized Gemma CUDA session.
- **`quantization_autotuner.mojo`:** Owns opt-in Linux host measurements between real packed and dequantized GEMM strategies, validates numerical agreement, and caches winners by caller device key and exact shape. It does not silently change model execution.
- **`posix_process.mojo`:** Executes bounded argv vectors without a shell and
  captures bounded stdout for native infrastructure such as exact-inode model
  blob hashing.

## Key Invariants
- `native_hardware.mojo`, `inference_memory.mojo` and `runtime_plan.mojo` own
  Linux resource observations, checked native model memory counts and CUDA
  device selection. The facade exports these; CLI only formats their results.
- Persistent tensor workspaces are carved from `MimirWell`; lists, strings, and
  temporary values still allocate elsewhere in generation.
- Compute loops operate directly on `RuneTensor` pointers, but their complete
  safety, numerical breadth, and allocation behavior remain hardening work.
- SIMD operations execute directly on `RuneTensor` data pointers via `unsafe_load` / `unsafe_store`.

## Optional bounded runtime-group32-column staging

Separate core/packed_turing_loop.mojo imports original accumulation/target/span
helpers and preserves original packed core/quantization modules verbatim. Internal
runtime-group0..7/lane0..31 decode matches original equations; kind12/13/14 and
rows64/128/batch4/8/16/32/precision0 remain static. Shared32 width/both barriers/
chronological F32 public MMA/guarded cells stay; no global workspace or production
selection. Final loop_rows=0 harness dispatch is exclusive with cached/large/narrow
flags. Explicit loop metadata requires full original64 F32 bits, unchanged native/
independent/guard/840 rotated finite timing gates. Both numeric configs pass; all56
original64 comparisons lose.22 portable contracts/master190/one skip. Read ../../docs/NATIVE_TURING_LOOP_STAGING.md;
no register/occupancy/cause/provider claim follows.

## Optional paired FFN primitive

Separate packed_turing_pair owns pure two-matrix admission and an opt-in paired
64-row-per-tensor / 32-column kernel. Same-kind12/13/14 and batch4/8/16/32 only;
weight/output aliases refuse before enqueue. Original quant/MMA equations and
all initialized shared tails/barriers remain; no global workspace or selection.
Real Q4/Q4 gate/up passes 983040 complete values per owner, original F32 bits,
600 independent dots, 6720 guards, 144 synthetic pairs and 12 span refusals.
All120 rotated timings remain. Batch4 beats staged but loses native; batch32
loses staged, so no candidate selection. Ten adversarial contracts/master190
passes/one skip. Failed guard-formula checker report is retained; corrected
validation uses unchanged GPU data and a new exclusive report. Read ../../docs/NATIVE_TURING_PAIRED_FFN.md.
Actual model activation/full-model/runtime/provider gates remain separate.
