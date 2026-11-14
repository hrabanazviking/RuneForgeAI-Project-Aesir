# QC-6 — the 27B: Qwen3.8-27B heretic Q8_0 -> Q4_K_M (streaming, dim0 tiling rule)

Worker slice, executed on purpleraider in worktree
/home/volmarr/aesir-qc-6, branch yrsa/qc-6, based on
origin/yrsa/hip-serve tip 3e0b2276e0c1828c31519f1c12a195e414e8e597
(re-read by ls-remote at seat time; main 31ab9363 never touched).
All six Forge roles (plan, build, test, review, verify, bank) were
run sequentially by this one worker; no sub-agents (depth limit).
Every number below is from a log on disk in this folder.

## Contention timeline (honest record)

- Slice start 2026-11-14 ~17:26 EST: sibling Q35-6 worker's HIP
  serve of the 27B Q8_0 ACTIVE (pid 3781599, RSS ~27.2 GB, port
  18435, started 17:04) with its bench driver. MemAvailable
  ~23.5 GB of 121 GB. Per the brief: never touched its tree; all
  heavy QC-6 runs serialize behind it (waits recorded per stage).
- Services aesir-gate / Ollama / Voxta DOWN by Volmarr's order;
  left down.

## Source pin (re-measured this slice)

/mnt/vault/models/gguf/Qwen3.8-27B-Ultimate-Heretic-Uncn-Turbo-Brilli-50x-AGI-NEO-Q8_0.gguf
28,596,003,296 B, sha256
1fca6eefc37607b5ab458f9a76815b36aeb38cf21ac36c49fdc0ab4eb186f08e
— matches the campaign pin exactly (qc-6-source-sha.log).
Note: the file carries quantize.imatrix.* KVs (it was produced
WITH an imatrix elsewhere); QC-6's conversion is no-imatrix, as
are all campaign comparisons.

## STAGE 1 — census + tiling design

Method: header-only mmap parse of the file itself
(qc6_census.py, banked; full 851-line table in
qc-6-census-source.log). 851 tensors, 48 KVs, header 11,183,424 B
data offset. Counts: 498 Q8_0 + 353 F32 — exactly the Q35-1/Q35-3r
census. Geometry: 64 layers (48 SSM + 16 full-attention, interval
4), hidden 5120, FFN 17408, vocab 248,320, ssm inner 6144,
time_step_rank 48, conv_kernel 4.

CENTRAL MEASURED FACT: every one of the 498 Q8_0 tensors has
dim0 % 256 == 0 (dim0 set {5120, 17408, 6144, 10240, 2048} — all
256-multiples). Under the QC-5 design rule, flat tiling == per-row
tiling on every quantized tensor, so PackedGGUF, the fused K GEMM
and llama.cpp all admit the K payloads by construction.

### Audit exceptions — every tensor with dim0 % 256 != 0

All exceptions are in the F32 kept class; there are NO Q8_0
exceptions. Per 48 SSM layers (x48 each):

| tensor | dims | dim0%256 | class |
|---|---|---|---|
| blk.N.ssm_a | [48] | 48 | rank-1 SSM parameter, F32 |
| blk.N.ssm_dt.bias | [48] | 48 | rank-1 bias, F32 |
| blk.N.ssm_norm.weight | [128] | 128 | rank-1 norm, F32 |
| blk.N.ssm_conv1d.weight | [4, 10240] | 4 | rank-2 F32, conv_kernel=4 rows |

Plus the rank-1 norm class at dim0=5120 (numerically aligned but
rank-1): output_norm.weight, per-layer attn_norm /
post_attention_norm (x64 each). Total kept: 353 F32 tensors,
10,582,016 B of payload.

### Fallback table (decided from the audit, before conversion)

Policy = llama.cpp file_type 15 (Q4_K_M) as transcribed in QC-5
(use_more_bits over n=64 layers), gated PER TENSOR on
dim0 % 256 == 0 (the QC-5 risk-1 rule):

