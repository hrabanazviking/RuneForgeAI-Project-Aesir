# QC-5 — the Q4_K_M tier: K-quant packing writer, whole-model conversion + grade, llama.cpp arbitration

Worker slice, executed on purpleraider in worktree
`/home/volmarr/aesir-qc-5`, branch `yrsa/qc-5`, based on
origin/yrsa/hip-serve tip `67293f1e1cacfe16ef3a3f152b9a0ff11b78ab91`
(re-read by ls-remote at seat time; the branch has since moved
sibling-side — integration is the coordinator's merge). All six Forge
roles (plan, build, test, review, verify, bank) were run sequentially
by this one worker; no sub-agents (depth limit). All runs fenced
(MemoryHigh=24G/MemoryMax=32G); every number below is a correctness
number from a log on disk in this directory, never a timing.

Stage commits (each pushed to `yrsa/qc-5` and ls-remote verified;
main never touched):

- Stage 1 (llama-quantize + census): `c2f7281b6a7c6b405bd2ee7f1966bfbbb251a24e`
- Stage 2 (K packer + proofs): `0cd5d4a3cf817a7ab499e9c6896b9c9c81b8122e`
- Stage 3a/3b (CLI tier + conversion proof): `5745a89d95a64e49fd8707a42c0483f6d6950be9`
- Stage 3c/3d + regressions + these notes: the commit carrying this file.

## Stage 1 — llama-quantize built (the QC-4 named gap, closed)

`cmake --build ~/llama.cpp-build/build --target llama-quantize -j 4`
under the fence, exit 0. Binary:
`/home/volmarr/llama.cpp-build/build/bin/llama-quantize` (17,880 B).
llama.cpp is at upstream commit `a956a85` — the same referee commit
as QC-4. `--help` exits 1 (its normal usage exit); help text banked
(`qc-5-llama-quantize-help.log`).

Source census (independent Python parse, `qc5_census.py`, banked):
`stories260K.F16.gguf` = 601,248 B, sha256
`57a81ed1c8b032ba29319eae80c3e568dbb5a16ce665a09da1a0efe2e4eb69e3`,
48 tensors, 21 KVs, `llama.block_count=5`, data_offset 14,240.
37 F16 matrices + 11 F32 1-D norms. Every matrix's TOTAL element
count is divisible by 256; dim0 is 64 (or 172 for ffn_down) — never
divisible by 256. That single fact drives the whole slice (below).

## Stage 2 — the K packer (`aesir_engine/core/quantize.mojo`)

`quantize_q4_k` / `quantize_q6_k` produce ggml-layout blocks:

- Q4_K (type 12): 144 B per 256 elements — f16 super-scale `d`,
  f16 super-min `dmin`, 12 B of packed 6-bit sub-block scales/mins
  (8 sub-blocks of 32), 128 B of 4-bit quants.
- Q6_K (type 14): 210 B per 256 elements — 128 B low nibbles,
  64 B high bits, 16 signed i8 scales (per 16 elements), f16 `d`.

Layouts verified lane-by-lane against BOTH the engine's own
dequantizer (`core/packed_quantization.mojo packed_value`) and
ggml's `get_scale_min_k4` semantics.

### ggml-mirroring account — where we mirror, where we simplify

MIRRORED from `ggml-quants.c`: the block layouts; the two-level
super-quantization structure (per-sub-block scale/min first, then
the scales themselves quantized against f16 `d`/`dmin` for Q4_K and
f16 `d` for Q6_K); quants re-formed against the STORED (quantized)
reconstruction, exactly as ggml's reference does, so the dequantizer
sees self-consistent values.

SIMPLIFIED (named, byte-changing, bound-proven):

1. Q4_K sub-block fit: plain min/max fit
   (`scale = (max - min_eff)/15`, min clamped <= 0) instead of
   ggml's `make_qkx2_quants` weighted least-squares search.
2. Q6_K group fit: symmetric `s_j = amax_j/32` with non-negative
   scales (`d = max_s/127`, stored scale bytes clamped [0,127],
   requant `l = clamp(round(x/s_hat), -32, 31)` stored as l+32)
   instead of `make_qx_quants`' signed scale search.
3. Rounding is round-half-away-from-zero; ggml rounds to nearest
   even. They differ only on exact .5 ties, inside the same bound.

### Proven round-trip bounds (asserted elementwise in the harness)

Q4_K, per element of a sub-block with ideal fit (s_j, m_j) and
stored reconstruction (s_hat, m_hat):

    err <= s_hat/2 + 15*|s_hat - s_j| + |m_hat - m_j|
           + 1e-6*(1 + |x| + s_hat + m_hat) + 1e-7

Q6_K, per element of a 16-group with ideal scale s_j and stored
s_hat (the `+ s_j` term is the +31/-32 clamp asymmetry):

    err <= s_hat/2 + 32*|s_hat - s_j| + s_j + dust

Harness (`test_quantize_k_qc_5`, ALL PASS, `qc-5-k-test.log`):
random + adversarial vectors (negative ranges exercising the mins,
constant blocks, outlier sub-blocks), a longhand packing proof that
`packed_value` equals an independent layout re-derivation on every
lane, all-zero blocks exact, all 9 refusals firing (count <= 0, count
not a multiple of 256, non-finite value named by index, super-scale
f16 overflow; underflow deliberately NOT refused), and a QC-1 writer
round-trip at file_type 15. Worst err/bound ratios on the
adversarial suites: **Q4_K 0.9989002, Q6_K 0.9686628** — the bounds
are honest and nearly tight.

## Stage 3a — policy + CLI tier

### The policy (llama.cpp's file_type 15 rule set, no imatrix)

Transcribed from `~/llama.cpp-build/src/llama-quant.cpp` at a956a85:
default Q4_K; OUTPUT -> Q6_K; ATTN_V -> Q6_K when
`use_more_bits(i, n) = i < n/8 || i >= 7*n/8 || (i - n/8) % 3 == 2`;
FFN_DOWN -> Q6_K when use_more_bits(layer); ATTENTION_OUTPUT stays
Q4_K; token_embd stays Q4_K. For n = 5 layers, use_more_bits selects
layers **2 and 4** (i >= 35/8 = 4, and (i-0) % 3 == 2).

As applied by our converter (confirmed by the emitted-file census):

| tensors | count | kind |
|---|---|---|
| output.weight | 1 | Q6_K |
| blk.2/4 .attn_v.weight | 2 | Q6_K |
| blk.2/4 .ffn_down.weight | 2 | Q6_K |
| all other matrices (incl. token_embd) | 32 | Q4_K |
| 1-D norms | 11 | kept F32 |

Payload totals: Q6_K 58,880 el / 230 blocks / 48,300 B; Q4_K
233,216 el / 911 blocks / 131,184 B; kept 2,816 B.

CLI: `aesir quantize <src> <out> --to q4_k_m` (tier constant
`q4_k_m`, file_type 15). The report now records the real per-tensor
emitted types and the real file type for every tier. `--streaming`
is refused for the K tier by name — a streaming K converter is
QC-6 work (see risks). CLI end-to-end product is BYTE-IDENTICAL to
the test product: sha256
`068a41c7beaee21b5376b0fefe2d95aa46fa3259c9166ecf35f852df94c98d26`
(`qc-5-cli.log`).

### Writer amendment (named scope decision)

The first conversion run was refused by the QC-1 writer:
"tensor dim0 is not block aligned: output.weight". The writer's
validators (`validate_gguf_desc`, `validate_gguf_metas`) required
`dims[0] % block == 0` — ggml's per-row rule — while the writer
itself prices payloads through the readers' FLAT
`gguf_tensor_byte_size`. Amendment, confined to block-256 (K) types:
they now require `element_count() % 256 == 0` (the flat rule the
payloads are actually priced by); block-1 and block-32 types keep
the previous check byte-for-byte. QC-1's proof reruns ALL PASS
after the amendment (regressions, below).

## The central finding: two K consumption models

The engine — and ggml — hold two incompatible answers to "how are
K blocks laid over a matrix":

- FLAT: blocks tile the tensor's element stream in order.
  Aesir's GGUFSeer pricing (`_tensor_byte_size` = (count//256)*144),
  `packed_value`, and `dequantize_range_f32` are flat. Our converter
  tiles flat because the dequantizer it must invert is flat.
- PER-ROW: each row of dim0 elements owns whole blocks; requires
  dim0 % 256 == 0. ggml's quantize/dequantize validity rule,
  Aesir's PackedGGUF pricing (`packed_row_bytes`), and the fused
  K GEMM's addressing (`blocks_per_row = A.cols // 256` in
  `_gemm_k_fast`, guarded by `A.cols % 256 != 0` in `gemm_ggml_k`)
  are per-row.

