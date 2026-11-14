# Qwen35 Adapter Campaign — Ledger

## 2026-11-14 — Q35-7: gate swap to the 27B + full-suite gate — DONE (worker slice; CAMPAIGN CLOSE)

Q35-7 — the closing slice, DONE on yrsa/q35-7 (base f3655d35).
Stage 1 (preconditions): F-4b-2 FIXED — the qwen35 sessions
(CPU + HIP mirror) stop on a stop set DERIVED from the model's
own tokenizer (eos 248046 <|im_end|> + 26 GGUF CONTROL entries
= 27 ids; type-4 user-defined tokens excluded, think blocks
unaffected); a stop token is forwarded but never emitted or
counted. The Q35-4b short-answer shape now halts at 4 emitted
tokens with clean text "\n\nhello", finish stop (was:
control-token spellings to the cap). F-4b-1 FIXED — one leading
role-marker block ("Assistant:" / "\nAssistant:" /
"\n\nAssistant:") trimmed in the sessions' presentation
path; served replies are byte-identical to the banked Q35-4b
replies after the marker (bench TRIM PROOF R1/R2/LONG).
A-119 successor attestation FILED beside (not over) A-048's
account: qwen35_successor_status ->
REAL_FILE_LOAD_PASS_ADAPTER_RESIDENT, existing test case
extended in place (905 count unchanged). /health gained
model_variant (qwen35-scoped, Q35-3r pattern; other profiles'
bytes unchanged). Stage 2 (swap): pre-swap gate configuration
backed up (hidden_files/hip-serve/aesir-gate-llama3-3b-
config-backup-q35-7.txt); VOXTA_SWITCHOVER.md updated (27B
resident primary, llama3-3b fallback + exact rollback); gate
serves the 27B Q8_0-resident CPU on :18434, fence
MemoryHigh=48G / MemoryMax=64G (measured VmHWM 31,616,528 kB);
bench ALL PASS on the gate (health truth incl.
model_variant=qwen35-27B, resident reuse 55, stateless
snapshot reuse 55, replies == reference, stop case clean);
gate left RUNNING on the 27B (health + completion re-verified
after the final restart). Stage 3 (suite): four fenced
build_matrix.sh amd runs; hip_config_gate failed run 1 and
was FIXED in scope (Q35-4a had added cpu to the admitted-
backend message; the HS-1 test expectation was stale — now
"auto, cpu, cuda or hip"; passes since). Final defended
count 900/905: the only failures are the two proven
pre-existing (gguf.tensor_directory_interface,
gpu.hip_q4k_gemv_no_leak — accounts untouched) and
resilience.state_vault_rejects_growth, an evidenced
scheduling-race flake (passes standalone 3/3 quiet + passed
in-suite at baseline; reproduced standalone under synthetic
32-core contention; no vault code touched by the campaign).
QWEN35_RESULTS.md filed in this folder; MAP.md completion
states updated. The Qwen35 adapter campaign is COMPLETE.
Named remaining work (in QWEN35_RESULTS.md): Q4_K_M resident
analogue + serve smoke, searched-fit packer, HIP decode
speed + native HIP admission, min_p/repeat_last_n on the
qwen35 path, gemma4 CPU forward.
- Coordinator verification (2026-11-14): suite summary
  re-read from the matrix log on disk (900 passed / 3
  failed / 2 skipped / 905 total; failures = the two
  proven pre-existing + resilience.state_vault_rejects_
  growth, named with its contention evidence); gate
  state checked live at merge time (aesir-gate active,
  auth-gated health answering); remote yrsa/q35-7 ==
  56c7d798 confirmed by ls-remote before merge; merged
  into yrsa/hip-serve (LEDGER conflict resolved keeping
  both the Q35-7 and QC-7 entries; six untracked build
  binaries in the coordinator seat moved aside to
  /home/volmarr/aesir-merge-aside-q35-7, recoverable)
  and banked. Post-merge gate restart from this tree
  follows VOXTA_SWITCHOVER.md.

- Post-merge gate restart (coordinator, 2026-11-14):
  per VOXTA_SWITCHOVER.md, the merged tree was rebuilt
  in aesir-hipserve (ENGINE_BUILD_EXIT=0; binary
  5,013,536 B, byte-size identical to the q35-7 build)
  and aesir-gate was restarted from
  /home/volmarr/aesir-hipserve with the two paths
  swapped, all other unit properties unchanged
  (MemoryHigh=48G/MemoryMax=64G, resident, ctx 4096,
  :18434). Verified live by the coordinator: unit
  active; startup log carries GGUF validated (851
  tensors) + resident load q8_0_resident (498 large
  tensors) + admission=native; authenticated /health
  reports profile qwen35, model_variant qwen35-27B,
  weight_load_mode q8_0_resident, session_residency
  true, exact_prefix_reuse true; a live completion
  returned clean text (no marker, no control-token
  leakage) with truthful finish accounting. The gate
  stands RUNNING on the 27B from the merged tree.
  (The auxiliary test_hip_prompt_prefix build in
  build-1.sh exits 1 in this tree on the known -I
  include-path quirk build-3.sh already carries the
  fix pattern for; the engine build is unaffected.)

## 2026-11-14 - QC-7: QC_RESULTS.md + residency note - DONE (worker slice; verified + banked by coordinator)

QC-7 - the compression workstream results record, DONE on
yrsa/qc-7 (records only; no engine code changed). Deliverables
in this folder: QC_RESULTS.md (what Aesir learned to do with the
module map; the per-tier per-model verdict table with verdict
words exactly as banked - stories Q8_0 FAITHFUL, gemma E2B Q8_0
NOT FAITHFUL, stories Q4_K_M ours DIVERGENT vs llama.cpp
FAITHFUL with zero K tensors, 27B Q4_K_M DIVERGENT by the strict
gate at 197/198 in band; size-vs-quality summary; the flat vs
per-row tiling law with the dim0 % 256 gate and fallbacks; named
remaining work) and RESIDENCY-NOTE.md (sibling file, chosen so
Q35-7 can cite/update it without touching the closed results
record: source resident ~31.0 GB vs product packed ~19.5 GB, KV
~0.54 GB at ctx 8192, Q35-4b serve peak ~31.3-31.6 GB class,
Q35-6b HIP serve VmHWM ~30.1 GB). Model store record: four
products RE-VERIFIED by sha256 on-device in QC-7 (27B Q4_K_M
4515cac6...fc04cc, gemma E2B Q8_0 a63bde43..., stories Q8_0
5d4df894..., stories Q4_K_M ours 068a41c7..., plus sources
banked-only as marked); two sha256 values absent from the notes
(llama.cpp stories product, QC-6 stories fallback product) are
recorded as NEW QC-7 measurements, not banked values. No number
was excluded as untraceable. MAP.md QC completion states updated
in the same slice. A sibling Q35-7 entry may land above this one
at merge time - expected.

- Coordinator verification (2026-11-14): QC_RESULTS.md
  re-read from disk (verdict table present, per-product
  citations to their notes; the 27B Q4_K_M store row
  carries the full sha256 marked RE-VERIFIED); remote
  yrsa/qc-7 == 3024230a confirmed by ls-remote before
  merge; fast-forwarded into yrsa/hip-serve and
  banked. The QC compression workstream is COMPLETE:
  QC-0 through QC-7 all banked. Remaining named work
  (searched-fit packer, Q4_K_M resident analogue,
  gemma4 CPU forward) stands recorded in QC_RESULTS.md.

## 2026-11-14 — QC-6: the 27B Q8_0 heretic -> Q4_K_M — DONE (worker slice; verified + banked by coordinator)

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
- Coordinator verification (2026-11-14): product file
  stat-verified on the vault (16,223,236,576 B); grade
  numbers re-read from QC-6-NOTES.md on disk; remote
  yrsa/qc-6 == be544bb6 confirmed by ls-remote before
  merge; merged into yrsa/hip-serve (clean merge) and
  banked. The strict-gate DIVERGENT verdict stands as
  recorded: one record (p5 pos22, rank 3, gap 0.421)
  outside the band at 99.49% in-band — the searched-fit
  packer is the named lever, its measured target this
  record.


## 2026-11-14 — Q35-6: HIP execution for qwen35 + Q35-6b real-file HIP serve — DONE (worker slice; verified + banked by coordinator)