| case | decision |
|---|---|
| output.weight, dim0%256==0 | Q6_K |
| blk.i.attn_v / ffn_down, use_more_bits(i,64), dim0%256==0 | Q6_K |
| any other rank>=2 matrix, dim0%256==0 | Q4_K |
| K designee, dim0%256!=0 but dim0%32==0 | Q8_0 fallback (llama: Q6_K->Q8_0 exactly; Q4_K->Q5_0 in llama, but no Q5_0 writer exists in this workstream — Q8_0 is the named substitute, per-row valid in every reader) |
| K designee, dim0%32!=0 | keep at source type (llama: F16; keeping the F32/Q8_0 source is never worse and never invents data) |
| rank-1 / norm / bias (any dim0) | keep at source type (QC-0 section 3) |
| ssm_conv1d.weight [4, 10240] | keep F32 — QC-0 section 3 verbatim: conv1d stays F32, full stop (a named deviation from llama-quantize, which would F16 it) |

Instances in THIS file: the Q8_0-fallback and keep-for-shape rows
fire ZERO times — every designee is 256-aligned. The table is
nevertheless implemented and fixture-proven (stage 2), because
the converter must be honest on any file of this class.

### Predicted product (policy-exact, from the census)

Q4_K: 457 tensors, 22,727,884,800 el -> 12,784,435,200 B
Q6_K: 41 tensors (output + 40 upshifted attn_v/ffn_down),
      4,165,468,160 el -> 3,416,985,600 B
kept F32: 10,582,016 B; header/metadata: 11,183,424 B
PREDICTED TOTAL: 16,223,186,240 B (~16.22 GB; the QC-0 plan's
15.13 GB figure priced every element at the flat Q4_K rate
without the file_type-15 Q6_K upshifts; the vault's 16 G MTP
Q4_K_M brackets the policy-exact prediction).

## STAGE 2 — streaming K converter (built + fixture-proven)

Code (this branch):
- core/dequantize_input.mojo: Q8_0 (type 8) wired into the
  dequantizing input path, decoded directly from the engine's own
  block layout (f16 d @0 of each 34 B block, int8 qs @2..34,
  value = q * d, F32 out). packed_value has no Q8_0 kind — its
  fallthrough is the Q4_K/Q5_K layout — so the kind is decoded in
  dequantize_value_f32 itself, never through that fallthrough.
- cli/quantize.mojo: q4_k_m_plan_qc6 (file_type-15 policy gated
  per tensor on dim0 % 256 == 0, with the stage-1 fallback table)
  and quantize_gguf_q4_k_m_streaming_qc6 (QC-3b streaming writer +
  per-row values via _read_row_f32 -> QC-5 packers / QC-2 Q8_0
  fallback quantizer -> streamed payload). The CLI's --streaming
  refusal for q4_k_m is removed; --to q4_k_m --streaming now runs
  this converter. Peak heap is O(largest row + header): rows are
  at most 17,408 F32 (70 KB) on the 27B.
- Deliberate expectation update (Q35-3b precedent):
  test_dequantize_input_qc_3b asserted type 8 refused (true in
  QC-3b, whose census needed no Q8_0 reader). QC-6 wires it, so
  the assertion now asserts support, with the citation in the
  test source. Rerun: ALL PASS.

Fixture proof (test_quantize_streaming_qc_6, ALL PASS,
qc-6-test.log):
- A: Q8_0 dequant kind exact on hand-built blocks (signed lanes
  at d=0.5, a d=-2.0 block, a cross-block range).
- B: the plan — Q6_K for output + use_more_bits attn_v/ffn_down
  at n=64; Q4_K elsewhere; Q8_0 fallback for dim0=64 designees
  (both Q4_K and Q6_K classes); keep-at-source named for
  dim0=172 (not a multiple of 32), ssm_conv1d, rank-1, and
  unwired source types.
