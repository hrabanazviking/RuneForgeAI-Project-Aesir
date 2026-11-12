# A-046 — Quant Census (Wave 6 opener)

Every quant type the engine claims, enumerated with a load + short-inference
smoke on the Z13 (purpleraider, AMD Ryzen AI Max / Strix Halo, CPU path).
Acceptance: a census table with a status per format — no format unaccounted
for. Rows are cited as A-046:C-001 … C-038 by later Wave 6/7 slices.

## Claim surface (what "the engine claims" means, from source)

Two enumerations in the banked tree at base 40ce2d88 define the claim:

1. loader/gguf.mojo, struct GGMLType — 26 GGML tensor types the loader
   enumerates: F32, F16, Q4_0, Q4_1, Q5_0, Q5_1, Q8_0, Q8_1, Q2_K, Q3_K,
   Q4_K, Q5_K, Q6_K, Q8_K, IQ2_XXS, IQ2_XS, IQ3_XXS, IQ1_S, IQ4_NL, IQ3_S,
   IQ2_S, IQ4_XS, IQ1_M, TQ1_0, TQ2_0, BF16. Its to_compressed_format map
   admits 22 of them (all except the dense F32/F16/BF16, handled as plain
   tensors, and Q8_K, which raises "unsupported GGML tensor type 15").
2. core/mimir_well.mojo, struct CompressedFormatType — 34 distinct values
   (0..33) with name() strings: the GGUF families above (with K-quant file
   recipes split out: Q3_K_S/M/L, Q4_K_S/M, Q5_K_S/M) plus GPTQ_4BIT,
   GPTQ_8BIT, AWQ_4BIT, EXL2_VARBIT, HQQ, SMOOTHQUANT_INT8, FP8_E4M3,
   FP8_E5M2. (Value 25 carries two names, TERNARY_155BIT and its canonical
   GGML name TQ1_0 — one format, one row.)

Union, deduplicated by format name: 38 formats = 34 CompressedFormatType
values + F32 + F16 + BF16 + Q8_K. That is the census denominator.

## Method

- Fixture A (real model): the pinned stories260K.F16.gguf, sha256
  57a81ed1c8b032ba29319eae80c3e568dbb5a16ce665a09da1a0efe2e4eb69e3,
  quantized with llama.cpp llama-quantize into every file_type recipe.
  On this geometry (288-wide rows) llama.cpp falls back for most tensors
  (36 of 48 tensors in K/IQ recipes), so these files smoke the loader and
  the fallback tensor mix, NOT genuine K/IQ tensors. Their greedy output
  is graded against the pinned F16 oracle (first 16 ids) — drift on a
  260K-param toy at low bit-width is quantization error, recorded as a
  match count, not hidden.
- Fixture B (genuine tensors): synth512, a synthetic 2-layer llama GGUF
  written for this census (embedding 512, ffn 1024, heads 8, vocab 512
  with the stories tokenizer, seeded random weights, seed 42). All rows
  are 512/1024 wide (divisible by 256), so llama-quantize — with a
  llama-imatrix generated importance matrix for the IQ1/IQ2 family —
  places genuine target-type tensors in every file. Tensor-type presence
  per file was verified by parsing each GGUF header (histograms in the
  ledger), never assumed from the file name. Weights are random, so the
  smoke grades load + forward + greedy decode completion with all
  generated ids in vocab range; quality grading for these formats lives
  in the E-MASTER known-value / SIMD-parity oracle cases (same gate run)
  and, for IQ, in the coherence discipline of law 3 — never token
  exactness against a random-weight model.
- Smoke harness: aesir_engine/tests/bench_quant_census_a046.mojo —
  GGUFSeer load, canonical raw prompt "One day, Timmy went to" (8 tokens),
  prefill + 16 greedy decode tokens via forward_pass, CPU only. No
  accelerator execution is claimed anywhere in this census.
- Non-GGUF formats (GPTQ/AWQ/EXL2/HQQ/SmoothQuant/FP8) have no GGUF
  file_type and no GGUF load path; their claim rests on dequantization
  implementations (core/external_quantization.mojo, loader/exl2.mojo)
  graded by E-MASTER oracle cases in the same gate run. Status
  DEQUANT_ONLY says exactly that.

## Census table