Q35-6 HIP execution for qwen35 — DONE. Fixture: corrected CPU
reference re-established (H1: prior HIP test sampled with
GenerationConfig defaults; pinned banked config), device
defects D1 (tiled q/k broadcast in _delta_kernel) + D2 (ring
shift race -> stage/commit via ring_tmp) fixed; trajectory
inside/at Q35-3a (c) band (s 0.0007150769, conv 0.0078125,
logits one f16 ulp over at rank 1 gap 0.0); greedy == corrected
CPU reference; batched prefill chosen (6.7x: 9.43 ms vs 63.16
ms at 64 tok). Qwen35HipSession (snapshot-composing,
CPU-mirrored contract) + experimental serve admission for
qwen35+hip (refusal without --experimental-qwen35 proven).
Fixture serve bench ALL PASS (resident reuse 72, stateless
snapshot reuse == resident reply). Q35-6b real 27B: grade
71/71 positions CPU-argmax rank 1 gap 0.0 (P0/P1/P5, incl. the
P5 pos-32 near-tie), 40-token greedy token-identical to the
banked llama.cpp-agreeing witness; HTTP serve ALL PASS
(health truth, T1 == CPU R1, resident T2 reused 55 + R2
prefix, stateless restore == T2, VmHWM 30.1 GB). T2 truncated-
T1 anomaly investigated to ground: model behavior on a
mid-sentence-truncated stream, not a defect (bisects all
bit-exact). Regressions Q35-1/2/3a/3r/4a/5 + ripple ALL PASS,
engine compile exit 0. Risks for Q35-7: naive GEMV bandwidth
(~11-14 s/token at 27B), native (non-experimental) admission
unclaimed, min_p/repeat_last_n unclaimed on qwen35 sampling,
F-4b-1/F-4b-2 carry-over.
- Coordinator verification (2026-11-14): q35-6b bench log
  re-read from disk (Q35-6b HTTP HIP real-file bench: ALL
  PASS); remote yrsa/q35-6 == 6c79d8cf confirmed by
  ls-remote before merge; merged into yrsa/hip-serve
  (clean merge, no conflicts) and banked. HIP decode
  speed (~0.07-0.09 tok/s naive GEMV) stands as the
  named Q35-7 consideration: the gate configuration
  decision (CPU-resident vs HIP-experimental) must weigh
  it honestly.


## 2026-11-14 — F-3b-1: gemma4 registry profile admits Q8_0 — FIXED (verified + banked by coordinator)

- Finding F-3b-1 from QC-3b is FIXED. Verdict on the exclusion:
  OMISSION — the gemma4 branch admitted via the shared
  native_quantization_supported list dating from the original
  registry commit (5ec8a956), predating any gemma4 Q8_0 file;
  no comment/test pinned a deliberate exclusion. Q35-2's
  qwen35-scoped Q8_0 admission is the house pattern; QC-3b
  supplied the first gemma4 Q8_0 evidence.
- Change (model_registry.mojo only): new scoped
  gemma4_quantization_supported() = shared native list + Q8_0;
  gemma4 branch uses it; supported list now names Q8_0.
  Shared lists NOT extended — llama Q8_0 still NOT READY
  (inspect proof). Serve planning (runtime_plan/cuda_chat)
  gates through the same registry inspect; memory pricing
  (gemma4_profile_memory_plan) is file-size based and priced
  the Q8_0 file at 5171679844 estimated VRAM bytes.
- Proofs: inspect emitted gemma-4-E2B Q8_0 NOT READY ->
  READY/COMPATIBLE (tensor validation passed); source Q4_K_M
  READY/VERIFIED unchanged; qwen35 27B READY unchanged.
  Engine compile exit 0; Q35-2 registry/profile tests ALL
  PASS (incl. registry case with new F-3b-1 assertions);
  gguf metadata suite: no new failures beyond the known
  gguf.tensor_directory_interface. Full record:
  F-3b-1-NOTES.md.
- Remainder named, untouched: gemma4 CPU support still "no"
  (forward gap from QC-3b), out of this slice's scope.

- Coordinator verification (2026-11-14): F-3b-1-NOTES.md
  + proof logs re-read from disk (Q35-2 registry tests
  ALL PASS incl. the new assertions; before-log carries
  the NOT READY line); remote yrsa/f-3b-1 == 2b08890c
  confirmed by ls-remote before merge; fast-forwarded
  into yrsa/hip-serve and banked. Cross-reference:
  QC-3b's F-3b-1 is CLOSED by the F-3b-1 entry above —
  converted gemma Q8_0 files now inspect READY/
  COMPATIBLE with the memory plan consuming them; the
  gemma4 CPU-forward gap remains named, unchanged.
## 2026-11-14 — QC-5: the Q4_K_M tier — K-quant packing writer, whole-model conversion + grade, llama.cpp arbitration (worker slice; verified + banked by coordinator)

- Stage 1: llama-quantize BUILT in ~/llama.cpp-build (target
  exit 0; llama.cpp at a956a85, the QC-4 referee commit) — the
  reverse-leg tool QC-4 named as missing now exists.
- Stage 2: K packer in core/quantize.mojo (quantize_q4_k /
  quantize_q6_k, ggml layouts 144 B / 210 B per 256). Mirrors
  ggml's structure; two NAMED simplifications (min/max fit
  instead of make_qkx2_quants; symmetric fit instead of
  make_qx_quants). Bounds proven and asserted elementwise;
  adversarial worst err/bound Q4_K 0.9989002, Q6_K 0.9686628.
  Harness ALL PASS.
- Stage 3a: CLI tier `--to q4_k_m` (file_type 15), policy
  transcribed from llama-quant.cpp (use_more_bits; layers 2,4
  for n=5). As applied: output + blk.2/4 attn_v + blk.2/4
  ffn_down -> Q6_K (5 tensors), 32 matrices -> Q4_K, 11 norms
  kept F32. CLI product byte-identical to the test product
  (sha256 068a41c7...). NAMED writer amendment: gguf_writer
  validators now check block-256 types by flat element_count
  % 256 (block-1/32 checks untouched; QC-1 proof still ALL
  PASS).