When dim0 % 256 == 0 the two models produce IDENTICAL bytes; the
distinction is invisible. stories260K (dim0 64 / 172) separates
them completely: a flat-tiled Q4_K_M file is the only Q4_K_M file
our converter can honestly emit for it, and it is admissible only
to the flat consumers. QC-0-PLAN's per-row wording assumed the
ggml model; this slice's converter follows the flat model, and the
divergence is recorded here as a finding, not silently.

## Stage 3b — conversion proof (`test_quantize_model_qc_5`, ALL PASS)

- Policy as applied (table above); metadata identical to source
  except `general.file_type` = 15; directory names/shapes/order
  preserved; all offsets 32-aligned; every kept payload
  byte-identical to source.
- Whole-model bound sweep through the engine dequantizer over all
  292,096 quantized elements: worst err/bound **Q4_K 0.99672973,
  Q6_K 0.7372395**.
- GGUFSeer loads the emitted file to VALIDATED.
- Size: **196,816 B** = 32.7% of the 601,248 B source; 51.9% of
  the Q8_0 product (379,152 B).

Admission probes (asserted exactly in the test; these are the
named admission differences vs the F16 source):

- PackedGGUF: REFUSES — "Packed GGUF: K-quant row is not block
  aligned" (per-row pricing). The source is admitted.