| ID | Format | Claim source | Status | Evidence |
|----|--------|--------------|--------|----------|
| C-001 | F32 | GGMLType 0 | SMOKE_PASS | synth512.F32 + stories F32, oracle 16/16 |
| C-002 | F16 | GGMLType 1 | SMOKE_PASS | pinned fixture, oracle 16/16 (A-004/A-030 line) |
| C-003 | BF16 | GGMLType 30 | SMOKE_PASS | synth512.BF16 genuine BF16 tensors; stories BF16 oracle 16/16 |
| C-004 | Q4_0 | GGMLType 2 / CFT 4 | SMOKE_PASS | synth genuine Q4_0 x15 tensors; stories oracle 10/16 |
| C-005 | Q4_1 | GGMLType 3 / CFT 5 | SMOKE_PASS | synth genuine Q4_1 x15; stories oracle 12/16 |
| C-006 | Q5_0 | GGMLType 6 / CFT 8 | SMOKE_PASS | synth genuine Q5_0 x15; stories oracle 15/16 |
| C-007 | Q5_1 | GGMLType 7 / CFT 9 | SMOKE_PASS | synth genuine Q5_1 x15; stories oracle 16/16 |
| C-008 | Q8_0 | GGMLType 8 / CFT 13 | SMOKE_PASS | synth genuine Q8_0 x16; stories oracle 16/16 |
| C-009 | Q8_1 | GGMLType 9 / CFT 14 | DEQUANT_ONLY | no GGUF file_type recipe exists (activation-side format); fused Q8_1 parity case in E-MASTER |
| C-010 | Q2_K | GGMLType 10 / CFT 0 | SMOKE_PASS | synth genuine Q2_K tensors; stories oracle 10/16 |
| C-011 | Q3_K_S | CFT 1 (tensor Q3_K) | SMOKE_PASS | synth file_type 11, genuine Q3_K x15; stories oracle 10/16 |
| C-012 | Q3_K_M | CFT 2 (tensor Q3_K) | SMOKE_PASS | synth file_type 12, genuine Q3_K/Q4_K/Q5_K mix; stories oracle 4/16 (heaviest toy-model drift, recorded) |
| C-013 | Q3_K_L | CFT 3 (tensor Q3_K) | SMOKE_PASS | synth file_type 13; stories oracle 12/16 |
| C-014 | Q4_K_S | CFT 6 (tensor Q4_K) | SMOKE_PASS | synth genuine Q4_K x13; stories oracle 15/16 |
| C-015 | Q4_K_M | CFT 7 (tensor Q4_K) | SMOKE_PASS | synth genuine Q4_K x13; stories oracle 16/16 |
| C-016 | Q5_K_S | CFT 10 (tensor Q5_K) | SMOKE_PASS | synth genuine Q5_K x15; stories oracle 16/16 |
| C-017 | Q5_K_M | CFT 11 (tensor Q5_K) | SMOKE_PASS | synth genuine Q5_K x13; stories oracle 16/16 |
| C-018 | Q6_K | GGMLType 14 / CFT 12 | SMOKE_PASS | synth genuine Q6_K x16; stories oracle 16/16 |
| C-019 | Q8_K | GGMLType 15 only | REJECTED_AT_LOAD | no CompressedFormatType value, no weight dequant path; loader map raises on type 15; llama-quantize cannot store it as a weight type either (aborts) — an activation-side ggml type, not a model format |
| C-020 | IQ1_S | GGMLType 19 / CFT 23 | SMOKE_PASS* | synth genuine IQ1_S x10, smoke PASS; stories recipe file FAILS — see bug B1 |
| C-021 | IQ1_M | GGMLType 29 / CFT 32 | SMOKE_PASS* | synth genuine IQ1_M x10; stories file FAILS — B1 |
| C-022 | IQ2_XXS | GGMLType 16 / CFT 24 | SMOKE_PASS* | synth genuine IQ2_XXS x12; stories file FAILS — B1 |
| C-023 | IQ2_XS | GGMLType 17 / CFT 28 | SMOKE_PASS* | synth genuine IQ2_XS x12; stories file FAILS — B1 |
| C-024 | IQ2_S | GGMLType 22 / CFT 26 | SMOKE_PASS* | synth file (IQ2_XS matrices + IQ3_S embd per llama.cpp recipe) + IQ2_S known-value/SIMD cases in E-MASTER; stories file FAILS — B1 |
| C-025 | IQ3_XXS | GGMLType 18 / CFT 29 | SMOKE_PASS* | synth genuine IQ3_XXS x8 tensors, smoke PASS; stories file FAILS — B1 |
| C-026 | IQ3_S | GGMLType 21 / CFT 27 | SMOKE_PASS* | synth genuine IQ3_S x15; stories file FAILS — B1 |
| C-027 | IQ4_NL | GGMLType 20 / CFT 30 | SMOKE_PASS* | synth genuine IQ4_NL x15 at K=512; REJECTED at K=288 — bug B1 is in this row's GEMM |
| C-028 | IQ4_XS | GGMLType 23 / CFT 31 | SMOKE_PASS* | synth genuine IQ4_XS x15; stories file FAILS — B1 |
| C-029 | TQ1_0 | GGMLType 34 / CFT 25 | SMOKE_PASS | synth genuine TQ1_0 x14; stories oracle 9/16 |
| C-030 | TQ2_0 | GGMLType 35 / CFT 33 | SMOKE_PASS | synth genuine TQ2_0 x14; stories oracle 9/16 |
| C-031 | GPTQ_4BIT | CFT 15 | DEQUANT_ONLY | core/external_quantization.mojo dequantize_gptq_4bit_matrix + E-MASTER gptq/awq cases; no GGUF path |
| C-032 | GPTQ_8BIT | CFT 16 | DEQUANT_ONLY | dequantize_gptq_8bit_matrix + E-MASTER cases; no GGUF path |
| C-033 | AWQ_4BIT | CFT 17 | DEQUANT_ONLY | dequantize_awq_4bit_matrix + E-MASTER cases; no GGUF path |
| C-034 | EXL2_VARBIT | CFT 18 | DEQUANT_ONLY | loader/exl2.mojo seer + dequantize_exl2_matrix + E-MASTER exl2 cases; own format, no GGUF path |
| C-035 | HQQ | CFT 19 | DEQUANT_ONLY | dequantize_hqq_4bit_axis1 + E-MASTER cases; no GGUF path |
| C-036 | SMOOTHQUANT_INT8 | CFT 20 | DEQUANT_ONLY | dequantize_smoothquant_weights + known-value case; no GGUF path |
| C-037 | FP8_E4M3 | CFT 21 | DEQUANT_ONLY | compute.mojo dequantize_fp8_e4m3 + fused parity case; no GGUF file_type |
| C-038 | FP8_E5M2 | CFT 22 | DEQUANT_ONLY | compute.mojo dequantize_fp8_e5m2 + fused parity case; no GGUF file_type |