- Stage 3b: conversion proof ALL PASS. Emitted
  stories260K.Q4_K_M.gguf = 196,816 B (32.7% of the 601,248 B
  source; 51.9% of the Q8_0 product). Whole-model bound sweep
  worst Q4_K 0.99672973 / Q6_K 0.7372395 over 292,096 elements.
  GGUFSeer VALIDATED. ADMISSION FINDINGS (the slice's central
  result): the engine has two K consumption models — FLAT
  (GGUFSeer, packed_value, dequantize_input) vs PER-ROW
  (PackedGGUF, fused K GEMM, ggml). Our flat-tiled file is
  refused by PackedGGUF ("K-quant row is not block aligned"),
  by the AesirEngine forward ("gemm_q4_k_m: invalid shape or
  incomplete quantization block"), and inside registry inspect
  (same PackedGGUF refusal, exit 1; source inspect exits 0
  UNSUPPORTED on the pre-existing tokenizer mismatch).
- Stage 3c: grade of OUR product on its dequantized weight set
  (stock QC-3a driver; the K file itself cannot execute in the
  per-row forward): in-band 154/157 = 98.09%, agreement
  141/157 = 89.81%, worst rank 3, worst gap 2.054 — verdict
  DIVERGENT by the strict gate rule, honestly reported.
  Divergent records named: (p0,pos22) rank 3 gap 0.914;
  (p2,pos10) rank 1 gap 1.062; (p3,pos8) rank 1 gap 2.054.
- Stage 3d arbitration: llama-quantize's own Q4_K_M of the
  source contains ZERO Q4_K/Q6_K tensors — {Q5_0: 29, Q8_0: 3,
  F16: 5, F32: 11} under file_type 15 (per-row fallback,
  exactly as predicted), 304,096 B. Aesir grades it FAITHFUL
  (157/157, agreement 96.82%, worst gap 0.390); llama.cpp
  cross-grade agrees (157/157, 97.45%, worst gap 0.380).
  U-QC5 FOR FILE_TYPE 15: NO — llama.cpp refuses OUR file at
  gguf_init_from_reader ("tensor 'output.weight' of type 14
  (q6_K) has 64 elements per row, not a multiple of block size
  (256)"). file_type is not the blocker; flat tiling vs the
  per-row validity rule is.
- Regressions: engine compile exit 0; QC-1, QC-2, QC-3a,
  QC-3b (dequant + streaming synth/stories), Q35-1 proofs ALL
  PASS rerun from this tree; QC-3a grade rerun CSV
  byte-identical to banked qc-3-grade.csv; regenerated Q8_0
  product byte-identical to QC-4's (sha256 5d4df894...).
- QC-6 named risks: converter must gate on dim0 % 256 (per-row
  rule) for forward-admissible products; no streaming K
  converter exists yet (27B needs it); fit-simplification cost
  unmeasured at scale; no imatrix. Full notes: QC-5-NOTES.md.

- Coordinator verification (2026-11-14): QC-5-NOTES.md
  re-read from disk; the flagged gguf_writer amendment
  diff inspected line-by-line (block-256 types only,
  flat-pricing rationale commented, other checks
  untouched); remote yrsa/qc-5 == 5cfeff33 confirmed by
  ls-remote before merge; merged into yrsa/hip-serve
  (LEDGER conflict resolved keeping both the F-3b-1
  and QC-5 entries) and banked. Central finding stands:
  flat vs per-row K tiling — QC-6 inherits the
  dim0 % 256 == 0 gate + named fallbacks as its first
  design rule.

## 2026-11-14 — QC-3b: gemma-4-E2B Q4_K_M -> Q8_0 whole-model conversion + grade (worker slice; verified + banked by coordinator)

- PREREQUISITE 1 (streaming writer): GGUFStreamWriter in
  loader/gguf_writer.mojo — header first, per-tensor chunked
  payloads, in-memory API untouched. Byte proofs: synthetic
  streamed == in-memory; stories260K streaming copy identical
  to in-memory emission AND source; gemma E2B header-copy
  re-emission through BOTH paths byte-identical to source
  (sha 740185b2...). Peak RSS on the gemma re-emission:
  in-memory 9,049,800 KB vs streaming 3,087,116 KB.
- PREREQUISITE 2 (dequantizing input path):
  core/dequantize_input.mojo, checked dispatch over the
  engine's own packed_value. Covers exactly the E2B census
  types {F32, F16, BF16, Q4_K, Q5_K, Q6_K}; all other types
  refused by name. Hand-built 256-lane block proofs exact
  per type. Kept-by-policy set for E2B: EMPTY.
- CONVERSION (streaming path; cli/quantize.mojo extended,
  QC-3a function untouched; --streaming added): 318 tensors
  quantized, 283 kept — every keep the rank-1 norm/scale
  class, named; zero dim0 keeps, zero dequant keeps.
  Source 3,106,738,272 B (sha 740185b2..., pin confirmed)
  -> emitted 4,954,595,424 B, sha256 a63bde439cf2...,
  file_type 15 -> 7. Emitted is LARGER (+59.5%): Q8_0 is a
  less dense tier than the Q4_K_M mix — expected, framed in
  the notes. Streaming CLI on stories reproduces QC-3a's
  banked sha 5d4df894... byte-identically. Conversion peak
  RSS 3,066,060 KB, 33.59 s, uncontended.
- U-QC4 SETTLED at copy+convert+emit level: 56 KVs incl.
  arrays carried raw; emitted metadata == source except
  file_type (asserted by the load-proof test).
- LOAD PROOF ALL PASS: PackedGGUF constructs on both
  files; GGUFSeer VALIDATED on both (gemma4, 601 tensors,
  vocab 262144); QC-2 bound probes on 6 tensors spanning
  every source class, worst err/bound 0.79-0.85.
- FINDING F-3b-1 (named, unfixed): registry admission
  DIFFERS — aesir inspect: source READY/VERIFIED, emitted
  NOT READY/UNSUPPORTED ("The Gemma 4 adapter does not
  support this GGUF quantization"; the gemma4 profile's
  supported list omits Q8_0). Loader admission identical.
  Mirror image of F-3a-1; profile fix named for a future
  slice, out of scope here.
- FINDING F-3b-2 (toolchain): UInt16(UInt8(Int8 load)) can
  fold to a sign-extended widening in this Mojo build;
  materialize mmap bytes through List[UInt8] before
  widening. Probe-side only; Python arbitration proved the
  emitted file inside bound before the probe was fixed.
- GRADE: Aesir harness attempt recorded (both models loaded,
  tokenizer parity passed, then NearTieGate raised on
  non-negative rank/gap — gemma4 CPU forward is not a
  supported path, inspect CPU support: no). Fallback per
  brief: llama.cpp BOTH sides, raw token IDs from the start
  (qc3bstream/qc3bgrade/qc3b_crossgrade.py). 79 records:
  exact 73, near-tie 5, divergent 1; in-band 78/79 =
  98.73%; agreement 73/79 = 92.41%. VERDICT: NOT FAITHFUL
  under the strict gate rule — the one out-of-band record
  is prompt 5 pos 24 (rank 1, gap 1489 milli; 5756 "fresh"
  vs 31225 "damp"), also the greedy witness's first
  divergence (step 15 of prompt 5; prompts 0-4 identical).
  Framing: the source is itself quantized — the grade
  prices the dequant->requantize round trip, not
  compression from a float original.
- REGRESSIONS from this tree: engine compile exit 0;
  QC-1, QC-2, Q35-1 ALL PASS; QC-3a proof ALL PASS, CLI
  sha 5d4df894... reproduced, grade CSV byte-identical to
  banked qc-3-grade.csv (diff exit 0), verdict FAITHFUL.
- Contention honestly noted: sibling Q35-6 27B serve was
  active at slice start (recon/build window), gone before
  every heavy run. Full notes: QC-3b-NOTES.md.
  Next: QC-5 (Q4_K_M target tier — needs a K-quant packing
  writer + llama-quantize built) / QC-6 (27B).

- Coordinator verification (2026-11-14): QC-3b-NOTES.md
  re-read from disk (streaming byte-identity incl. the
  E2B re-emission at sha 740185b2; conversion
  3,106,738,272 -> 4,954,595,424 B; grade 78/79 in band
  = 98.73%, verdict NOT FAITHFUL under the strict gate
  rule, recorded as ruled); remote yrsa/qc-3b ==
  19ffe352 confirmed by ls-remote before merge;
  fast-forwarded into yrsa/hip-serve and banked.
  FINDING F-3b-1 stands as named next work: the gemma4
  registry profile omits Q8_0 from its supported list,
  so a converted gemma file is loader-grade only until
  the profile admits Q8_0 — fix before any serve-ready
  claim for converted gemma models.

## 2026-11-14 — QC-4: llama.cpp cross-check of the QC-3a compressed model (worker slice; verified + banked by coordinator)

- Determinism: `aesir quantize` from the merged tree reproduces
  the QC-3a file byte-identically — sha256
  5d4df894e4ed0d16f84d94c0a2a7524a4915123fe96148dc0e41b7bc1a6d77b7,
  379,152 B (qc-4-emitted-sha.log). No determinism finding.
- U-QC5 SETTLED (file_type 7 class): llama.cpp (upstream
  a956a852, native build at ~/llama.cpp-build) loads the MIXED
  file (32x Q8_0 + 5x F16 + 11x F32) with no warning or refusal;
  its loader census reads the true per-tensor mix and dispatches
  per tensor, the file_type label serving the ftype display
  only. F16 source control loads identically.
- Cross-grade (157 records, QC-3a streams, CPU-vs-CPU):
  (a) llama.cpp-Q8_0 vs llama.cpp-F16: in-band 157/157,
  agreement 157/157, FAITHFUL. (b) llama.cpp-Q8_0 vs
  Aesir-F16 (QC-3a reference): in-band 157/157, agreement
  157/157, FAITHFUL. Sanity llama-F16 vs Aesir-F16: 157/157
  argmax agreement.
- Greedy witness: llama.cpp Q8_0 == F16 token-identical on all
  6 prompts. QC-3a's prompt-2 step-3 divergence is NOT seen by
  llama.cpp: the same near-tie record (prompt 2 pos 10) has
  margin +0.0068 for the source winner in llama-Q8_0 vs -0.007
  in Aesir-Q8_0 — same coin-flip record, opposite side, both
  FAITHFUL (qc-4-margin-probe.log).
- Named artifact: llama-cli text front-end generates identical
  gibberish from BOTH files (its prompt tokenization differs
  from the fixture reference stream); raw-ID path coherent on
  both. Not a file finding.
- Regressions: engine compile exit 0; QC-3a grade rerun from
  this tree reproduces every banked number and its CSV is
  byte-identical to banked qc-3-grade.csv; QC-3a proof ALL PASS.
- Named gap: the plan's reverse leg (Aesir loads a llama.cpp-
  quantized stories Q8_0) is outside the commission's numbered
  scope and the kept build tree has no llama-quantize binary;
  QC-5's arbitration leg needs that binary built as a named
  first step. Full notes: QC-4-NOTES.md. Next: QC-3b / QC-5.


- Coordinator verification (2026-11-14): QC-4-NOTES.md
  re-read from disk (U-QC5 SETTLED — llama.cpp accepts
  the mixed file as-is; both cross-grade pairings
  FAITHFUL 157/157, agreement 157/157 in pairing (a));
  remote yrsa/qc-4 == 76039dcc confirmed by ls-remote
  before merge; fast-forwarded into yrsa/hip-serve and
  banked. Named scope gap stands: the reverse leg
  (Aesir loading a llama.cpp-quantized file) needs
  llama-quantize built — named first step for the
  QC-5 arbitration work.

## 2026-11-14 — QC-3a: whole-model Q8_0 conversion of stories260K + grade (worker slice; verified + banked by coordinator)

- DELIVERED: `aesir quantize` — aesir_engine/cli/quantize.mojo
  (new: quantize_gguf_q8_0 + q8_0_keep_reason policy +
  dispatch_quantize) wired into cli/commands.mojo (dispatch beside
  inspect + help), per QC-0 section 6's assignment of the CLI to
  QC-3. Path: QC-1 metadata-copy parse + GGUFSeer tensor access;
  per tensor either exact f16->f32 widening into QC-2's
  quantize_q8_0 or a verbatim payload copy; KVs copied raw except
  general.file_type = 7; emission via QC-1's writer, names /
  shapes / order preserved.
- POLICY AS APPLIED (stories260K census 37 F16 matrices + 11 F32
  norms): 32 matrices quantized (dim0 64; 237,056 elems;
  474,112 B -> 251,872 B Q8_0); 16 kept, every one named in the
  run report — blk.0..4.ffn_down.weight x5 stay F16 (dim0 172,
  172 % 32 = 12; no padding) and 11 norms stay F32
  (one-dimensional class). Kept payloads byte-identical to source.
- EMITTED: stories260K.Q8_0.gguf, 379,152 B (63.06% of the
  601,248 B source; sha256 5d4df894...a6d77b7), in the campaign
  folder, NOT committed (*.gguf is git-ignored; the source
  fixture is manifest-classified external). Independent Python
  census agrees: file_type 7, census {Q8_0: 32, F32: 11, F16: 5},
  data_offset 14,240 unchanged, all offsets 32-aligned.
- LOAD PROOF (test_quantize_model_qc_3, ALL PASS): metadata ==
  source except file_type; emitted Q8_0 blocks inside QC-2's
  proven bound (worst err/bound 0.7999 / 0.7987 on the two probed
  tensors); GGUFSeer reaches VALIDATED; PackedGGUF constructs in
  full (file_type reads 7); engine generates — greedy 8 ==
  source's own first 8 == the pinned llama.cpp oracle prefix.
- GRADE (grade_quantize_qc_3; CSV + independent Python re-grade
  agree exactly): teacher-forcing rank + gap of the source's
  argmax in the Q8_0 row, RAW prompts, CPU vs CPU, identical
  token-ID streams; stream = prompt + source greedy 16 (A-045
  convention), 6 prompts, 157 records — exact 156, near-tie 1,
  divergent 0; gate verdict FAITHFUL_NEAR_TIE; in-band 100.00%;
  argmax agreement 156/157 = 99.36%; worst rank 1, worst gap
  0.007. Prompt segment 61/61 exact; continuation 95 exact + 1
  near-tie. The one non-exact record is named: prompt 2 pos 10
  (335 vs 426, rank 1, gap 7 milli) — the same position where
  free-running greedy diverges at step 3 (5/6 prompts greedy-
  identical x16; both prompt-2 continuations coherent).
  VERDICT: FAITHFUL.
- FINDING F-3a-1 (named, unfixed): `aesir inspect` files BOTH
  the source and the emitted file NOT READY / UNSUPPORTED with
  the identical reason (llama3-variant tokenizer metadata
  mismatch) — admission is unchanged by conversion; the emitted
  file's quantization reads Q8_0 correctly. Pre-existing
  fixture-vs-registry property; stories' working path is the
  engine path, not registry admission.
- REGRESSIONS: engine compile exit 0; QC-2 quantizer test ALL
  PASS (banked numbers reproduce exactly); QC-1 writer test ALL
  PASS; Q35-1 loader test ALL PASS. Fences MemoryHigh=24G /
  MemoryMax=32G throughout; contention honestly noted (sibling
  Q35-6 HIP grade active during recon/build/first run; no
  timings claimed). QC-3b named gaps: dequantizing input path
  for quantized sources + the streaming writer at 3.1 GB are
  prerequisites, not yet built. Full notes: QC-3a-NOTES.md.

- Coordinator verification (2026-11-14): grade summary log
  re-read from disk (157 records, in-band 157/157 = 100.00%,
  agreement 156/157, worst rank 1 gap 7 milli-logits,
  verdict FAITHFUL); emitted file sha256 re-measured on
  disk = 5d4df894...6d77b7, 379,152 B vs source 601,248 B;
  remote yrsa/qc-3 == eb1cd17d confirmed by ls-remote
  before merge; fast-forwarded into yrsa/hip-serve and
  banked. FIRST COMPRESSED MODEL THAT LOADS AND GRADES
  FAITHFUL — the compression workstream's named moment.

## 2026-11-14 — QC-2: Q8_0 quantizer + round-trip property tests (worker slice; verified + banked by coordinator)

- DELIVERED: aesir_engine/core/quantize.mojo (new, ONE module in
  core/ beside the dequantizers it inverts, per QC-0 section 6) —
  quantize_q8_0 (List[Float32] -> Q8_0 payload bytes) +
  q8_0_payload_bytes + layout constants. The exact inverse of the
  engine's Q8_0 dequantizers (34 B blocks: f16 d @0, 32 x int8 @2).
- RULE (ggml quantize_row_q8_0_ref, re-read on-box from
  ~/llama.cpp-build/ggml/src/ggml-quants.c:273-296): per 32-block
  d = amax/127 (f32, stored f16), qs = roundf(w / d) clamped
  [-127, 127], qs formed against the UNROUNDED d; zero block emits
  all zeros. ERRATUM E-1 for QC-0 section 5: the plan said
  round-to-nearest-even; ggml's reference uses roundf (half AWAY
  from zero) — implemented ggml, pinned by byte-exact tie tests.
