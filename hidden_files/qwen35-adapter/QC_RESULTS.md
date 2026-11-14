# QC_RESULTS — Aesir Compression Workstream: Honest Results (QC-7, 2026-11-14)

Workstream QC-0..QC-7: teach Aesir to WRITE compression — quantize a
source model and emit a valid GGUF that Aesir itself, and llama.cpp as
an independent cross-check, can load and run. This file is the
workstream results record. It changes no engine code.

Traceability rule: every number below cites the banked notes/log file
it came from, all in this folder (hidden_files/qwen35-adapter/).
Verdict words are reproduced EXACTLY as banked — FAITHFUL,
NOT FAITHFUL and DIVERGENT are distinct banked verdicts and are not
softened or merged here. Grading discipline throughout (QC-0-PLAN.md):
teacher-forcing rank + logit gap on RAW prompts, compressed vs its
own source, CPU-vs-CPU; near-tie band = rank <= 2 AND gap < 1.0;
strict gate rule = every record in band.

Method note (QC-7): ONE worker ran the six Forge roles sequentially
(recon, spec, build, proof, review, bank). No sub-agents were spawned
(depth limit). No engine code was changed in this slice.

## 1. What Aesir learned to do — module map

Source: QC-1-NOTES.md, QC-2-NOTES.md, QC-3a-NOTES.md, QC-3b-NOTES.md,
QC-5-NOTES.md, QC-6-NOTES.md, F-3b-1-NOTES.md.

| Capability | Module / surface | Banked by |
|---|---|---|
| GGUF writer core: spec-exact GGUF v3 emission (header, KV sequence, tensor directory, aligned data section), metadata-copy reader path (header/KV/directory without materializing tensors), write-side refusals mirroring the readers | aesir_engine/loader/gguf_writer.mojo (GGUFModelDesc, build_gguf_bytes, write_gguf_file, read_gguf_header_copy, copy_gguf_model); pricing delegates to GGUFSeer _tensor_byte_size so writer and reader cannot drift | QC-1 |
| Streaming writer: header first, per-tensor payloads in directory order through write_chunk; peak memory O(largest tensor chunk), not O(file). Gemma E2B re-emission peak RSS: in-memory 9,049,800 KB vs streaming 3,087,116 KB | loader/gguf_writer.mojo (GGUFStreamWriter, build_gguf_header_bytes) | QC-3b stage 1 |
| Q8_0 quantizer: ggml quantize_row_q8_0_ref rule (d = amax/127 stored f16; q = roundf(w/d), round half AWAY from zero — QC-2 erratum E-1 corrects the plan round-to-nearest-even phrasing; clamp [-127,127]; zero block d=0). Proven per-element error bound, worst err/bound 0.80-0.90 on random data; exact on the Q8_0 lattice | aesir_engine/core/quantize.mojo (quantize_q8_0) | QC-2 |
| K-quant packers: Q4_K (144 B/256, f16 d + f16 dmin + 12 B packed 6-bit sub-block scales/mins + 128 B quants) and Q6_K (210 B/256). Named simplifications vs ggml: plain min/max sub-block fit instead of make_qkx2_quants searched fit; symmetric Q6_K group fit instead of make_qx_quants; round-half-away vs round-to-nearest-even. Proven bounds nearly tight: worst err/bound Q4_K 0.9989002, Q6_K 0.9686628 (adversarial suites) | core/quantize.mojo (quantize_q4_k, quantize_q6_k) | QC-5 stage 2 |
| Dequantizing input path: checked dispatch over the engine own dequantizers to F32 (no F16 intermediate); covered dense F32/F16/BF16 + Q4_K/Q5_K/Q6_K (QC-3b), Q8_0 wired in QC-6; every other type refused BY NAME (kept-by-policy with reason) | aesir_engine/core/dequantize_input.mojo | QC-3b stage 2, QC-6 stage 2 |
| Converter + CLI: aesir quantize <src> <out> [--to q8_0 \| q4_k_m] [--streaming]; per-role policy (rank-1 norm/scale/bias class stays at source type; general.file_type set per tier: Q8_0 = 7, Q4_K_M = 15); Q4_K_M policy = llama.cpp file_type 15 rule set without imatrix (default Q4_K; output and use_more_bits attn_v/ffn_down upshifted to Q6_K) | aesir_engine/cli/quantize.mojo + cli/commands.mojo dispatch | QC-3a, QC-3b, QC-5, QC-6 |
| Registry admission earned by evidence: qwen35 admits Q4_K_M beside Q8_0 (scoped, docstring-cited); gemma4 admits Q8_0 via scoped gemma4_quantization_supported (F-3b-1 fix; shared lists NOT extended) | aesir_engine/core/model_registry.mojo | QC-6, F-3b-1 |

