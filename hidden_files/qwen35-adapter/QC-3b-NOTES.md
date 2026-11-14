# QC-3b — gemma-4-E2B Q4_K_M -> Q8_0 whole-model conversion + grade

Worker slice, banked in stages on branch yrsa/qc-3b from
origin/yrsa/hip-serve 59fb186e. Method note: ONE worker ran the
six Forge roles sequentially (no sub-agents; depth limit), stages
banked per stage: stage 1 8edb467e, stage 2 fed289d1, stage 3
this commit. All numbers below are from files/logs on disk in
this folder, never from a summary.

## Machine state / contention timeline (honest record)

- Slice start 2026-11-14 ~15:45 EST: purpleraider up 5h44,
  MemAvailable ~24 GB; sibling Q35-6 worker's `aesir serve` of
  the 27B Q8_0 was ACTIVE (RSS ~25 GB, 99% CPU) — contention
  present during recon and the stage-1 builds; recorded, no
  timings claimed from that window.
- By ~15:51 EST the sibling serve had exited; MemAvailable
  ~124.9 GB. Every heavy run after that (conversion, load
  proof, grades) ran uncontended, one at a time, fenced
  MemoryHigh=24G / MemoryMax=32G via user systemd units.
- Services aesir-gate / Ollama / Voxta were DOWN by Volmarr's
  order at slice start and were left down (verified not
  running). The 16 GB MTP Q4_K_M of the other variant in the
  vault was never touched.

## Source pin

/home/volmarr/aesir-forge/.aesir/models/gemma-4-E2B-it-Q4_K_M.gguf
3,106,738,272 B, sha256
740185b21d22ceb83a11c3aa62ad5842ef32c70f6096d756bbee85a1e4ec34b8
— the QC-0 catalog pin, re-measured and confirmed this slice
(also re-verified by the conversion run itself).

## Stage 1 — streaming writer (prerequisite build 1)

loader/gguf_writer.mojo extended, in-memory API untouched:
header/KV/directory construction factored into
build_gguf_header_bytes (shared by build_gguf_bytes and the new
path); GGUFStreamWriter writes the header first, then accepts
tensor payloads per-tensor in directory order through
write_chunk (1 MiB flush buffer), refusing overrun, short, and
out-of-order writes. Peak memory is O(largest tensor chunk),
not O(file).

Proof (test_gguf_writer_streaming_qc_3b, ALL PASS):
- synthetic 3-tensor model: streamed bytes == in-memory bytes;
  refusal paths fire.
- stories260K: streaming copy byte-identical to the in-memory
  emission AND to the source (sha 57a81ed1...).
- gemma E2B header-copy re-emission through BOTH paths
  byte-identical to the source file (sha 740185b2..., cmp
  clean) — 601 tensors, all 56 KVs incl. array values.
- Peak RSS on that gemma re-emission (/usr/bin/time -v):
  in-memory 9,049,800 KB (~8.63 GiB) vs streaming 3,087,116 KB
  (~2.94 GiB). The streaming figure is ~ the mmap source
  residency alone; ~5.96 GB of heap (payload descriptors +
  output buffer) is avoided. Wall 6.40 s vs 3.36 s is
  correctness context only.
Logs: qc-3b-build-stage1*.log, qc-3b-stream-*.log,
qc-3b-gemma-{mem,stream}*.log, qc-3b-gemma-copy-sha.log,
qc-3b-rss-mem.log, qc-3b-regress-qc-1.log.

## Stage 2 — dequantizing input path (prerequisite build 2)