- PROOF (test_quantize_q8_0_qc_2; log qc-2-test.log) ALL PASS:
  byte-exact layout + tie blocks; both engine dequantizers agree
  element-for-element on every round-trip; EVERY element satisfies
  the proven per-block bound err <= d_hat/2 + 127*|d_hat - d| +
  amax*2^-10 + d_hat*0.002 + 1e-7 (worst err/bound 0.8951 across
  288 random multi-scale blocks, scales 1e-4..1e4: max err
  42.08008, mean 2.3806543); lattice values (d = 0.25 / 2.0, incl.
  +/-127) and zero blocks round-trip EXACTLY (err 0); tiny blocks
  stay in bound even when the f16 scale underflows to 0 (amax
  1e-7: max err 1e-07, ratio 0.4998).
- FILE PROOF (QC-1 harness style): 3-tensor GGUF via the QC-1
  writer with general.file_type = 7 (Q8_0 — the inherited
  metadata duty, demonstrated for QC-3); emitted payload bytes ==
  quantizer payload bytes exactly; GGUFSeer maps both Q8_0
  tensors (stops only at required-tensor validation), PackedGGUF
  constructs in full; engine-path dequant from the file at
  GGUFSeer's parsed offsets in bound — quant.weight 256x64 max
  err 0.016937 / mean 0.0046754; big.weight 32768x32 =
  1,048,576 elements (32,768 blocks) max err 0.19629 / mean
  0.0037532, no index overflow. Deterministic: the banked rerun
  reproduces the numbers exactly.
- REFUSALS (named errors, no payload): count 0 or not a multiple
  of 32 (refuse, never pad — non-aligned tensors stay at source
  type per QC-0 section 3); NaN/+Inf element (index named);
  block scale overflowing f16 (amax 1e10 tested). Scale underflow
  deliberately NOT refused (bound still proven, see notes).
- FINDINGS (readers not edited): F-1 engine Q8_0 dequantizers
  write F16, so blocks with amax > 65504 dequantize to Inf
  through the engine path though ggml-valid (llama.cpp dequants
  to f32) — engine-path proof stated for amax <= 65504; a fix
  would be a named reader slice (f32-out dequant), not the
  quantizer's. F-2 GGUFSeer mmap_and_load's except path munmaps
  (_cleanup) — tensor data pointers dangle after any failed
  load; the first file-test version segfaulted proving it, the
  proof now follows QC-1's offsets + file-image pattern.
- REGRESSIONS: engine compile exit 0; QC-1 writer test ALL PASS
  rerun from this tree; Q35-1 loader test ALL PASS. Builds/tests
  fenced MemoryHigh=24G / MemoryMax=32G (systemd user units).
  Contention honestly noted: sibling Q35-6's HIP grade process
  (RSS ~24.5 GB) was active throughout — correctness numbers
  only in this slice, no timings claimed. CLI stub NOT built
  (QC-3 owns cli/commands.mojo dispatch per QC-0 section 6);
  streaming quantizer entry named as QC-6 road. Full notes:
  QC-2-NOTES.md.

- Coordinator verification (2026-11-14): proof log re-read
  from disk (round-trip bound worst ratio 0.8951; 1M-element
  file round-trip max err 0.19629216; ALL PASS); remote
  yrsa/qc-2 == bf29712d confirmed by ls-remote before merge;
  fast-forwarded into yrsa/hip-serve and banked. Plan
  erratum E-1 stands (ggml roundf, half away from zero,
  pinned by byte-exact tie tests). Findings F-1 (engine
  dequant writes f16 — engine-path proof stated for
  amax <= 65504) and F-2 (GGUFSeer failed-load dangling
  pointers) recorded, readers untouched.

## 2026-11-14 — QC-1: GGUF writer core — spec-exact v3 emission + metadata-copy path (worker slice; verified + banked by coordinator)