- AesirEngine forward: REFUSES — "gemm_q4_k_m: invalid shape or
  incomplete quantization block" (per-row fused GEMM). No Q4_K_M
  file, flat- or row-tiled, can execute stories260K's shapes in
  this forward; that is precisely why llama.cpp's own product
  contains no K tensors for this model (Stage 3d).
- Registry inspect: our file dies inside inspect on the same
  PackedGGUF refusal (exit 1). The SOURCE inspect exits 0 with
  verdict UNSUPPORTED / NOT READY — the pre-existing
  tokenizer/chat-template metadata mismatch, unchanged.

## Stage 3c — grade of OUR product

Method, stated plainly: the stock QC-3a grade driver
(`grade_quantize_qc_3`, AesirEngine teacher-forcing) cannot execute
the K file (above), so the grade was taken on the DEQUANTIZED
WEIGHT SET our file encodes — `dequantize_model_qc_5` materializes
the engine's own flat dequantization of every K tensor into an F16
GGUF with the source's metadata, and the unmodified driver grades
that against the F16 source. That is exactly the quantity a
quantization grade measures: the end-to-end effect of the weights
any correct forward computes from our payloads. 157 records, RAW
prompts, CPU-vs-CPU, band = rank <= 2 AND gap < 1.0.

Result (`qc-5-grade-ours.csv`, summary via `qc3_grade_summary.py`):

- in-band **154/157 = 98.09%**; argmax agreement 141/157 = 89.81%;
  exact 141, near-tie 13, divergent 3.
- rank distribution {0: 141, 1: 12, 2: 3, 3: 1}; worst gap 2.054.
- Verdict by the strict gate rule: **DIVERGENT (not FAITHFUL)** —
  an honest result with numbers, as the brief prescribes for
  K-quant margins.
- The 3 divergent records, named:
  - prompt 0, pos 22 (continuation): rank 3, gap 0.914 — rank out.
  - prompt 2, pos 10 (continuation): rank 1, gap 1.062 — gap out.
  - prompt 3, pos 8 (prompt segment): rank 1, gap 2.054 — gap out.
    At this position even the source's own true-token rank is 4
    (gap 2.617): an intrinsically ambiguous record.

## Stage 3d — arbitration (the QC-0 experiment)

`llama-quantize <source> <out> Q4_K_M` (no imatrix), exit 0
(`qc-5-llama-quantize.log`). llama.cpp's own warnings confirm the
Stage-1 prediction line by line: every Q4_K designation falls back
to Q5_0 (dim0 64 not divisible by 256), the Q6_K designations
(output, blk.2/4 attn_v) fall back to Q8_0, and every ffn_down
falls back to F16 (172 not divisible by 32 either). Census of
llama's product (`qc-5-census-llama.log`): **{Q5_0: 29, Q8_0: 3,
F16: 5, F32: 11} — zero Q4_K, zero Q6_K tensors**, file_type 15,
304,096 B (50.6% of source).

(a) Reverse leg — Aesir grades llama.cpp's file (stock driver):
**FAITHFUL** — in-band 157/157, agreement 152/157 = 96.82%,
worst rank 1, worst gap 0.390 (`qc-5-grade-llama.csv`).

