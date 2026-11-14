# Aesir Qwen35 Adapter Campaign — RESULTS

Closed 2026-11-14 by Q35-7. The campaign set out to make the
`qwen35` hybrid architecture (the 27B heretic GGUF,
/mnt/vault/models/gguf/Qwen3.8-27B-Ultimate-Heretic-Uncn-
Turbo-Brilli-50x-AGI-NEO-Q8_0.gguf, 28,596,003,296 B, sha256
1fca6eefc37607b5ab458f9a76815b36aeb38cf21ac36c49fdc0ab4eb186f08e)
load, generate, and serve on Aesir. It does all three: the file
grades FAITHFUL against llama.cpp on CPU, serves end to end in
the Q8_0-resident CPU configuration, and is now the aesir-gate's
primary model on :18434. Full per-slice record: LEDGER.md +
the Q35-*/QC-* notes in this folder.

## Headline numbers

- Real-file oracle grade (Q35-3b, after the U1 fix): FAITHFUL —
  198/198 records in the near-tie band (rank <= 2, sub-logit
  gap) vs llama.cpp CPU on the same file; greedy generation
  token-identical to the oracle. U1 was a real engine defect
  (delta-net q/k broadcast) found and fixed by the grade.
- Resident load (Q35-3r): 498 large tensors stay Q8_0 —
  28,574,187,520 B stored vs 53,786,705,920 B of F16
  materialization avoided; resident numerics bit-equal to the
  default path on the fixture (logits diff exactly 0.0).
- CPU serve (Q35-4b, re-proven Q35-7): end-to-end ~1.5-1.8
  tok/s (grade decode ~2.2 tok/s); serve VmHWM ~31.3 GB
  (Q35-7 gate measure 31,616,528 kB); resident reuse and
  stateless snapshot reuse both at the turn-1 boundary (55 on
  the standard bench), replies == the in-process reference.
- HIP (Q35-6/6b): real-file grade 71/71 positions CPU-argmax
  rank 1, gap 0.0; 40-token greedy token-identical to the
  banked CPU witness; HIP serve bench ALL PASS, VmHWM 30.1 GB.
  HIP decode is SLOW (~0.07-0.09 tok/s, naive GEMV ~11-14
  s/token at 27B) — experimental admission only.
- Full engine suite at close (Q35-7, this tree, fenced
  MemoryHigh=64G / MemoryMax=96G, four runs): 900 passed /
  3 failed / 2 skipped / 905 total on the final runs. The
  three failures: gguf.tensor_directory_interface and
  gpu.hip_q4k_gemv_no_leak (the two proven pre-existing
  failures, untouched) and resilience.state_vault_rejects_
  growth — a scheduling race case (forked byte-appender vs
  500 read attempts) that passes standalone 3/3 on a quiet
  box, passed in-suite in the pre-campaign baseline, fails
  in-suite under the suite process's own contention, and
  reproduces standalone under synthetic 32-core load; no
  vault code was touched by this campaign (evidence:
  q35-7-cases-rerun*.log, q35-7-cases-load*.log, q35-7-
  suite-run*.log). A fourth case, hardware.hip_config_gate,
  failed on run 1 and was FIXED in scope: Q35-4a had added
  cpu to the admitted-backend message and the HS-1 test's
  expected string was stale; the expectation now names the
  true set ("auto, cpu, cuda or hip") and the case passes.

## Per-slice verdicts

- QA-0 — plan adopted, seat verified. DONE.
- Q35-1 — loader truth: validator formulas fixed to the real
  SSM layout; the real 27B is accepted to tensor
  materialization; synthetic fixture loads, mutated fixture
  rejected; U2 settled (token types recorded, not enforced). DONE.
- Q35-2 — registry + profile + inspect: `aesir inspect` on the
  real file returns READY/COMPATIBLE, native admission,
  variant qwen35-27B. DONE.
- Q35-3a — CPU forward geometry repair (fixture-grade):
  qkv split, conv width, v-head recurrence with q/k broadcast,
  state sizing; synthetic load/forward/greedy + per-token vs
  batched state equality ALL PASS. DONE.
- Q35-3b — real-file oracle grade: FAITHFUL 198/198 (above).
  A-119's historical LOAD_FAIL account deliberately left
  untouched; the successor attestation was named for Q35-7
  and is filed there. DONE.
- Q35-3r — Q8_0-resident load path: opt-in contract enforced
  at load (non-Q8_0 large weights refused by name), reported
  as weight_load_mode in serve health. DONE.
- Q35-4a — CPU serve session over the engine-core path
  (fixture-grade): native_serve dispatch, honest capabilities. DONE.
- Q35-4b — real-file serve proof on :18435 in the resident
  configuration: ALL PASS (health truth, resident + stateless
  reuse, serve-length witness at 483 tokens). Two findings
  named for Q35-7: F-4b-1 (raw "Assistant:" marker in
  replies), F-4b-2 (no stop on end/control tokens). DONE.