- DELIVERED: aesir_engine/loader/gguf_writer.mojo (new, ONE
  module beside the readers) — GGUFModelDesc (KV list + tensor
  directory + payloads in-entry) -> spec-exact GGUF v3 bytes /
  file: 24 B header, typed-KV contract mirrored from
  GGUFSeer._parse_metadata_value, directory 1–3 dims in GGML
  order, offsets all % alignment == 0 (default 32), file size ==
  data_offset + final tensor end exactly. KV values ride as RAW
  encoded bytes (typed constructors for all 13 scalar types +
  5 array kinds), so copy fidelity never depends on interpreting
  a value. Pricing delegates to GGUFSeer._tensor_byte_size itself
  (one source of truth; accepted set = the 25 explicitly priced
  types). PLUS the metadata-copy reader path
  (read_gguf_header_copy / copy_gguf_model): GGUFSeer mmap +
  cursor walk, NO tensor materialization (Q35-1 style).
- WRITER REFUSES, pre-emission, what the readers refuse or
  misprice: duplicate KV keys, duplicate tensor names, bad /
  nested-array value types, typed-key contract violations,
  general.alignment mismatch, payload length != reader-priced
  size, dim0 not block-aligned, rank outside 1..3, unsupported
  tensor type.
- PROOF (test_gguf_writer_qc_1; log qc-1-test.log) ALL PASS:
  synthetic 3-tensor model (F32 norm + F16 matrix + Q8_0 matrix,
  16 hand-built 34 B blocks; 33 KVs covering all 13 value types)
  — header/KV/directory copy-parse EXACT, offsets 0/128/640 all
  32-aligned, size 2720 == data_offset 1536 + 1184, payloads
  byte-identical incl. Q8_0 blocks; GGUFSeer maps all 3 (stops
  only at required-tensor validation, the synthetic baseline)
  and PackedGGUF loads in full; 10 refusal cases fire. Real
  file: stories260K header copy == both readers' parses for all
  48 tensors, and the copied model re-emits BYTE-IDENTICAL
  (601,248 B, 0 mismatches) and reaches VALIDATED.
- BONUS (U-QC4 parse half): gemma-4-E2B header copy ==
  GGUFSeer + PackedGGUF parses (56 KV, 601 tensors,
  data_offset 15,819,776); feed_forward_length i32 array x35
  identical element-for-element. Whole-file gemma re-emission
  stays QC-3b's road (streaming writer first).
- ERRATA for QC-0: E-1 the size identity generalizes to
  data_offset + final tensor end (inter-tensor padding is
  real); E-2 loader _tensor_byte_size falls through to a Q4_0
  price for unpriced types (refusal arrives later at map time)
  — named next work, no reader change in this slice; E-3
  stories260K has no rope.freq_base key (reader default
  10000.0). No reader bugs blocked the proof.
- REGRESSIONS: engine compile exit 0; Q35-1 ALL PASS; gguf
  metadata suite exit 1 ONLY at the known pre-existing
  gguf.tensor_directory_interface (attributed, not chased).
  Builds/tests fenced MemoryMax 32G. Full notes:
  QC-1-NOTES.md.

- Coordinator verification (2026-11-14): proof logs re-read
  from disk (writer proof ALL PASS; stories260K re-emission
  byte-identical, 601,248 B, 0 mismatches; synthetic offsets
  0/128/640 aligned; refusal cases present); remote
  yrsa/qc-1 == f7fac828 confirmed by ls-remote before merge;
  fast-forwarded into yrsa/hip-serve and banked. Errata
  E-1..E-3 stand as recorded in QC-1-NOTES.md (E-2, the
  _tensor_byte_size Q4_0 fall-through for unpriced types,
  is named next work for the reader side).

## 2026-11-14 — Q8-1 fix: Q8_1 block size arbitrated at 36 B, compute side repaired (worker slice; verified + banked by coordinator)

- ARBITRATION (U-QC2 SETTLED): ggml block_q8_1 is 36 bytes — f16 d @0,
  f16 s @2 (s = d*sum(qs)), int8 qs @4..36 (ggml-common.h:258-269 in
  ~/llama.cpp-build; ggml.c traits type_size = sizeof = 36). QC-0's
  40 B expectation is refuted. The LOADER priced 36 B and was CORRECT;
  the COMPUTE readers (dequantize_q8_1, gemm_q8_1) walked a fictitious
  40-byte f32/f32 layout and were the defect.
- FIXED: compute.mojo both readers to 36 B/f16-d/qs@4 with citation
  comments; quantization_autotuner (32, 40) -> (32, 36); mimir_well
  format comment corrected; test_q8_fp8_quantization Q8_1 case
  re-encoded to the true layout (deliberate banked-expectation
  update, cited in the test; expected result -8 unchanged).
- AUDITED, already correct: gguf _tensor_byte_size (36), mmproj
  geometry (32, 36). AUDITED, honest refusals kept: PackedGGUF (no
  kind-9 geometry), loader/quantization strict lookups, model
  registry (no adapter admits Q8_1; qwen35 stays Q8_0-only).
- PROOF: new test_q8_1_fix_q8_1 ALL PASS (dequant unit; byte-size
  units agree 36 B across loader/mmproj/autotuner; synthetic GGUF
  Q8_1-then-F32 fixture — downstream offset delta 64, values exact;
  PackedGGUF refusal proven). Q8/FP8 parity runner ALL PASS.
  Regressions: Q35-1 ALL PASS, Q35-2 ALL PASS, engine compile exit 0;
  gguf metadata suite fails ONLY at the known pre-existing
  gguf.tensor_directory_interface (unchanged, not chased).
- Full notes: Q8-1-FIX-NOTES.md. Handoff to QC-1: its writer must
  emit 36-byte blocks, f16 d @0, f16 s = d*sum(qs) @2, int8 qs @4.

- Coordinator verification (2026-11-14): ggml header
  re-read on the box (block_q8_1 static_assert == 36 B);
  compute.mojo diff and proof/regression logs re-read from
  disk (Q8-1 proof, Q8/FP8 parity, Q35-1, Q35-2 ALL PASS);
  remote yrsa/q8-1-fix == 8fc2762b confirmed by ls-remote
  before merge; merged into yrsa/hip-serve and banked.
  The intermittent test-binary segfault observation stands
  as recorded in Q8-1-FIX-NOTES.md — an unexplained harness
  observation, not a proven production defect; named here
  so it is not lost.

## 2026-11-14 — Q35-4b: real-file serve proof — 27B Q8_0 resident on :18435 (worker slice; verified + banked by coordinator)

- REAL-FILE SERVE PROVEN END TO END: the 27B (sha256
  1fca6eef…186f08e, re-measured) served through the Qwen35 CPU
  session in RESIDENT mode (--qwen35-resident) on side port
  :18435 — the configuration Q35-7 inherits. Startup admission=
  native: the file took the registry's own signature path
  (variant qwen35-27B), NOT experimental. /health truth:
  profile qwen35, backend cpu, session_residency true,
  exact_prefix_reuse true WITH the detail "snapshot-based at
  committed turn boundaries only", weight_load_mode
  "q8_0_resident", experimental_admission false. (No variant
  field exists in /health; variant truth is admission/plan-
  level — named in the notes for Q35-7.)
- Two-turn resident chat over HTTP == the in-process resident
  reference exactly (driver ref_qwen35_realfile_q35_4b, same
  call sequence + serve-default sampling): T1 prompt 23,
  POS1=55, wall 20.82 s; T2 prompt 65, reused 55 (resident
  path), evaluated 10, wall 18.27 s. Stateless full-history
  resend after an intervening different-session request:
  reused 55 via Q35-5 snapshot restore, evaluated 10, reply
  == resident R2 exactly (wall 18.89 s).