(b) llama.cpp loads OUR file (qc4grade, the QC-4 harness):
**REFUSED at GGUF read** — "gguf_init_from_reader: tensor
'output.weight' of type 14 (q6_K) has 64 elements per row, not a
multiple of block size (256)" -> model load failed
(`qc-5-qc4grade-ours.log`). **U-QC5 for file_type 15: NO** —
llama.cpp does not load our file. file_type 15 is not the blocker
(llama's own product carries 15 and loads in both engines); the
blocker is flat tiling vs ggml's per-row K validity rule.

(b2) llama.cpp grades its own product (qc4grade rows,
`qc4_crossgrade.py` vs the Aesir-source CSV): **FAITHFUL** —
in-band 157/157, agreement 153/157 = 97.45%, worst rank 1, worst
gap 0.380, worst record the same prompt 2 pos 14 as the Aesir-side
grade (`qc-5-crossgrade-llama.log`). Both engines agree on
llama's product.

(c) Three-product table (157 records, same stream, same gate):

| product | bytes | % of source | in-band | agreement | worst rank | worst gap | verdict |
|---|---|---|---|---|---|---|---|
| ours (true Q4_K/Q6_K, flat) | 196,816 | 32.7% | 154/157 = 98.09% | 89.81% | 3 | 2.054 | DIVERGENT |
| llama's (Q5_0/Q8_0/F16 mix) | 304,096 | 50.6% | 157/157 = 100% | 96.82% | 1 | 0.390 | FAITHFUL |
| QC-3a Q8_0 (reference) | 379,152 | 63.1% | 157/157 = 100% | (QC-3a) | — | — | FAITHFUL |

Reading the table honestly: llama's "Q4_K_M" for this model is a
gentler quantization wearing the same file_type — Q5_0 (~5.1 bpw)
on most tensors, Q8_0 on the sensitive ones, full F16 on every
ffn_down — at 1.55x our size. Ours is the only true-density
Q4_K_M of the three, and its 3 divergent records are the price of
that density on a 260K toy model with 64-wide matrices. The gap
conflates two causes that this slice cannot separate: (i) true K
density vs the fallback mix, and (ii) our named min/max fit
simplification vs ggml's searched fits. Separating them needs a
ggml-exact searched packer — named QC-6 candidate work, not
hidden.

## Regressions (all rerun from this tree, `qc-5-regress.log`)

- Engine compile: exit 0 (builds b/b2/c/d/e/f).
- QC-1 writer proof: ALL PASS (byte-identical re-emission).
- QC-2 Q8_0 proof: ALL PASS.
- QC-3a conversion proof: ALL PASS; its regenerated Q8_0 product
  is byte-identical to QC-4's banked product (sha256 5d4df894...).
- QC-3a grade rerun: CSV BYTE-IDENTICAL to banked qc-3-grade.csv.
- QC-3b dequantize_input proof: ALL PASS; streaming writer proof:
  synth + stories modes exit 0 (gemma modes' fixtures do not live
  in this tree).
- Q35-1 loader proof: ALL PASS.
- QC-5 K harness + conversion proof: ALL PASS (above).

## Named risks / required decisions for QC-6 (the 27B conversion)

1. TILING RULE MUST CHANGE. This converter quantizes when the
   TOTAL element count % 256 == 0. For QC-6's product to be
   admissible to PackedGGUF and the fused K GEMM (the qwen35
   packed path), quantization must be gated on dim0 % 256 == 0
   per tensor (where the two tilings coincide byte-for-byte),
   with llama-style named fallbacks (or keep) for the rest. The
   27B directory must be audited tensor by tensor first.
2. NO STREAMING K CONVERTER. The 27B cannot be converted
   in-memory on this machine class; the CLI refuses --streaming
   for q4_k_m by name. Under the dim0 rule each row is a whole
   number of blocks, so the QC-3b streaming machinery adapts
   row-locally — that adaptation is QC-6's first build.
3. FIT QUALITY AT SCALE. The min/max simplification's grade cost
   is unmeasured at real-model scale; ggml's searched fits
   (make_qkx2_quants / make_qx_quants) are the known lever if
   QC-6 grades demand it.
4. NO IMATRIX exists for our models; all comparisons here are
   the honest no-imatrix ones. A QC-6 imatrix decision is
   Volmarr/coordinator business, not assumed.
5. FORWARD ADMISSION IS SHAPE-DEPENDENT. Any future model with
   dim0 % 256 != 0 matrices hits the same three refusals
   (PackedGGUF, fused K GEMM, ggml) regardless of converter;
   teaching PackedGGUF/the GEMM flat-K addressing is reader work,
   out of this workstream's scope, and is named here as the
   alternative road.
