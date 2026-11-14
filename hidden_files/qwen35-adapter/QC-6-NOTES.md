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