SMOKE_PASS* (IQ family): genuine-tensor smoke passes at census geometry
(K divisible by 256). The asterisk is bug B1 below — the same files at
stories geometry (K=288) fail, and that failure is an engine limitation,
not a fixture artifact: llama.cpp itself loads and runs those files.

## Bug B1 — gemm_iq rejects K not divisible by 256, breaking IQ4_NL at K=288

All nine stories IQ-recipe files (IQ1_S, IQ1_M, IQ2_XXS, IQ2_XS, IQ2_S,
IQ3_XXS, IQ3_S, IQ4_NL, IQ4_XS file_types) load ("GGUF validated: 48
tensors") then raise in inference: "gemm_iq4_nl: invalid shape or
incomplete quantization block". Root cause, core/compute.mojo gemm_iq:
the shared IQ GEMM gate requires A.cols % 256 == 0 for every IQ type.
llama.cpp's recipes place IQ4_NL tensors in the 288-wide matrices of
these files; IQ4_NL is a 32-value-block format (dequantize_iq4_nl_block32
exists and is used for embeddings) and does not need a 256-wide K.
The 256 gate is correct for the grid IQ types (256-value super-blocks)
but wrong for IQ4_NL (and arguably IQ4_XS, 256-value super-block with
32-value sub-blocks — keeper/engine owner to judge). Fix direction:
route IQ4_NL GEMM through the block32 dequant path when K % 256 != 0,
or relax the gate per type with a per-type block-size table. Recorded
as immediate next work in team-04 CAMPAIGN_STATE.md; A-059 (Vulkan IQ
GEMV) cites this census for the IQ format list and inherits the shape
question on the GPU side.

## Reconciliation (no format unaccounted for)

Enumerated 38 = SMOKE_PASS 28 (C-001..C-008 dense+legacy, C-010..C-018
K family, C-020..C-028 IQ family, C-029..C-030 ternary) + DEQUANT_ONLY 9
(C-009, C-031..C-038) + REJECTED_AT_LOAD 1 (C-019). 28 + 9 + 1 = 38.
Every CompressedFormatType value 0..33 and every GGMLType loader entry
appears exactly once above. Canonical GGUF types the engine does NOT
claim (Q4_2, Q4_3, IQ3_S's siblings I8/I16/I32/I64/F64, Q4_0_4_4/4_8/8_8
ARM variants, MXFP4, NVFP4) are absent from both enumerations and are
therefore out of census scope by the roadmap's own wording ("every quant
type the engine claims"); they are named here so the boundary is
explicit, not silent.

## Discipline notes

- CPU engine only; no accelerator execution claimed (law: accelerator-
  visible is not accelerator-run). The Vulkan device visible to
  llama-quantize during fixture creation is a tool-side fact, not an
  Aesir execution claim.
- IQ quality is graded by the E-MASTER known-value + SIMD-parity oracle
  cases and the embedding lookup case in the same gate run, per law 3
  (coherence/rank discipline) — never by token exactness.
- All counts in this doc were read from logs on disk: a046_smoke.log
  (57 file smokes: 48 PASS, 9 FAIL — the 9 being bug B1), per-file
  smoke logs, GGUF header histograms, and the E-MASTER gate log
  a046_run_all.log (see ledger for the counted totals).
