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
