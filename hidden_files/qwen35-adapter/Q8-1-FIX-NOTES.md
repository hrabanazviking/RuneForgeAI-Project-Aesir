# Q8-1 fix — Q8_1 block size arbitration and repair (2026-11-14)

Worker slice on worktree /home/volmarr/aesir-q8-1, branch yrsa/q8-1-fix,
base fd73cad9. Settles QC-0 unknown U-QC2.

## Arbitration — ggml block_q8_1 is 36 bytes; the COMPUTE side was wrong

Primary source on this box, ~/llama.cpp-build/ggml/src/ggml-common.h:258-269:

    #define QK8_1 32
    typedef struct {
        union { struct { ggml_half d; ggml_half s; }; ggml_half2 ds; };
        int8_t qs[QK8_1];
    } block_q8_1;
    static_assert(sizeof(block_q8_1) == 2*sizeof(ggml_half) + QK8_1);

i.e. f16 d @0, f16 s @2 (s = d * sum(qs), auxiliary), int8 qs @4..36,
sizeof == 36. ggml.c type traits for GGML_TYPE_Q8_1: blck_size = QK8_1
(32), type_size = sizeof(block_q8_1) = 36.

QC-0's expectation (f32 d @0 + f32 sum @4 = 40 B) is REFUTED: no such
layout exists in ggml. The loader priced 36 B and was CORRECT; the
compute readers walked a fictitious 40-byte f32/f32 layout and were
the defect — every Q8_1 dequant/GEMM read its scale from the wrong
bytes and its quants 4 bytes late, and multi-block tensors drifted
4 B further per block.

## Sites audited (grep Q8_1 / GGML type 9 across aesir_engine/)

- loader/gguf.mojo _tensor_byte_size (type 9): 36 B — CORRECT, untouched.
- loader/mmproj.mojo _block_geometry (kind 9): (32, 36) — CORRECT, untouched.
- loader/packed_gguf.mojo: NO kind-9 geometry — PackedGGUF REFUSES
  Q8_1 outright (32-col rows: "K-quant row is not block aligned";
  256-aligned rows: "unsupported tensor type 9"). Honest state, kept.
- loader/quantization.mojo: strict block-size lookups cover only
  Q4_K_M/Q4_0/Q4_1/Q8_0 — Q8_1 raises "unknown quantization format".
  Refusal, kept as-is.
- core/model_registry.mojo: no adapter admits Q8_1 (qwen35 policy is
  Q8_0-only, census-proven). Refusal, kept as-is.
- core/extreme_quantization.mojo: no Q8_1 handling. Absent, kept.
- core/compute.mojo dequantize_q8_1: 40 B f32/f32 — WRONG, FIXED.
- core/compute.mojo gemm_q8_1: 40 B f32/f32 — WRONG, FIXED.
- core/quantization_autotuner.mojo format info: (32, 40) — WRONG, FIXED to 36.
- core/mimir_well.mojo format comment: "F32 scale + auxiliary sum" —
  WRONG description, FIXED to the f16 d + f16 s layout.
- tests/test_q8_fp8_quantization.mojo Q8_1 parity case: encoded the
  fictitious 40 B layout — FIXED (deliberate banked-expectation
  update, cited in the test): 36 B, f16 d=0.5 @0, f16 s=-8 @2,
  qs @4; expected matvec result unchanged (-8).

## Fix

compute.mojo: dequantize_q8_1 and gemm_q8_1 now walk 36-byte blocks,
scale = f16 d @0, quants @4..36, with comments citing ggml-common.h
and this slice. autotuner block_bytes 40 -> 36. mimir_well comment
corrected. No loader change (it was right).

## Proof (logs in this folder)

- test_q8_1_fix_q8_1 (new, aesir_engine/tests/test_q8_1_fix_q8_1.mojo;
  runner scripts build-q8-1.sh / run-q8-1-tests.sh): ALL PASS —
  (1) dequantize_q8_1 unit on the 36 B layout; (2) byte-size units
  agree at 36 B/block across loader _tensor_byte_size, mmproj
  mmproj_tensor_byte_count, autotuner format info (32/64/320 elements
  -> 36/72/360 B); (3) synthetic GGUF with a Q8_1 tensor followed by
  an F32 tensor: both map, downstream offset delta = 64 (36 B padded
  to 32-alignment), downstream values exactly [1.5, -2.25, 3.0, 42.0];
  (4) PackedGGUF refuses the same file outright. Log: q8-1-test.log.
- Q8/FP8 parity runner (new wrapper run_q8_fp8_q8_1.mojo around the
  existing module, which has no main): ALL PASS incl. the corrected
  raw Q8_1 matvec. Log: q8-1-q8fp8.log.
- Regressions: Q35-1 loader test ALL PASS (q8-1-regress-q35-1.log);
  Q35-2 registry test ALL PASS (q8-1-regress-q35-2.log); full engine
  compile exit 0 (q8-1-build.log, ENGINE_BUILD_EXIT=0).
- gguf metadata regression (test_gguf_metadata_types): exit 1 ONLY at
  the known pre-existing gguf.tensor_directory_interface failure
  (rank-3 probe expects "one or two dimensions", gets the
  missing-required-tensor error; documented since the HS line,
  unchanged by this slice, not chased). Log: q8-1-regress-meta.log.

## Resulting Q8_1 support state

GGUFSeer loads/maps Q8_1 tensors at correct offsets; compute
dequant + GEMM read the true 36 B layout; autotuner prices it
correctly. PackedGGUF refuses Q8_1; loader/quantization strict
lookups refuse it; no model-registry adapter admits it. End-to-end
Q8_1 model execution remains unadmitted by policy, now on correct
arithmetic rather than a size conflict.

## Out-of-scope observation (recorded, not chased)

In the new test binary, direct pointer reads of a mapped Q8_1
tensor's bytes (f16/UInt8 loads through the RuneTensor data pointer
or repeated mmap_ptr loads in check position) segfaulted
intermittently, migrating with code layout, while the same bytes
read stably through print arguments and the loader's own accessors,
and pool-pointer reads are stable. The proof therefore uses the
metadata-test baseline pattern (offset dict + F32 pool-copy values).
Worth a look if a future slice reads Q8_1 tensors directly in tests;
production GEMM/dequant paths on pool and mmap pointers pass their
own suites (Q8/FP8 parity, Q35 forward lines).

## Handoff to QC-1

QC-1's writer must emit ggml block_q8_1 exactly as the readers now
walk it: 36-byte blocks, f16 d @0, f16 s = d*sum(qs) @2, int8 qs @4.