- C: stories260K through the streaming K path under the tiling
  rule. NO stories matrix is 256-aligned, so the fallbacks carry
  the whole model: 32 matrices -> Q8_0 fallback, 5 ffn_down
  (dim0 172) kept F16, 11 norms kept F32. The product is
  PAYLOAD-IDENTICAL to QC-3b's proven streaming Q8_0 product,
  tensor by tensor (only general.file_type differs: 15 vs 7).
  Admission, all three readers: GGUFSeer VALIDATED; PackedGGUF
  CONSTRUCTS (the admission QC-5's flat-tiled product was
  refused — the fallbacks make every row shape valid); the
  engine generates TOKEN-IDENTICALLY to the QC-3b product.
  llama.cpp also loads the product and generates (exit 0,
  qc-6-stories-llama.log). CLI end-to-end product is
  byte-identical to the test product (cmp exit 0).

Regressions (run-qc-6-tests.sh, all rerun from this tree):
engine compile exit 0; QC-1 writer ALL PASS; QC-2 ALL PASS;
QC-3a conversion ALL PASS + CLI product sha256 5d4df894... (the
banked value) + grade CSV byte-identical to banked qc-3-grade.csv
(diff exit 0); QC-3b dequant ALL PASS (after the cited update),
streaming writer stories exit 0, gemma conversion reproduces the
banked product sha256 a63bde43... and its load proof ALL PASS;
QC-5 K harness ALL PASS; QC-5 model conversion ALL PASS;
Q35-1 loader ALL PASS.

Contention note: stage-2 builds/tests ran while the Q35-6
sibling serve was still active (1 core); no timings claimed
from that window. The sibling serve exited before stage 3
(MemAvailable 124.6 GB at stage-3 start); the QC-6 heavy runs
waited for it, per the brief's serialize rule.

## STAGE 3 — the 27B conversion + admission + grade

### Conversion (detached unit qc6-convert, MemoryHigh=56G /
### MemoryMax=64G, machine clear — sibling serve had exited)

Command: aesir quantize <source> <product> --to q4_k_m --streaming
(run-qc-6-convert.sh; qc-6-convert.log / qc-6-convert-time.log)
- Wall time: 3:21.30. Exit 0.
- Report: quantized=498 kept=353; quantized_source_bytes=
  28,574,187,520; quantized_output_bytes=16,201,420,800
  (== the stage-1 policy prediction to the byte); kept 10,582,016 B.
- Emitted types: 457 Q4_K + 41 Q6_K (output.weight + 40
  use_more_bits attn_v/ffn_down) — the census of the product
  (qc-6-census-product.log) agrees exactly; ZERO Q8_0 fallbacks
  fired and ZERO shape keeps fired on this file, as the audit
  predicted. Kept reasons: 305x rank-1 class, 48x ssm_conv1d.
- Product: /mnt/vault/models/gguf/Qwen3.8-27B-Ultimate-Heretic-
  Uncn-Turbo-Brilli-50x-AGI-NEO-Q4_K_M.gguf (NOT committed)
  16,223,236,576 B = 56.7% of the 28,596,003,296 B source
  (prediction 16,223,186,240 + 50,336 B of inter-tensor
  alignment padding). sha256
  4515cac669491b4b7a8d6060e6d6e553b35ead74247369aa5cec6c41a7fc04cc
- Peak RSS 27,976,676 KB (~28.0 GB), with MemAvailable moving
  only 124.89 -> 124.86 GB across the run: the RSS is almost
  entirely reclaimable mmap file pages of the source (faulted
  in as read); the converter heap stays O(largest row) by
  construction. Both numbers recorded, neither hidden.

### Registry admission (the QC-0 QC-6 deliverable)

core/model_registry.mojo: qwen35_quantization_supported now
admits Q4_K_M beside Q8_0, scoped to qwen35, with the evidence
cited in the docstring; supported_quantizations reads
"Q8_0, Q4_K_M". test_qwen35_registry_q35_2 updated deliberately
(Q4_K_M admitted, Q5_K_M still refused; a2 case: file_type 15
classifies READY) — rerun on the real file: ALL PASS
(qc-6-registry-test.log).

### Admission — all four readers on the product