- R1 RE-WITNESSED AT SERVE LENGTH: 483-token prompt (8x the
  grade's ~60) — served reply == in-process forward exactly;
  in-process rerun from reset reproduces exactly; text is
  coherent (structured extraction inside the think block, cut
  only by the 48-token cap). No long-context collapse at 483.
- R2 ANSWERED: serve defaults are NativeSamplingConfig() —
  temperature 0, top_k 40, top_p 0.95, min_p 0 (unmapped),
  repetition_penalty 1.0 via the session map, repeat_last_n
  64 (unmapped), seed 42. forward_pass_qwen35's own default
  rep-penalty 1.1 does NOT govern the serve path. Output
  coherent under these defaults; nothing retuned.
- FINDINGS (named, unfixed, Q35-7's): F-4b-1 replies carry the
  raw "Assistant:" marker (no chat template on this path);
  F-4b-2 special-token leakage after short answers ('hello
  <|endoftext|><|im_start|>…' to the token cap) — the qwen35
  CPU path does not stop on the model's end/control tokens.
- Peaks: serve VmHWM 31.3 GB; reference processes 31.6 GB
  (time -v). systemd MemoryPeak (5.35 GB) undercounts the
  mmap'd weights and is NOT the peak. Fence 64G respected;
  MemAvailable ~124 GB before the run; no contention observed.
  Speeds: end-to-end completion ~1.5–1.8 tok/s (grade decode
  ~2.2); long exchange wall 139.75 s (483 prefill + 48 gen).
- Regressions on the slice tree: engine compile exit 0;
  Q35-1, Q35-2, Q35-3a, Q35-3r, Q35-4a session ALL PASS;
  Q35-5 snapshot binary REBUILT from this tree and run —
  ALL PASS (closes the coordinator-owed standalone rerun
  post-U1 in form); ripple ALL PASS. Full 905 matrix not
  re-run (slice order).
- Both serve units stopped; :18435 free; :18434 down and
  untouched; aesir-gate/Ollama/Voxta stayed down throughout.
  Details: Q35-4b-NOTES.md + q35-4b-*.log in this folder.

- Coordinator verification (2026-11-14): bench log re-read
  from disk (health payload, T1/T2/stateless usage lines and
  MATCHES REFERENCE lines all present); regression logs ALL
  PASS incl. the rebuilt Q35-5 snapshot binary — the post-U1
  standalone rerun is closed; remote yrsa/q35-4b == d0f533aa
  confirmed by ls-remote before merge; fast-forwarded into
  yrsa/hip-serve and banked.

## 2026-11-14 — Q35-3b: real-file oracle grade FAITHFUL (worker slice; verified + banked by coordinator)

- FIRST COHERENT GENERATION FROM THE REAL FILE: Aesir greedy
  (40 tok, raw prompt P0) is TOKEN-IDENTICAL to llama.cpp's —
  coherent text (q35-3b-v2-gen.log, this folder). The 27B
  heretic loads, runs, and generates on Aesir. Milestone
  reported to the parent the same day.
- Grade (resident CPU vs llama.cpp CPU, same file, one token
  stream, 198 positions / 6 raw prompts): comparator argmax
  rank 1 at 197/198; 198/198 (100%) in the near-tie band;
  argmax agreement 197/198; worst record P5 pos 32, rank 2,
  gap 0.015; true-token rank-1 counts identical (142 in both
  engines' rows).
- U1 ARBITRATED — REAL BUG FOUND AND FIXED: pre-fix grade
  failed (61/198 in band; greedy looped ' France' x40). ggml's
  gated-delta-net broadcasts q/k TILED (head = vh % groups);
  Aesir used contiguous (vh // v_per_group) — 32 of 48
  v-heads read the wrong q/k head in every SSM layer. One-line
  fix in each forward path (inference.mojo) with the
  arbitration comment. Q35-3a's banked greedy changed (it had
  encoded the defective mapping; its determinism/geometry
  assertions pass untouched); Q35-3r's hard-coded sequence
  re-derived from the corrected run with a Q35-3b citation,
  then ALL PASS.
- Comparator: llama.cpp built natively (no Docker) at
  ~/llama.cpp-build @ a956a852 (knows qwen35); custom
  teacher-forcing tool kept with the build tree. Load path:
  resident for all Aesir runs. Peaks (time -v max RSS; systemd
  MemoryPeak unpopulated for these units): Aesir ~31.0 GB
  grade / 31.3 GB gen; comparator 28.2 GB; fences 96G/110G
  respected; one heavy run at a time. Speeds: Aesir ~2.2
  tok/s, llama.cpp ~2.7 tok/s (both CPU).
- HONEST CONTEXT: the grade exercised 198 positions total
  (prompts of 4-59 positions; positions 0..~60). Rope
  dimension_sections [11,11,10,0] settled for text positions
  in that range ONLY — R1: re-witness at serve lengths in
  Q35-4b. Batched vs per-token on the real file: next token
  identical, logits diff 0.0156 (f16 rounding class; R3:
  same-path snapshot seeds). R2: serve sampling defaults
  differ from grade config — Q35-4b grades its own. R4:
  plan serve latency from ~2.2 tok/s CPU.
- A-119 battery: deliberately NOT edited (it is A-048's filed
  historical account); a successor attestation row is named
  Q35-7 work.
- Regressions: Q35-1, Q35-2, Q35-3a, Q35-3r (v2), Q35-4a,
  ripple ALL PASS; full engine compile exit 0. Q35-5 snapshot
  behaviour re-proven in substance post-fix via Q35-3r (r7)
  (restore + stateless reuse over the resident engine, ALL
  PASS); the standalone snapshot-test binary rerun on the
  merged tree is folded into Q35-4b's regression set.
- Coordinator verification: remote yrsa/q35-3b == f5d61159
  confirmed by ls-remote; the fix diff, grade summary, and
  generation log re-read from disk; merged into
  yrsa/hip-serve and banked. Services stayed down
  throughout; Ollama never relaunched.

## 2026-11-14 — QC-0: compression workstream recon + plan (worker slice; verified + banked by coordinator)

- Plan banked as QC-0-PLAN.md (488 lines, this folder). Dequant
  inventory as the writer's inverse spec: Q8_0 34 B blocks
  (f16 d + 32 i8); K-quants Q2_K 84 B / Q3_K 110 B / Q4_K 144 B /
  Q5_K 176 B / Q6_K 210 B at 256-blocks; IQ/TQ family via
  codebooks; Q8_K named but has NO dequant (unsupported).
  GGUF writer state ABSENT, proven by search (cli
  llama_cpp_compat lists quantize as explicitly unsupported);
  emission spec derived from our reader: v3-only, LE, typed-KV
  contract, tensor directory, alignment 32, qwen35 F32-norms
  gate.
- First-proof substrate: no uncompressed mid-size model exists
  on the box — every source is itself quantized, so quantizer
  input is F32 values via the engine's own dequantizers. First
  whole-model proof: stories260K.F16.gguf (601,248 B, true F16,
  full tokenizer); scale step: gemma-4-E2B-it-Q4_K_M.gguf
  (3,106,738,272 B). The vault's 16 G MTP Q4_K_M is a DIFFERENT
  variant — size reference only, never the deliverable.
- Slices QC-1..QC-7 as in the MAP's QC section. Unknowns
  U-QC1..U-QC7 in the plan, each with its settler; U-QC1: no
  llama.cpp binary/source on the box — QC-4 must locate/build
  one (native, no Docker) before any cross-check claim.
- DISCOVERED BUG, named next work (not fixed; recon scope):
  Q8_1 block size conflict — loader _tensor_byte_size prices
  36 B/block while compute.mojo walks 40 B blocks. Owed before
  any Q8_1 reliance; Q8_1 is not a scheduled tier.
- Coordinator verification: remote yrsa/qc-0 == bc833bb0
  confirmed by ls-remote before merge; single-file commit
  (plan only, no code); fast-forwarded into yrsa/hip-serve.

## 2026-11-14 — Coordinator note: services stopped by Volmarr's orders; gate key TURNED; QC workstream commissioned

- ~13:15 EST voxta.service + ollama.service stopped by Volmarr's
  order (parent-executed); MemAvailable unchanged (~27.9 GB) — the
  pool holder was the gate's live HIP session all along.
  ~13:22 EST, his blanket go-ahead in chat ("do what is needed my
  witchie to progress with the tests and develop for Project
  Aesir, and work on teaching it how to compress the models too"):
  aesir-gate stopped by his word (parent-executed). All three
  services inactive; MemAvailable measured 124,382,660 kB; load ~0.
- Q35-6a worker saw the gate vanish mid-slice (healthy 13:19,
  refused at its 13:20:48 pre-check) and stopped per protocol,
  touching nothing — the disappearance was the ordered stop, not
  a failure. Its wrapper printed but did not assert the pre-check;
  lesson is the worker's to record in Q35-6 notes. Partial 6a
  results stand uncommitted in /home/volmarr/aesir-q35-6: second
  HIP context admitted beside the then-live gate; device greedy
  16 tokens == banked Q35-3a CPU greedy exactly, per-token rank 1
  gap 0.0 at prompt positions; state diffs off-band vs its own
  in-test CPU reference, whose usage is suspect — CPU-only A/B
  owed before any equality claim. 6a resumes after 3b/4b.
- Service license (parent, under his go-ahead): the campaign may
  stop/start aesir-gate as proofs require and relaunch Ollama
  when a comparator run needs it; Voxta stays OFF unless a proof
  targets Voxta interop (report any relaunch). A service found up
  that the campaign did not start is Volmarr's hand — work
  around it.
- Gate application: measured fit now PASSES for the 27B F16 path
  (~57 GB) and the 40B F16 estimate (~83 GB) against ~124 GB with
  >8 GB margin. Q35-3b + Q35-4b UNBLOCKED, sequenced first, still
  fenced (MemoryMax from measured headroom), one heavy run at a
  time, re-measure before each attempt. Q35-3r remains required
  before Q35-7's final serve configuration (the serve must
  coexist with a machine in normal use).
- NEW WORKSTREAM QC — teach Aesir to WRITE compression: emit
  quantized GGUF that Aesir and llama.cpp can load and run.
  QC-0 recon + slice plan first (own MAP/ledger section);
  grading is teacher-forcing rank + logit gap vs the model's own
  uncompressed source, CPU-vs-CPU, near-tie band = faithful;
  first proof on a small registered model, then the heretics —
  the strategic prize is a Q4_K_M 27B (~15-16 GB).

## 2026-11-14 — Q35-3r: Q8_0-resident load path, fixture-grade proof (worker slice; verified + banked by coordinator)

- Recon verdict (code read, this slice): the engine-core CPU path
  already consumes Q8_0 packed -- GGUFSeer maps Q8_0 as zero-copy
  mmap views and gemm_f16 dispatches them to gemm_q8_0 (fused GEMV
  / one-row bounded scratch); the ~57 GB gate figure was an F16-
  materialization PRICING, never a loader behavior. The missing
  piece was the contract, now built: opt-in resident mode
  (--qwen35-resident -> NativeModelPlan.resident_q8 -> session ->
  AesirEngine -> Qwen35Block) enforcing at load that EVERY large
  weight is stored Q8_0, refused BY NAME otherwise, no F16
  fallback; /health reports weight_load_mode=q8_0_resident only
  under the opt-in (other profiles byte-identical). One forward
  implementation; default path untouched. Full notes:
  Q35-3r-NOTES.md.
- Proof ALL PASS (logs q35-3r-*): (a) resident vs default on the
  forward fixture: greedy IDENTICAL to the banked sequence, logits
  max_abs_diff = 0.0 exactly (same packed views, same kernels --
  no second conversion exists); (b) resident per-token vs batched
  diffs bit-equal to Q35-3a (c) (0.0008479953 / 0.0078125 /
  0.013671875), next token identical; (c) large fixture (30.98M
  large elements): peak RSS default 113,248 KB vs resident
  113,612 KB vs deliberate-F16-materialize 174,460 KB -- avoided
  cost measured and closing against the formula; (d) session +
  snapshot over the resident engine (r6/r7), Q35-4a/Q35-5 tests,
  serve benches resident (health mode key) + default (no key),
  Q35-1/Q35-2/Q35-3a ALL PASS, ripple ALL PASS, engine compile 0.
- Real-file censuses via the no-materialization probe (peaks
  ~174 MiB, no forward): 27B 498 large / 26,893,352,960 elements /
  Q8_0 28,574,187,520 B / F16 53,786,705,920 B; 40B 746 large /
  39,068,631,040 / 41,510,420,480 B / 78,137,262,080 B. Both files
  PASS resident validation. FIT for Q35-3b, stated plainly:
  residency removes the 53.8 GB anonymous term, but ~28.6 GB of
  touched file pages + ~4.2 GB pool remain -- beside the live set
  at ~27 GB MemAvailable a real-file serve still needs the
  parent's quiet-window call.
- Fixtures: generator parameterized; the four banked fixtures
  regenerate byte-identical; new qwen35_forward_f16probe.gguf
  (refusal probe) + qwen35_large.gguf (footprint profile).
- Coordinator verification (2026-11-14): proof logs re-read from
  disk (test/bench/session/snapshot/ripple/regress ALL PASS;
  logits diff 0.0; real-file probe peak 178,664 KB, RESIDENT
  VALIDATION PASS); remote yrsa/q35-3r == ec1b9a1b confirmed by
  ls-remote before merge; fast-forwarded into yrsa/hip-serve.

## 2026-11-14 — Q35-5: residency + prefix snapshots for hybrid state, fixture-grade proof (verified + banked by coordinator)

- Snapshot/restore for Qwen35State at committed turn boundaries:
  Qwen35Snapshot deep-copies s_data + conv_data, the committed
  token stream, and — per the KV finding — the full-attention
  layers' KV prefix rows [0, boundary). KVCache is append-only
  and positionally stable WITHIN one live cache, but reset()
  redraws it over the same pool and intervening conversations
  overwrite prefix rows, so surviving snapshots COPY the KV
  prefix (only the 16-of-64 real / 1-of-4 fixture attn layers
  carry rows). Zero-state kept as a virtual snapshot at 0.
- Reuse = longest snapshot whose stream is an exact prefix of
  the new request's stream, or no reuse. Two exact checks in
  begin_turn (position 0 only): text-extension (resent text is
  byte-exactly snapshot conversation + "Assistant: " + its reply
  + one new user message; the stream is then snapshot.stream +
  tokenize(delta) BY CONSTRUCTION — re-tokenized reply text can
  never reproduce generated IDs, the seam HS-6 names) and
  token-prefix via reusable_prompt_prefix (final-token rule
  included). Resident Q35-4a path untouched.
- Store bound: snapshot_limit = 4 turn-boundary snapshots per
  session (configurable field), FIFO eviction, zero-state
  excluded. Real cost per snapshot: 27B SSM+conv 158,859,264 B
  + KV boundary x 65,536 B (4096 -> 268,435,456 B); 40B SSM
  alone ~235 MB — the bound is an informed choice (notes).
- Capability honesty: /health for qwen35 now reports
  exact_prefix_reuse=true ONLY with the new qualifier key
  exact_prefix_reuse_detail="snapshot-based at committed turn
  boundaries only" (serve_loaded gains the optional detail
  param; other profiles' payloads byte-identical).
- Proof ALL PASS (logs q35-5-*): session (a1) restore diffs
  s/conv/KV = 0.0/0.0/0.0 bit-exact; (a2) B re-run after restore
  s/conv/logits diffs 0.0, reply == resident; (a3) stateless
  begin prompt=90 reused=72, state/logits diffs 0.0; (c)
  diverged reused=0 prompt=191, reply == fresh cold reference;
  (d) 6 turns -> exactly 4 snapshots, oldest (60) evicted and
  unrestorable. Serve bench: resident reused=72/18 reply==R2;
  stateless (intervening session destroys residency) reused=72
  evaluated=18 reply==R2; diverged reused=0; bound resend-oldest
  reused=0 prompt=193 cold. F1: bit-exactness claimed only for
  same-path copy+continuation, never cross-path (notes).
- Regression: full engine compile exit 0; Q35-1 ALL PASS;
  Q35-2 ALL PASS; Q35-3a ALL PASS (greedy identical); Q35-4a
  session reference ALL PASS; Q35-4a resident + fresh HTTP
  benches ALL PASS (q35_4_bench.py caps assertion updated to
  the Q35-5 truth — deliberate extension); ripple probe ALL
  PASS unchanged. Proof units stopped; :18435 free; gate
  untouched. Full notes: Q35-5-NOTES.md. Banked by coordinator after disk verification of all proof logs. Next: Q35-6 (HIP) / Q35-3b (parent-gated).

## 2026-11-14 — Q35-4a: Qwen35 CPU serve session, fixture-grade proof (worker slice; verified + banked by coordinator)

- runtime_plan admits qwen35 explicitly: qwen35_profile_for +
  validate_qwen35 + qwen35_memory_plan branch; final else is
  gemma4-explicit (unknown profiles refuse by name). Fixture
  admission is an explicit opt-in (NativeModelPlan 4th arg
  experimental_qwen35 / serve flag --experimental-qwen35): the
  registry signature pin (64L/5120) is the only check skipped —
  validate_qwen35 runs in full — and the plan is marked
  experimental, reported in /health as experimental_admission.
  Without the opt-in the fixture still refuses with the registry's
  own reason. Variant follows the file (qwen35-27B real /
  qwen35-4L/128d fixture); serve family/parameter_size derive from it.
- NEW Qwen35CPUSession (aesir_engine/qwen35_session.mojo) over
  AesirEngine: batched prefill, per-token decode, persistent
  qwen35_state. reset() snapshots the committed stream (no reuse
  claimed), freshens KV, returns to position 0 WITHOUT wiping SSM
  state — the engine's reset-on-position-0 rule wipes it on the
  next conversation's first forward; resident turns skip reset and
  keep state bit-exact. Capabilities: residency TRUE,
  exact_prefix_reuse FALSE, suspend/restore not implemented,
  structured output + tools refused.
- Dispatch: cpu admitted ONLY for qwen35 (verbatim no-CPU-fallback
  refusal kept for all other profiles); qwen35 + cuda/hip refused
  as CPU-only in this slice; native_settings config whitelist
  gains cpu. Fixture tokenizer made byte-level toy (chars as
  tokens; weights untouched; Q35-1 fixtures byte-identical).
- Proof ALL PASS (logs q35-4-*): serve on side port 18435,
  /health profile=qwen35 backend=cpu residency=true
  exact_prefix_reuse=false experimental_admission=true; turn 1
  200 == in-process reference; resident turn 2 200 with
  reused_prompt_tokens=72, evaluated=18, reply == in-process A+B
  greedy reference EXACTLY (token streams in q35-4-session-test.log);
  fresh-instance control reused=0, prompt=193, different
  continuation. Proof units stopped; gate untouched on :18434.
- Regression: full engine compile exit 0; Q35-1 ALL PASS; Q35-2
  ALL PASS (sources unchanged); Q35-3a ALL PASS, greedy sequence
  identical. Ripple probe UPDATED by slice purpose: it asserted
  NativeModelPlan refuses qwen35 (Q35-2 truth); now asserts the
  Q35-4a admission truth (native for the real file, experimental-
  only for the fixture, unknown refused) — ALL PASS. Full notes:
  Q35-4-NOTES.md. Next: coordinator verify + bank; then Q35-5
  (SSM snapshots) / Q35-3b (parent-gated).

## 2026-11-14 — Q35-3a: CPU forward geometry repair, fixture-grade proof (worker slice; verified + banked by coordinator)

- Delta-net geometry repaired in inference.mojo (both forwards,
  identically) + aesir.mojo construction: conv_dim 3*inner ->
  qkv_width = qkv_weight.rows (2*groups*state + inner; 10240 real);
  qkv bands q [0, groups*state), k [groups*state, 2*groups*state),
  v [2*groups*state, qkv_width); recurrence over v-heads
  (dt_rank = 48 real) with q/k broadcast from group heads
  (3 v-heads/group), ssm_a/dt_bias/alpha/beta per v-head, y/z-gate
  over full inner width; q/k L2-norm once per group band (was
  in-loop per head); Qwen35State now layers x v_heads x state x
  state with conv ring qkv_width (construction passed group_count
  and 3*inner before). A-045 logit-row sink mirrored into both
  qwen35 forward_pass functions. Full-attention branch, partial
  rotary (64/256), ssm_norm/ssm_out path audited — already
  layout-true, unchanged.
- New fixture qwen35_forward.gguf (second profile in
  scripts/make_qwen35_fixtures.py; Q35-1 fixtures byte-identical):
  hidden 128, groups 2, state 16, dt_rank 4, inner 64, qkv 128,
  vocab 1024, all Q8_0 widths % 32 == 0, seeded random weights,
  ssm_a negative (stable by construction).
- Proof ALL PASS (q35-3-test.log): (a) finite logits, argmax 79 <
  1024, greedy == argmax; (b) greedy 16 tokens identical across
  two runs (1019 675 143 452 111 251 827 386 423 176 368 1018 910
  490 742 849); (c) per-token vs batched: s max_abs_diff
  0.0008479953, conv 0.0078125, logits 0.013671875 (max |logit|
  13.5546875) — NOT bit-identical, next token identical (finding
  F1 for Q35-5); (d1) split per-token continuation EXACT 0.0;
  (d2) batched-prefill-A + per-token-B EXACT 0.0; (d3) batched
  continuation chunk carries state, diffs as (c); (e) real
  signature formulas (2048 @ 0 / 2048 @ 2048 / 6144 @ 4096 /
  48x128x128 per layer).
- Regression: full engine compile exit 0; Q35-1 loader test ALL
  PASS; Q35-2 registry test ALL PASS (rebuilt, unchanged sources).
  Full 905 matrix not re-run. Named risks carried to Q35-3b:
  U1 semantics beyond layout (oracle-arbitrated), rope
  dimension_sections [11,11,10,0] unread by any engine code,
  1/sqrt(d_state) q-readout scale placement. No real file loaded
  through the forward path; Q35-3b stays parent-gated.
- Full notes: Q35-3-NOTES.md. Next: coordinator verify + bank;
  then Q35-3b (parent-gated) / Q35-4.

## 2026-11-14 — Q35-2: registry + profile + inspect (worker slice; verified + banked by coordinator)

- `core/qwen35_profile.mojo` NEW: formula-driven Qwen35Profile from
  GGUF metadata (qwen35_profile_for + validate_qwen35 +
  validate_relations with named refusals: interval not dividing
  blocks, inner != dt_rank*state, rope/head inconsistency; exact
  851-tensor contract mirroring the Q35-1 loader validator).
- classify() qwen35 branch: real geometry 64L/5120 ->
  native_profile "qwen35", READY / COMPATIBLE (qwen3 precedent:
  no generation witness yet), tensor_naming "qwen35/blk.*";
  Q8_0 admitted via a qwen35-scoped policy only (shared native
  lists untouched); other geometries COMPATIBLE without
  native_profile. cuda/cpu support stay false, capabilities stay
  "inspection" — execution is Q35-3/Q35-4, stated in the reason.
- inspect() dispatch + `qwen35_memory_plan`: KV priced for ONLY
  the 16 full-attention layers; activations carry SSM state
  (150,994,944 B) + conv rings (7,864,320 B), formula-driven.
  Real-file inspect now: READY / COMPATIBLE, tensor_validation
  "passed", estimated_vram_bytes 29295152100 at ctx 8192
  (q35-2-inspect-27b.log; was UNSUPPORTED at the gate).
- Policy test ALL PASS (q35-2-test.log): classify admit/refuse,
  three named validate refusals, real-file validate + inspect,
  exact memory numbers; existing native.model_registry +
  native.gemma4_profiles cases run unchanged inside it — pass.
  Full engine compile exit 0 (q35-2-build.log). Full 905 matrix
  NOT re-run (slice order; baseline 901/905 stands).
- Ripple guard PASS (q35-2-ripple.log): NativeModelPlan still
  refuses qwen35 under both "auto" and explicit "qwen35" — no
  serve admission leaked; Q35-4 owns runtime_plan. Named wart:
  the auto refusal text names Gemma 4 (gemma else-branch) —
  Q35-4 should add an explicit qwen35 branch. Also named:
  PackedGGUF cannot open the Q35-1 tiny fixture (ssm_out Q8_0
  columns 24, not 32-aligned), so the profile proof runs on the
  real file via the inspect seam; fixture regeneration was NOT
  done in-slice (would change banked Q35-1 expectations).
- Full notes: Q35-2-NOTES.md. Next: Q35-3 (CPU forward).

## 2026-11-14 — Q35-1: loader truth (worker slice; verified + banked by coordinator)

- `_validate_qwen35_tensors` fixed: qkv rows and ssm_conv1d rows now
  `qkv_width = 2*groups*state + inner` from config (real file: 10240);
  type constants aligned to the real census (Q8_0 weight matrices,
  F32 small tensors; 498 Q8_0 + 353 F32 re-verified by header parse).
- U2 SETTLED: types are recorded, not enforced — `_require_tensor_shape`
  never compares expected_type (code read), and the type-probe fixture
  (attn_gate stored F16 vs validator Q8_0) still validates (test (c)).
- Synthetic fixtures (scripts/make_qwen35_fixtures.py; tiny correct
  geometry, qkv 56): good PASS, bad-qkv (88) rejected with the shape
  error, type-probe PASS. Log: q35-1-test.log, ALL PASS.
- Real-file probe PASS through the no-materialization seam
  (inject_mmproj-style staging + direct _validate_required_tensors;
  zero-copy views + only 2,645,504 F32 elements converted; unit peak
  226 MB): q35-1-realfile-probe.log.
- Full notes: Q35-1-NOTES.md (incl. the pre-existing
  gguf.tensor_directory_interface regression note — unchanged,
  out of scope). Next: Q35-2 (registry + profile + inspect).

Running record. Newest entries at the top. Every entry from disk or a
tool result, never from a summary.

## 2026-11-14 — QA-0: campaign opened, plan adopted, seat verified

- Campaign commissioned by Volmarr in chat ("yes make the adopter for
  that kind") after the HS line's 27B gate verdict (NOT RUNNABLE:
  no qwen35 adapter, no recurrent-state session, no HIP path).
- Ground truth read on-device: GATE_AND_27B_RESULTS.md, MAP.md
  (HS line), inspect-27b.log, and the prior crew's QWEN35_PLAN.md —
  a complete verified recon (four-part blocker stack: registry,
  loader validator, engine-core forward geometry, serve layer) with
  slices Q35-1…Q35-7 and unknowns U1–U5. **Adopted as this
  campaign's plan**; it was banked by the prior crew at a8215e29
  ("Qwen35 line: recon + slice plan (Q35-1..Q35-7) banked") while
  this campaign was opening — local HEAD == origin/yrsa/hip-serve ==
  a8215e29, verified by fetch + ls-remote. Seat checked quiet (no
  build/git processes) before this campaign's first write.
- Target file SHA-256 verified on-device this session:
  1fca6eefc37607b5ab458f9a76815b36aeb38cf21ac36c49fdc0ab4eb186f08e
  (28,596,003,296 B) — matches the gate doc.
- Machine state at open: MemAvailable ~27 GB of 127 GB; aesir-gate,
  ollama, voxta all active (live for Volmarr's Voxta testing — never
  to be touched). The tracked `hidden_files/hip-serve/serve-bench.log`
  modification in git status is the live gate's own log; left alone.
- Full-suite baseline to defend (from the gate doc): 901/905 with
  only the two proven pre-existing failures
  (gguf.tensor_directory_interface; gpu.hip_q4k_gemv_no_leak).
- Next: Q35-1 (loader truth) — validator formula fix + type-policy
  probe + synthetic fixture. The real-file load probe in Q35-1
  reaches tensor materialization only; the full CPU residency proof
  is Q35-3 and carries the U3 memory exception decision with it.