Writer proof anchor (QC-1): synthetic 3-tensor model byte-exact;
stories260K re-emission BYTE-IDENTICAL to source (601,248 B, 0
mismatches); gemma E2B header copy == GGUFSeer and PackedGGUF parses
for all 601 tensors.

## 2. Per-tier, per-model results

### 2.1 Verdict table (one line per product)

| # | Source -> Product | Bytes (source -> product, ratio) | Records | In-band | Agreement | Worst rank | Worst gap | Verdict (as banked) | Source |
|---|---|---|---|---|---|---|---|---|---|
| 1 | stories260K F16 -> Q8_0 (ours, Aesir grade) | 601,248 -> 379,152 (63.06%) | 157 | 157/157 = 100.00% | 156/157 = 99.36% | 1 | 0.007 | FAITHFUL | QC-3a-NOTES.md |
| 2 | stories260K F16 -> Q8_0 (ours, llama.cpp cross-grades: llama-vs-llama and llama-vs-Aesir) | 601,248 -> 379,152 (63.06%) | 157 | 157/157 = 100.00% | 157/157 = 100.00% | 0 | 0 by construction where argmax agrees (max abs logit diff 0.4316) | FAITHFUL | QC-4-NOTES.md |
| 3 | gemma-4-E2B Q4_K_M -> Q8_0 (ours, llama.cpp grade, fallback) | 3,106,738,272 -> 4,954,595,424 (+59.5%, grows) | 79 | 78/79 = 98.73% | 73/79 = 92.41% | 2 in-band (divergent record rank 1) | 0.587 in-band; 1.489 divergent record | NOT FAITHFUL | QC-3b-NOTES.md |
| 4 | stories260K F16 -> Q4_K_M (ours, true K, flat tiling; graded on dequantized weight set) | 601,248 -> 196,816 (32.7%) | 157 | 154/157 = 98.09% | 141/157 = 89.81% | 3 | 2.054 | DIVERGENT | QC-5-NOTES.md |
| 5 | stories260K F16 -> Q4_K_M (llama.cpp product; Aesir grade / llama.cpp grade) | 601,248 -> 304,096 (50.6%) | 157 | 157/157 = 100% / 100% | 152/157 = 96.82% / 153/157 = 97.45% | 1 / 1 | 0.390 / 0.380 | FAITHFUL (both engines) | QC-5-NOTES.md |
| 6 | stories260K F16 -> streaming-K path product under the dim0 tiling rule (fallbacks carry the model) | 601,248 -> 379,152 (63.06%) | no separate grade: payload-identical to product 3b-class Q8_0 (see 2.2) | — | — | — | — | no grade claimed (admission + token-identity proof only) | QC-6-NOTES.md |
| 7 | Qwen3.8-27B Q8_0 -> Q4_K_M (ours, Aesir grade, Q35-3b stream) | 28,596,003,296 -> 16,223,236,576 (56.7%) | 198 | 197/198 = 99.49% | 190/198 = 95.96% | 3 (the one out-of-band record) | 0.421 | DIVERGENT | QC-6-NOTES.md |