- GGUFSeer: VALIDATED (grade/gen logs: "GGUF validated: 851
  tensors, 48 metadata entries, architecture qwen35").
- PackedGGUF: constructs — registry inspect runs on it:
  "Tensor validation: passed".
- Registry inspect (qc-6-inspect-product.log): Quantization
  Q4_K_M, Compatibility COMPATIBLE, Status READY (source:
  READY / Q8_0, qc-6-inspect-source.log).
- llama.cpp: loads the product (exit 0, qc-6-llama-product.log)
  and generates; its readback agrees with the product census.
- Engine forward (U-QC3 SETTLED): the qwen35 CPU forward
  executes the product's Q4_K/Q6_K tensors end-to-end through
  the default packed path — the full grade and generation below
  are that execution. No packed-path sub-slice was needed.
- Load-mode honesty: the product does NOT load through the
  Q35-3r resident contract (validate_qwen35_resident is
  Q8_0-only and refuses the product BY NAME — proven when a
  driver argv bug loaded it resident: "resident Q8_0 load
  refused tensor blk.0.ffn_gate.weight: stored GGML type 12 is
  not Q8_0"). The product's executed path is the default packed
  path: quantized tensors still map as zero-copy packed views
  (no F16 materialization — the 19.5 GB footprint below is the
  proof), only the Q8_0-only enforcement contract does not
  apply. A Q4_K_M resident-analogue contract is QC-7/Q35-7
  work, named in the risks.

### Grade (Aesir CPU vs CPU, RESIDENT source vs product,
### Q35-3b stream: 6 RAW prompts, 198 records, identical IDs)

Harness: grade_qwen35_qc_6 (the Q35-3b oracle driver + load-mode
argument), banked parity arithmetic, band rank <= 2 AND
gap < 1.0. Pipeline sanity first: the SOURCE graded against
the banked llama.cpp rows reproduces Q35-3b v2 exactly —
198/198 in band, rank-1 at 197, worst gap 0.015 — so the
pipeline measures what the campaign measured.

Product vs source (qc-6-grade-summary.log, qc6_crossgrade.py):
- in-band 197/198 = 99.49%; argmax agreement 190/198 = 95.96%
- rank distribution {1: 190, 2: 7, 3: 1}; worst gap 0.421
- per prompt (records / in-band / agree): p0 4/4/4, p1 18/18/18,
  p2 30/30/29, p3 59/59/59, p4 38/38/37, p5 49/48/43
- the ONE out-of-band record, named: p5 pos 22 — rank 3
  (band is <= 2), gap 0.421 (well inside the gap bound);
  source argmax 1817, product argmax 17454, true token 89240.
- VERDICT by the strict gate rule: DIVERGENT (not FAITHFUL) —
  one rank-3 record of 198. Context, stated plainly: this is
  the strongest K-tier grade in the workstream (QC-5's true-
  Q4_K_M on stories: 154/157, worst gap 2.054), and the gap
  magnitude here (worst 0.421) is five times tighter; the
  divergence is a single near-tie class record, not a
  structural one. No re-band is claimed.

### Generation witness (product, greedy, prompt 0, 40 tokens)

GEN IDS: 11751 13 271 4639 579 4252 0 11751 369 279 6511 321
7526 3177 314 9338 13 1049 369 3750 364 1141 8807 3712 11 7431
11 1880 11 321 25438 57902 1680 430 279 242476 300 21262 11 279
Text: " Paris.\n\nThat's correct! Paris is the capital and
largest city of France. It is known for its rich history,
culture, art, and iconic landmarks such as the Eiffel Tower,
the" — coherent, factual, on-prompt. The source's own greedy
(qc-6-gen-source.log, token-identical to Q35-3b's banked
witness) reads " Paris.\n\nThat is correct. **Paris** is the
capital and most populous city of France..." — the product's
wording diverges from the source's greedy path (as the 95.96%
argmax agreement prices) while staying coherent: a divergence
named, not hidden.

### Residency note (for QC-7 / Q35-7)

Measured peak RSS of a full load + forward (time -v):
- Q8_0 source, resident path: 30,998,948 KB (grade p3) /
  30,999,304 KB (gen) — the ~31.0 GB class Q35-3b recorded.
- Q4_K_M product, default packed path: 19,536,880 KB (grade
  p3) / 19,537,308 KB (gen) — ~19.5 GB.
- Saving: ~11.46 GB of resident footprint (-37%) for a stored
  saving of 12.37 GB (-43.3%). Serve-coexistence math for
  Q35-7: product load ~19.5 GB + qwen35 KV at ctx 8192
  536,870,912 B (~0.54 GB, registry memory plan) leaves the
  product servable beside a second 27B-class resident on this
  121 GB box where two Q8_0 residents (2x ~31 GB + pools)
  were the previous budget unit; on a 32 GB-class device the
  product fits where the source does not.

### Stretch — NOT taken, named as remaining

ggml's searched fit (make_qkx2_quants) replacing QC-5's plain
fit was conditioned on stages 1-3 landing clean; the grade's
strict-gate verdict is DIVERGENT (one record), so the stretch
is named remaining work, with its target measured: does the
searched fit move p5 pos 22 (rank 3, gap 0.421) into band, and
what does it do to the 190/198 agreement? That is a QC-7/
QC-8-class slice (a searched packer + re-grade), not hidden
scope here.

### Named risks for QC-7 / Q35-7

1. RESIDENT CONTRACT: Q35-3r's gate is Q8_0-only. The product
   serves today only through the default packed path; a
   Q4_K_M resident-analogue contract (validate the K census +
   report the mode in health, Q35-3r style) is required before
   any "resident Q4_K_M" claim or gate swap (Q35-7).
2. SERVE SMOKE NOT RUN: QC-6 graded through the driver, not
   the serve surface; the two-turn serve smoke in the QC-0
   deliverable text belongs with Q35-7's gate work (the serve
   was down by Volmarr's order throughout this slice).
3. SEARCHED FIT (stretch above) is the known quality lever if
   QC-7 wants the strict gate green at this tier.
4. Rope sections at serve-length contexts (carried from
   Q35-3b R1): the grade stream is short (<= 60 positions);
   nothing here re-witnesses long-context behaviour of the
   product.
5. The product file lives only on the vault
   (4515cac6...fc04cc); it is reproducible byte-for-byte from
   the pinned source + this branch's converter (deterministic
   plain fit), but QC-7 should record it in the model store
   deliberately, not by rediscovery.