New module core/dequantize_input.mojo: checked dispatch over
the engine's OWN dequantizer core/packed_quantization
.packed_value (the same code the forward path reads with).
Covered exactly the E2B census types: dense F32 (kind 0),
F16 (1), BF16 (30) widened, and Q4_K (12), Q5_K (13), Q6_K
(14) dequantized element-wise to F32 (no F16 intermediate, so
QC-2 finding F-1's range limit does not apply). Every other
GGUF type is refused BY NAME via dequant_input_keep_reason
(kept-by-policy with the reason string).

Proof (test_dequantize_input_qc_3b, ALL PASS): hand-built
256-lane blocks per K type; every lane exact vs the longhand
documented formula plus literal hand-computed lanes (Q4_K
14.25 / 96.75 / 87.25 incl. the g>=4 packed scale/min
reconstruction; Q5_K 94.25 / 124.25 with high bits; Q6_K
50.0 / -18.0 with signed scales); dense widenings exact;
unwired types (2,3,6,7,8,9,10,11,15,20,23) refused by name.
Coverage for E2B: covered = {F32, F16, BF16, Q4_K, Q5_K,
Q6_K}; kept-by-policy set for THIS model is EMPTY — the
census contains no other quantized type.

## Stage 3 — conversion

cli/quantize.mojo extended (QC-3a's quantize_gguf_q8_0 and
q8_0_keep_reason NOT modified): q8_0_keep_reason_dequant adds
the dequant-covered types to the quantize policy;
quantize_gguf_q8_0_streaming converts row-by-row (one row of
F32 -> per-row quantize_q8_0 -> stream writer), kept tensors
copied in 64 KiB chunks; CLI gained --streaming (default
in-memory path untouched). Policy as QC-3a: rank-2 weights
with dim0 % 32 == 0 quantize; rank-1 norm/scale class stays;
anything else stays and is NAMED in the run report.

Streaming-converter byte proof: `aesir quantize --streaming`
on stories260K emits sha256 5d4df894e4ed0d16f84d94c0a2a7524
a4915123fe96148dc0e41b7bc1a6d77b7 — byte-identical to QC-3a's
banked in-memory emission (qc-3b-stories-stream-sha.log).

E2B conversion (run-qc-3b-convert.sh; uncontended; 33.59 s
wall; peak RSS 3,066,060 KB ~ 2.92 GiB — again ~ source mmap
residency; the converter's own heap stayed row-sized):
  SUMMARY quantized=318 kept=283
          quantized_source_bytes=3089747968
          quantized_output_bytes=4937605120
          kept_bytes=1169548
Emitted: hidden_files/qwen35-adapter/gemma-4-E2B-it-Q8_0.gguf
(NOT committed; *.gguf git-ignored), 4,954,595,424 B, sha256
a63bde439cf22226df55e1ef937c656c71a801e34c721290c8d1cfeb962a36d1.
All 283 kept tensors carry the one reason class
"one-dimensional tensor (norm/scale/bias class) stays at
source type" — zero dim0 keeps, zero dequant keeps.

HONEST SIZE FRAMING: the emitted file (4.95 GB) is LARGER
than the source (3.11 GB, +59.5%). That is expected and is
not a defect: Q8_0 (~8.5 bits/element stored) is a less
dense tier than the Q4_K_M mix (~4.5-6 bits/element). This
slice proves the dequantize -> widen -> requantize machinery
at whole-model scale into the campaign's proven-fidelity
tier; it is not a size win over Q4_K_M, and no smaller file
was ever the deliverable.

### Census, both sides (independent Python parse agrees with
### the Mojo directory/policy checks)

source (file_type 15, 601 tensors, 56 KVs, data_offset
15,819,776, total elements 4,647,450,147):
  F32  x353   111,270,028 B  (283 rank-1 norms/scales + 70
                             rank-2 inp_gate/proj)
  BF16 x1      27,525,120 B  (per_layer_model_proj.weight)
  Q4_K x212 1,121,845,248 B
  Q5_K x1   1,614,807,040 B  (per_layer_token_embd.weight,
                             2,348,810,240 elems)
  Q6_K x34    215,470,080 B  (attn_v + ffn_down, alt. layers)
emitted (file_type 7, 601 tensors, 56 KVs, data_offset
15,819,776, total elements 4,647,450,147 — identical):
  F32  x283     1,169,548 B  (the rank-1 class, verbatim)
  Q8_0 x318 4,937,605,120 B
Every rank-2 source tensor had dim0 % 32 == 0 (dim0 set
{256,1536,2048,4096,6144,8960,12288}); the only dim0-not-
mult-32 tensors in the model are the 35 rank-1
layer_output_scale.weight [1], kept by the rank-1 rule.

### U-QC4 — settled at copy+convert+emit level

The conversion exercises gemma4 metadata re-emission at
whole-model scale: the load-proof test asserts the emitted
header's 56 KVs are identical to the source's except
general.file_type 15 -> 7, array values carried raw. Any KV
the path could not carry would have stopped the conversion
with a named error; none did. U-QC4 is settled for the
copy+convert+emit path (it says nothing about serving).

## Load proof (test_quantize_gemma_qc_3b, ALL PASS)

- Metadata identical except general.file_type 15 -> 7
  (56 KVs, arrays carried raw).
- Directory preserved; every emitted tensor's type matches
  the QC-3b policy; all payload offsets 32-aligned.
- PackedGGUF constructs in full on BOTH files (601 tensors;
  offsets/kinds/byte counts agree).
- GGUFSeer mmap_and_load: BOTH files reach VALIDATED
  (arch=gemma4, tensors=601, kvs=56, vocab=262144) — loader
  admission identical.
- QC-2 bound probes on sampled rows (0 and rows//2) of six
  tensors spanning every source class — token_embd (Q4_K),
  per_layer_token_embd (Q5_K), blk.0.ffn_down (Q6_K),
  blk.0.attn_q (Q4_K), per_layer_model_proj (BF16),
  blk.0.inp_gate (F32): all inside the proven bound, worst
  err/bound 0.792 / 0.796 / 0.798 / 0.797 / 0.794 / 0.848 —
  the same family as QC-2's and QC-3a's probes.
Log: qc-3b-loadproof.log (exit 0).

## Admission comparison — FINDING F-3b-1 (named, unfixed)

Loader admission is identical (above). REGISTRY admission is
NOT: `aesir inspect` files the source READY / VERIFIED
("Matched a native Gemma 4 variant profile", quantization
Q4_K_M) and the emitted file NOT READY / UNSUPPORTED with
reason "The Gemma 4 adapter does not support this GGUF
quantization" — the gemma4 variant profile's supported-
quantizations list (Q4_K_S, Q4_K_M, Q5_K_S, Q5_K_M, Q6_K,
F16, BF16, F32) does not include Q8_0 (qc-3b-inspect-source
.log, qc-3b-inspect-q8.log). So for gemma4, conversion DOES
change registry admission, the mirror image of QC-3a's
F-3a-1 (where admission was identically refused on both
sides). The emitted file's working path today is the
loader/engine path, not registry admission. The fix is a
profile-side change (admit Q8_0 for gemma4, whose engine
kernels already read Q8_0 — proven by the load proof and by
Q35-3r's Q8_0-resident path); profile/reader edits are out
of this slice's scope, so it is named here, not made.

## FINDING F-3b-2 (toolchain, probe-side only)

In this Mojo build, UInt16(UInt8(Int8 load)) can fold into a
SIGN-EXTENDED widening (observed d_bits 0xFF9F for the true
bytes 0x9F 0x13), producing a NaN f16 scale and a spurious
bound violation in the first load-proof run. The emitted
file was never wrong: independent Python dequant of the
exact block showed the lane inside the bound (err 0.00042 <
bound ~0.00058) before the probe was fixed. Durable rule:
materialize mmap bytes through a List[UInt8] (a real UInt8
store) before widening — the pattern QC-3a's probe already
used. The debug trail is in qc-3b-dbgprobe*.log.

## Grade

### Aesir attempt (bounded, recorded exactly)

grade_quantize_qc_3 (the QC-3a harness, arch-generic) was run
on the pair (qc-3b-aesir-attempt.log, exit 1): it LOADED
both models (gemma4, 35 blocks, vocab 262144), tokenized all
6 prompts, and reported TOKENIZER PARITY on the emitted
file; grading then raised "NearTieGate: rank and gap must be
non-negative" and produced no CSV. `inspect` reports gemma4
CPU support: no (CUDA: yes) — the CPU forward for this arch
is not a supported path, and its rows are not gradeable.
Per the brief's named fallback, the grade below is llama.cpp
on BOTH sides, with the Aesir side standing as load-proof
only. The substitution is named, not hidden.

### llama.cpp grade (CPU vs CPU, raw token IDs)

Harness: qc3bstream tokenized 6 RAW prompts ONCE with the
SOURCE model's llama.cpp tokenizer (add_bos=true) and took
the source's greedy 16; qc3bgrade dumped full logit rows
(vocab 262,144) for both models on those identical streams;
qc3b_crossgrade.py filed the campaign record (rank + gap of
the comparator's argmax in the candidate's row; band rank
<= 2 AND gap_milli < 1000). 79 records.

AGGREGATE: exact 73, near-tie 5, divergent 1; in-band
78/79 = 98.73%; argmax agreement 73/79 = 92.41%; worst
in-band rank 2, worst gap_milli 587 (max gap 1489, the
divergent record). Prompt segment 44/44 in band;
continuation segment 34/35.
Per prompt: p0 8/8, p1 9/9, p2 11/11, p3 14/14, p4 11/11,
p5 25/26 in band.
Named records: prompts 0/2/4 pos 1 share one recurring
near-tie (comparator argmax 50134 vs candidate 106, rank 2,
gap 587 milli — in band). The ONE divergent record:
prompt 5 pos 24, rank 1, gap 1489 milli — comparator argmax
5756, candidate argmax 31225.

VERDICT: NOT FAITHFUL under the campaign's strict gate rule
(every record in band): 78/79 in band, one rank-1 record
whose gap (1.489) exceeds the 1.0 band. Everything else —
including all 44 prompt-segment records — is in band, and
the single out-of-band record is a near-tie coin-flip of
the same class QC-3a/QC-4 recorded, not a structural
divergence.

Greedy witness (qc3bgrade GEN lines): prompts 0-4
token-identical between source and Q8_0 (each completes
factually then emits <turn|>: "Paris.", "oxygen.", "lazy
dog.", "mix the ingredients together.", "Jupiter.").
Prompt 5 is identical for 14 generated tokens, then first
diverges at generation step 15 — source 5756 ("fresh") vs
Q8_0 31225 ("damp"): "...the air smelled of pine and
fresh/damp earth" — the same position as the divergent
grade record; both continuations are coherent.

HONEST FRAMING (required): the source is itself quantized.
This grade prices the dequantize -> requantize round trip
Q4_K_M -> F32 -> Q8_0, NOT compression from a float
original; there is no float E2B reference in the campaign.
The pairing is also same-engine (llama.cpp) on both sides
by design: it prices the CONVERSION, not engine parity.
Aesir-side evidence for the emitted file is the load proof
above, not a forward grade.
Logs: qc-3b-stream-build.log, qc-3b-grade-{src,q8}.log,
qc-3b-crossgrade.log, qc-3b-gen-llama-{src,q8}.txt,
qc-3b-{streams,prompts}.txt, rows in qc-3b-rows-llama-*.bin.

## Regressions (rerun from this tree, run-qc-3b-regress.sh)

- Engine compile exit 0 (qc-3b-build-stage3.log).
- QC-1 writer test ALL PASS; QC-2 quantizer test ALL PASS;
  Q35-1 loader test ALL PASS.
- QC-3a: conversion test ALL PASS; CLI in-memory emission
  sha256 5d4df894... (banked value); grade rerun exit 0 and
  its CSV is BYTE-IDENTICAL to banked qc-3-grade.csv
  (diff exit 0); summary verdict FAITHFUL (157 records,
  in-band 100%, agreement 156/157).
- QC-3b streaming + dequant tests rerun ALL PASS.

## Named risks / hand-offs

- QC-5 (Q4_K_M as TARGET tier): no K-quant PACKING writer
  exists (only dequantizers) — writing Q4_K/Q5_K/Q6_K
  payloads is new machinery, incl. the scale/min packing
  the stage-2 proofs exercised in reverse. llama-quantize
  is still absent from ~/llama.cpp-build (only llama-cli /
  llama-perplexity are built); QC-4 already named building
  it as QC-5's arbitration first step. The mixed-file
  file_type question (15) re-opens on the target side, and
  llama.cpp's per-tensor tier choice is imatrix-driven —
  policy must be decided, not assumed.
- QC-6 (27B): row-streaming is mandatory at that scale and
  is now proven (per_layer_token_embd alone: 2.35 B elems).
  The 27B is qwen35, not gemma4 — census first, do not
  carry gemma4 assumptions. Comparator cost (U-QC6): full
  logit rows at vocab 262,144 are ~1 MB per position;
  a 27B Q8_0 resident forward exceeds this slice's
  24G/32G fence — fence from measured headroom or reduce
  the record set deliberately. GGUFSeer pool sizing also
  needs checking at 27B metadata scale.
- F-3b-1 should be fixed (gemma4 profile admits Q8_0)
  before any "converted gemma model is serve-ready" claim;
  until then converted gemma files are loader-grade only.
- F-3b-2's materialization rule applies to every future
  probe that widens mmap bytes.