### 2.2 Per-product detail, load/admission, honest framing

Product 1 — stories260K Q8_0 (QC-3a). Mixed file: 32 Q8_0 + 5 F16
(ffn_down, dim0 172 not a multiple of 32, kept by name) + 11 F32
norms, file_type 7. Load: GGUFSeer VALIDATED; PackedGGUF constructs
in full; engine greedy first-8 identical to source and to the pinned
llama.cpp oracle prefix. Registry inspect: NOT READY / UNSUPPORTED
on BOTH source and product with the identical tokenizer reason
(finding F-3a-1, pre-existing; conversion changed nothing there).
Single non-exact record named: prompt 2 pos 10, rank 1, gap 0.007;
free-running greedy diverges there at step 3, both continuations
coherent. QC-4 later showed llama.cpp does NOT see that greedy
divergence (margin +0.0068 in llama-Q8_0 vs -0.007 in Aesir Q8_0 —
the same near-tie coin, opposite side; no defect either side).

Product 2 — QC-4 cross-check of product 1. Determinism: re-emitted
from the merged tree byte-identically (sha256 in section 4).
llama.cpp loads the MIXED file as-is with no warning/refusal —
U-QC5 settled for file_type 7: llama.cpp dispatches per tensor type,
the label is display only. Named comparator artifact: llama-cli text
tokenization of this fixture differs from the reference token stream
on BOTH files identically; raw-token-ID path is the evidence.

Product 3 — gemma-4-E2B Q8_0 (QC-3b). HONEST FRAMING (banked,
required): the source is itself quantized; this grade prices a
dequant -> requantize round trip (Q4_K_M -> F32 -> Q8_0) on a
llama.cpp fallback grade, NOT compression from a float original —
no float E2B reference exists in the campaign. Aesir-side grade was
attempted and is recorded exactly: both models loaded, tokenizer
parity held, then the harness raised and produced no CSV; inspect
reports gemma4 CPU support: no — admission is not a forward (see
section 5). The grade is therefore llama.cpp on BOTH sides by
design (it prices the conversion, not engine parity). The ONE
divergent record: prompt 5 pos 24, rank 1, gap 1.489 (comparator
argmax 5756 vs candidate 31225); greedy diverges at the same
position (fresh vs damp), both coherent. Recurring in-band near-tie:
prompts 0/2/4 pos 1, rank 2, gap 0.587. Load: GGUFSeer VALIDATED on
both files; PackedGGUF constructs on both. Registry: source READY /
VERIFIED; product at QC-3b time NOT READY / UNSUPPORTED (finding
F-3b-1: gemma4 profile list lacked Q8_0) — FIXED by F-3b-1: product
now READY / COMPATIBLE, tensor validation passed, estimated VRAM
5,171,679,844 B (F-3b-1-NOTES.md). Size framing (banked): the product
is LARGER than the source (+59.5%) — Q8_0 (~8.5 bits/elem) is a less
dense tier than the Q4_K_M mix; a tier-density fact, not a defect.

Product 4 — stories260K Q4_K_M, ours (QC-5). The only true-density
Q4_K_M of the stories set: 32 Q4_K + 5 Q6_K (output + blk.2/4
attn_v/ffn_down) + 11 F32 norms, file_type 15; 51.9% of the Q8_0
product size. Admission: GGUFSeer VALIDATED; PackedGGUF REFUSES
(K-quant row is not block aligned); AesirEngine forward REFUSES
(per-row fused GEMM shape); llama.cpp REFUSES at GGUF read (q6_K
tensor has 64 elements per row, not a multiple of 256) — U-QC5 for
file_type 15 answered NO for flat tiling; the blocker is tiling,
not the file_type label. Grade method stated plainly in the notes:
the K file cannot execute, so the grade was taken on the
DEQUANTIZED WEIGHT SET the file encodes (engine flat dequantization
materialized to F16, unmodified QC-3a driver). Divergent records
named: p0 pos22 rank 3 gap 0.914; p2 pos10 rank 1 gap 1.062;
p3 pos8 rank 1 gap 2.054 (at p3 pos8 even the source true-token
rank is 4 — an intrinsically ambiguous record).