## LEDGER DRAFT ENTRY for QC-6 (for the coordinator to fold in)

QC-6 — the 27B Q8_0 heretic -> Q4_K_M, DONE on yrsa/qc-6.
Census: all 498 Q8_0 tensors dim0 % 256 == 0; only exceptions
are the F32 kept class (353: 305 rank-1 + 48 ssm_conv1d [4,
10240], kept F32 per QC-0 s.3). Streaming K converter built
(QC-3b writer + dim0 tiling gate + llama-style fallbacks;
Q8_0 dequant wired into the input path); stories fixture:
fallbacks carry the whole model, product payload-identical to
QC-3b's proven Q8_0 product, PackedGGUF constructs, engine
generates token-identically. 27B conversion: 3:21 wall, peak
RSS 28.0 GB (mmap pages; heap O(row)), product
16,223,236,576 B (56.7% of source; policy prediction exact),
sha256 4515cac6...fc04cc, on the vault (not committed).
Registry: qwen35 admits Q4_K_M (scoped, evidence-cited);
inspect READY/COMPATIBLE; GGUFSeer VALIDATED; llama.cpp
loads. Grade vs Q8_0 source (Aesir CPU-vs-CPU, Q35-3b 198-
record stream): in-band 197/198 = 99.49%, agreement 95.96%,
worst gap 0.421, one out-of-band record (p5 pos22, rank 3) —
verdict DIVERGENT by the strict gate, the strongest K-tier
grade in the workstream. Generation witness coherent.
Resident footprint 31.0 GB (source) -> 19.5 GB (product).
U-QC3 settled: the qwen35 forward executes Q4_K_M. Remaining:
Q4_K_M resident-analogue contract + serve smoke (Q35-7),
searched-fit packer (named stretch, not taken). Full notes:
QC-6-NOTES.md.