- Q35-5 — residency + prefix snapshots: snapshot/restore of
  the hybrid state (SSM + conv rings + KV prefix) at token
  boundaries; reuse only at snapshot boundaries; fixture +
  serve proofs ALL PASS. DONE.
- Q35-6 — HIP execution: device delta-net defects D1/D2
  fixed; trajectory inside the Q35-3a band; batched prefill
  chosen (6.7x at 64 tok); Qwen35HipSession + experimental
  serve admission. Q35-6b real-file HIP serve ALL PASS
  (grade 71/71). DONE — experimental, not the gate config.
- Q35-7 — gate swap + close: F-4b-2 fixed (stop set derived
  from the model's own tokenizer: eos 248046 <|im_end|> +
  26 GGUF CONTROL entries = 27 stop tokens; the Q35-4b short
  answer that leaked `<|endoftext|><|im_start|>...` to the cap
  now halts at 4 emitted tokens with clean text "\\n\\nhello",
  finish stop); F-4b-1 fixed (one leading role-marker block
  trimmed in the session's presentation path; served replies
  byte-identical to the banked Q35-4b replies after the
  marker); A-119 successor attestation filed beside (not
  over) A-048's account (REAL_FILE_LOAD_PASS_ADAPTER_RESIDENT);
  /health gained model_variant (qwen35-scoped, Q35-3r style).
  Gate swapped to the 27B resident CPU configuration on
  :18434 (fence MemoryHigh=48G / MemoryMax=64G for the 31.3 GB
  class); full bench ALL PASS on the gate; llama3-3b kept as
  the documented fallback in VOXTA_SWITCHOVER.md with exact
  rollback steps; pre-swap configuration backed up to
  hidden_files/hip-serve/aesir-gate-llama3-3b-config-backup-q35-7.txt.
  Gate left RUNNING on the 27B. DONE.

## Cross-references from the QC compression workstream

(Full record: QC_RESULTS.md + QC-0..QC-7 notes.)
- Q8-1 fix (QC-0's named bug): Q8_1 block size arbitrated at
  36 B; the compute side that walked 40 B blocks repaired. DONE.
- F-3b-1 (found by QC-3b): gemma4 registry admitted Q8_0 —
  verdict OMISSION, fixed with a gemma4-scoped list in the
  Q35-2 house pattern. DONE.
- QC-6: the 27B Q8_0 -> Q4_K_M product (16,223,236,576 B,
  56.7% of source, sha256 4515cac6...fc04cc) grades 197/198
  in band vs its Q8_0 source — DIVERGENT by the strict gate
  (one record, p5 pos22 rank 3 gap 0.421), the strongest
  K-tier grade in the workstream; resident footprint would
  be ~19.5 GB vs ~31.0 GB. It is NOT the gate configuration:
  it serves only via the packed path (see remaining work).
- QC-7: QC_RESULTS.md + RESIDENCY-NOTE.md filed; the QC
  workstream is COMPLETE (QC-0..QC-7).

## Honest limits

- Grade context: the 198/198 oracle grade covers short
  positions (~0..60); the serve-length witness is 483 tokens
  and is same-path agreement (served == in-process), not a
  second oracle grade at length. Longer-context grading is
  unclaimed.
- HIP decode speed: ~0.07-0.09 tok/s at 27B (naive GEMV).
  The HIP path stays experimental-flagged; native (non-
  experimental) HIP admission is unclaimed.
- Sampling: min_p and repeat_last_n have no qwen35 CPU-
  forward counterpart and are not claimed (unchanged Q35-4a
  truth); the serve defaults governed every proof (R2).
- Truncated-turn continuation: a turn-2 whose turn-1 was cut
  mid-sentence by the token cap continues as the model
  chooses on that truncated stream (Q35-6b investigation:
  model behavior, bit-exact on both paths, not a defect).
- Snapshot store: per-session in-memory, limit 4 turn
  boundaries (Q35-5) — longer Voxta histories resend cold.

## Named remaining work (not done, not hidden)

1. Q4_K_M resident analogue: a resident load contract for
   the QC-6 Q4_K_M product + its serve smoke, so the ~19.5 GB
   configuration can be gated like the Q8_0 one.
2. Searched-fit packer: the named lever for QC-6's one
   out-of-band record (p5 pos22) — the strict-gate DIVERGENT
   verdict stands until it lands.
3. HIP decode speed: batched/vectorized GEMV (or a measured
   hybrid) before HIP can be a gate candidate; native HIP
   admission after that.
4. min_p / repeat_last_n on the qwen35 sampling path.
5. gemma4 CPU forward (the F-3b-1 remainder: registry admits
   gemma4 Q8_0 files the CPU forward cannot yet run).