Product 5 — stories260K Q4_K_M, llama.cpp (QC-5 arbitration).
HONEST FRAMING (banked): llama.cpp product contains ZERO K tensors
— census {Q5_0: 29, Q8_0: 3, F16: 5, F32: 11}, file_type 15. Every
Q4_K designation fell back to Q5_0 (dim0 64), Q6_K designations to
Q8_0, ffn_down to F16 (dim0 172). It is a gentler quantization
wearing the same file_type, at 1.55x our product size; its FAITHFUL
grades (both engines) are the reverse leg QC-4 named as missing.
The QC-5 three-product reading stands: the grade gap between
products 4 and 5 conflates (i) true K density vs the fallback mix
and (ii) our min/max fit vs ggml searched fits; separating them
needs the searched packer (section 5).

Product 6 — stories260K through the QC-6 streaming K converter
(QC-6 stage 2 fixture proof). No stories matrix is 256-aligned, so
the fallback table carries the whole model: 32 matrices -> Q8_0
fallback, 5 ffn_down kept F16, 11 norms kept F32. Product is
PAYLOAD-IDENTICAL to QC-3b proven streaming Q8_0 product, tensor by
tensor (only general.file_type differs: 15 vs 7). Admission:
GGUFSeer VALIDATED; PackedGGUF CONSTRUCTS (the admission product 4
was refused); engine generates token-identically to the QC-3b
product; llama.cpp loads and generates. No separate grade is
claimed — payload identity carries product 1/3b evidence.

Product 7 — 27B Q4_K_M (QC-6). Census first: all 498 Q8_0 tensors
have dim0 % 256 == 0; kept class = 353 F32 (305 rank-1 + 48
ssm_conv1d [4, 10240], kept F32 per QC-0 section 3). Emitted:
457 Q4_K + 41 Q6_K, ZERO Q8_0 fallbacks, ZERO shape keeps.
Conversion 3:21 wall, peak RSS 27,976,676 KB (~28.0 GB, almost
entirely reclaimable source mmap pages; heap O(largest row)).
Admission: GGUFSeer VALIDATED; PackedGGUF constructs (registry
inspect tensor validation passed); registry READY / COMPATIBLE;
llama.cpp loads and generates; qwen35 CPU forward executes the
product end-to-end through the default packed path (U-QC3 settled).
Load-mode honesty (banked): the product does NOT load through the
Q35-3r resident contract — validate_qwen35_resident is Q8_0-only
and refuses it BY NAME; its executed path is the default packed
path (zero-copy packed views, no F16 materialization — the 19.5 GB
footprint in RESIDENCY-NOTE.md is the proof). The ONE out-of-band
record, named: p5 pos22, rank 3, gap 0.421; source argmax 1817,
product argmax 17454, true token 89240. Generation witness coherent
(Paris answer; wording diverges from source greedy as the 95.96%
agreement prices). Pipeline sanity: source vs banked llama.cpp rows
reproduced Q35-3b v2 exactly (198/198 in band).

## 3. Size-vs-quality summary (plain)

Source for every line: the notes file cited in the table above.

- Q8_0 from a float source (stories260K): near-lossless at ~63% of
  the source bytes (63.06%), 100% of grade records in band, worst
  gap 0.007 logits. The proven-fidelity tier.
- Q8_0 from a Q4_K_M source (gemma E2B): an UP-conversion that grows
  the file +59.5% (3.11 GB -> 4.95 GB) — Q8_0 is less dense than the
  Q4_K_M mix. It buys a proven-tier representation of a quantized
  source at 98.73% in-band, and its strict verdict is NOT FAITHFUL
  on one rank-1 / gap-1.489 record. A density fact, never a size win.
- Q4_K_M at true density on hostile shapes (stories260K, dim0
  64/172): ~33% of source bytes (32.7%), the smallest product in
  the workstream, at a DIVERGENT strict verdict (154/157 in band,
  worst gap 2.054) — and, flat-tiled, admissible to no packed or
  per-row reader. Density without the tiling gate is not a product.
- Q4_K_M as llama.cpp actually emits it for that model: 50.6% of
  source, FAITHFUL in both engines — because it contains no K
  tensors at all (Q5_0/Q8_0/F16 fallbacks).
- Q4_K_M at real scale with the tiling gate satisfied (27B): 56.7%
  of the Q8_0 source, 99.49% in band, worst gap 0.421 — the
  strongest K-tier grade in the workstream, still DIVERGENT by the
  strict gate on a single rank-3 record. It also buys residency:
  ~19.5 GB resident vs ~31.0 GB for the source (RESIDENCY-NOTE.md).

## 4. The tiling law — the workstream central technical lesson

Source: QC-5-NOTES.md (central finding), QC-6-NOTES.md (stage 1).

The engine — and ggml — hold two incompatible answers to how K
blocks lay over a matrix:

- FLAT: blocks tile the tensor element stream in order. Aesir
  GGUFSeer pricing (_tensor_byte_size = (count//256)*144),
  packed_value and dequantize_range_f32 are flat.
- PER-ROW: each row of dim0 elements owns whole blocks; requires
  dim0 % 256 == 0. ggml quantize/dequantize validity, Aesir
  PackedGGUF pricing (packed_row_bytes) and the fused K GEMM
  addressing (blocks_per_row = cols // 256) are per-row.

When dim0 % 256 == 0 the two models produce IDENTICAL bytes and
the distinction is invisible. The law as banked by QC-6:

- Quantize a tensor to a K tier ONLY when dim0 % 256 == 0 per
  tensor (there flat == per-row, and every reader admits the
  payload by construction).
- Otherwise apply named fallbacks, never silent tiling: a K
  designee with dim0 % 32 == 0 falls back to Q8_0 (per-row valid
  everywhere; the named substitute where llama.cpp would use Q5_0,
  for which this workstream has no writer); a designee with
  dim0 % 32 != 0 stays at source type; rank-1 / norm / bias tensors
  stay at source type at any dim0; ssm_conv1d stays F32, full stop.
- The 32-block tiers have the analogous gate: Q8_0 quantizes only
  where dim0 % 32 == 0 (stories ffn_down at dim0 172 stayed F16 in
  QC-3a for exactly this reason).
- Evidence: stories260K (no 256-aligned matrix) separates the
  models completely — flat product refused by PackedGGUF, the
  fused GEMM and llama.cpp; fallback product admitted by all. The
  27B (every Q8_0 tensor 256-aligned) needs no fallback at all.

## 5. Named remaining work (exactly as the slices left it)

Source: QC-5-NOTES.md, QC-6-NOTES.md, QC-3b-NOTES.md, QC-1-NOTES.md,
QC-0-PLAN.md, F-3b-1-NOTES.md.

1. ggml searched-fit packer (make_qkx2_quants / make_qx_quants
   replacing the plain min/max fit). Measured targets: QC-6 p5
   pos22 (rank 3, gap 0.421 — does the searched fit move it into
   band, and what does it do to the 190/198 agreement?) and QC-5
   stories 154/157. Named QC-7/QC-8-class work; the QC-6 stretch
   was NOT taken.
2. Q4_K_M resident-analogue contract: Q35-3r gate is Q8_0-only and
   refuses the 27B product by name. A K-census-validating resident
   contract (health-reported, Q35-3r style) is required before any
   resident Q4_K_M claim or gate swap — Q35-7 work. The QC-6 serve
   smoke (two-turn, serve surface) also belongs with Q35-7; QC-6
   graded through the driver, not the serve surface.
3. gemma4 CPU forward: F-3b-1 fixed registry admission (Q8_0 now
   READY/COMPATIBLE), but inspect still reports CPU support: no for
   gemma4 — admission is not a forward. Until a CPU forward exists,
   converted gemma files are loader-grade + llama-grade only.
4. The reverse leg for file_type 15 mixed products: QC-4 reverse
   leg was for file_type 7; QC-5 supplied the stories instance
   (Aesir grades llama.cpp file_type 15 product FAITHFUL; llama.cpp
   refuses our flat product). The general file_type 15 mixed-product
   reverse leg (a per-row-valid mixed K product cross-loaded both
   ways) remains as the slices left it — QC-6 stories fallback
   product (file_type 15, llama.cpp loads it) is partial evidence,
   not the settled leg.
5. F-2 (QC-2 finding): GGUFSeer failed-load dangling pointers —
   mmap_and_load except path calls _cleanup() which munmaps before
   re-raising, so seer.tensors[*].data pointers dangle after ANY
   failed load. Validated production loads are unaffected; proofs
   must use the offsets/file-image pattern post-raise. Unfixed,
   named for a reader slice.
6. The _tensor_byte_size Q4_0 fall-through (QC-1 erratum E-2):
   GGUFSeer prices types it does not explicitly price at the Q4_0
   rate (18 B/32) — e.g. type 15 Q8_K — with refusal arriving only
   later at map time. Named next work: make loader pricing refuse
   unknown types explicitly, or document the fall-through as
   load-bearing. (The writer already refuses unpriced types up
   front.) Related pre-existing reader inconsistency from QC-0
   U-QC2: Q8_1 priced 36 B/block by the loader while compute.mojo
   walks 40 B blocks; Q8_1 is not a write tier; settles only with a
   real Q8_1 file or an upstream-source read.
7. Imatrix absence: no imatrix exists for our models; every
   comparison in this workstream is the honest no-imatrix one. The
   27B source carries quantize.imatrix.* KVs (produced elsewhere);
   QC-6 conversion is no-imatrix. An imatrix decision is
   Volmarr/coordinator business, not assumed.
8. Also carried, unnamed as slices: rope sections at serve-length
   contexts for the 27B product (QC-6 risk 4 — grade stream is
   <= 60 positions); QC-2 finding F-1 (engine Q8_0 dequantizers
   write F16, so blocks with amax > 65504 dequantize to Inf through
   the engine path though the payload is ggml-valid); teaching
   PackedGGUF / the fused GEMM flat-K addressing (reader work, the
   alternative road named by QC-5 risk 5, out of this workstream
   scope).

## 6. Model store record

All products are GGUF files, NOT committed (*.gguf is git-ignored
tree-wide; QC-3a/QC-3b/QC-6 notes). Verification state column:
RE-VERIFIED = sha256 recomputed on-device in QC-7 (2026-11-14) and
matching the banked value; BANKED-ONLY = value from the notes, file
not re-hashed this slice; NEW = hashed first in QC-7.

| File | Path | Bytes | sha256 | State |
|---|---|---|---|---|
| stories260K.F16.gguf (source fixture) | external fixture, copies in sibling worktrees (fixture pin) | 601,248 | 57a81ed1c8b032ba29319eae80c3e568dbb5a16ce665a09da1a0efe2e4eb69e3 | BANKED-ONLY (pin re-verified by QC-3a/QC-4 runs) |
| stories260K.Q8_0.gguf (QC-3a product; reproduced byte-identically by QC-3b streaming, QC-4, QC-5, QC-6 regressions) | /home/volmarr/aesir-qc-3/hidden_files/qwen35-adapter/stories260K.Q8_0.gguf (and sibling worktree copies) | 379,152 | 5d4df894e4ed0d16f84d94c0a2a7524a4915123fe96148dc0e41b7bc1a6d77b7 | RE-VERIFIED |
| gemma-4-E2B-it-Q4_K_M.gguf (source) | /home/volmarr/aesir-forge/.aesir/models/gemma-4-E2B-it-Q4_K_M.gguf | 3,106,738,272 | 740185b21d22ceb83a11c3aa62ad5842ef32c70f6096d756bbee85a1e4ec34b8 | BANKED-ONLY (re-measured by QC-3b conversion run) |
| gemma-4-E2B-it-Q8_0.gguf (QC-3b product) | /home/volmarr/aesir-qc-3b/hidden_files/qwen35-adapter/gemma-4-E2B-it-Q8_0.gguf | 4,954,595,424 | a63bde439cf22226df55e1ef937c656c71a801e34c721290c8d1cfeb962a36d1 | RE-VERIFIED |
| stories260K.Q4_K_M.gguf (QC-5 product, ours, flat) | /home/volmarr/aesir-qc-5/hidden_files/qwen35-adapter/stories260K.Q4_K_M.gguf | 196,816 | 068a41c7beaee21b5376b0fefe2d95aa46fa3259c9166ecf35f852df94c98d26 | RE-VERIFIED |
| stories260K.llama-Q4_K_M.gguf (QC-5 product, llama.cpp) | /home/volmarr/aesir-qc-5/hidden_files/qwen35-adapter/stories260K.llama-Q4_K_M.gguf | 304,096 | 5275ae0d8387e520815af352d9b350b0e7210939ec22e8dcee953a03f7795e83 | NEW (size banked in QC-5 notes; sha first recorded here, measured QC-7) |
| stories streaming-K fallback product (QC-6 fixture proof; CLI copy byte-identical) | /home/volmarr/aesir-qc-6/hidden_files/qwen35-adapter/qc-6-stories-q4km.gguf | 379,152 | 579a6a17c0f6741a79c83e92925126188ac2398bb92d2b1fd33409cc2e10c460 | NEW (payload identity + size banked in QC-6 notes; sha first recorded here, measured QC-7) |
| Qwen3.8-27B heretic Q8_0 (source) | /mnt/vault/models/gguf/Qwen3.8-27B-Ultimate-Heretic-Uncn-Turbo-Brilli-50x-AGI-NEO-Q8_0.gguf | 28,596,003,296 | 1fca6eefc37607b5ab458f9a76815b36aeb38cf21ac36c49fdc0ab4eb186f08e | BANKED-ONLY (re-measured by QC-6, qc-6-source-sha.log) |
| Qwen3.8-27B heretic Q4_K_M (QC-6 product) | /mnt/vault/models/gguf/Qwen3.8-27B-Ultimate-Heretic-Uncn-Turbo-Brilli-50x-AGI-NEO-Q4_K_M.gguf | 16,223,236,576 | 4515cac669491b4b7a8d6060e6d6e553b35ead74247369aa5cec6c41a7fc04cc | RE-VERIFIED |

Also on the vault, NOT a workstream product (QC-0-PLAN.md): a
sibling ...-MTP-Q4_K_M.gguf (16 G) of a different (MTP) variant,
produced elsewhere — a size sanity reference only, never a QC
deliverable or source. Its exact bytes/sha are not banked in the QC
notes and are therefore not recorded here.

## 7. Accuracy statement

Before banking, this file was re-read against QC-0-PLAN.md,
QC-1..QC-6-NOTES.md (QC-3 split as QC-3a/QC-3b), F-3b-1-NOTES.md,
LEDGER.md and MAP.md. Every number above traces to one of those
banked files or to a QC-7 on-device re-measurement marked as such
in section 6. No number was excluded as untraceable; two sha256
values (llama.cpp stories product, QC-6 stories fallback product)
were absent from the notes and are recorded as NEW QC-7
measurements rather than presented as banked values.
