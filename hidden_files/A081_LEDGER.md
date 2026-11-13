# A-081 Ledger — Part III gate (team-11)

- Slice: A-081 — Part III gate (Wave 9 closer). Roadmap:
  docs/AESIR_Z13_MASSIVE_ROADMAP.md. Acceptance: GPU path
  declared primary for decode ONLY if it beats the A-030 CPU
  baseline by >=2x on the 8B-class Q4 fixture decode;
  otherwise an honest verdict with the blocking causes named
  as new road-slices. Ledger updated either way.
- Team: team-11 (lead solo on device; no sub-agent spawn
  available in this seat — all device work by the lead).
- Worktree: /home/volmarr/aesir-team-11, branch
  yrsa/aesir-team-11, base 3cfc4370 (A-078 banked, 78 of 216).
- Machine: purpleraider (ASUS ROG Flow Z13, Strix Halo),
  AMD Radeon 8060S (vendor 0x1002, device_type 1), RADV
  STRIX_HALO; llvmpipe refused by the identity guard.

## VERDICT: HONEST NEGATIVE — GPU NOT declared primary

Fresh measurement this slice (driver
tests/bench_part3_gate_a081.mojo, sha256 9c05c8a7...0263a;
log hidden_files/a081_bench.log, sha256 43891878...3f9,
MOJO_EXIT=0). Fixture: Meta-Llama-3.1-8B-Instruct-Q4_K_M.gguf
sha256 7b064f5842bf9532c91456deda288a1b672397a54fa729aa665952863033557c
verified in-worktree before the run (the A-067 pin). RAW
prompt "The capital of France is" (6 tokens, add_bos=True, no
template), greedy 32 steps, 3 reps per path, quiet window
(load 0.05-0.21, Z-100 soak probes frozen state T, ps-checked
no seat gate / suite / bisect running at launch):

| Path | Reps tok/s | Median tok/s |
|---|---|---|
| CPU AesirEngine decode span (A-036 timings) | 7.325 / 6.958 / 6.750 | 6.958 |
| GPU VulkanRealModel decode-step wall | 1.501 / 1.497 / 1.474 | 1.497 |

- GPU greedy ids == CPU greedy ids: 32 of 32 exact.
- GPU step average 670 ms; weight streaming 377 ms/step
  (56 percent), 4,185 MB/step (A-070 accounting in-log).
- Reading A (roadmap / Z13-P2-030 bar: 2 x 8,745.9 =
  17,491.8 tok/s): FAIL, shortfall factor ~11,700x.
- Reading B (same-fixture bar: 2 x 6.958 = 13.92 tok/s):
  FAIL, GPU/CPU ratio 0.215x (GPU ~4.7x slower than CPU).
- The negative stands on Reading B alone; it does not rest
  on the cross-model-class comparison.
- Consistency: A-067 ~680 ms/position; A-070 step 664-686 ms
  with stream 392 ms/step (57.1 percent); A-077 soak 4,590
  steps / 3,600 s = 1.275 tok/s sustained. A-074 subgroup
  attention wins (8.6-9.1x) do not move end-to-end decode
  because streaming dominates the step.

## Blocking causes — new road-slices (full text in
## docs/bench/A081_PART_III_GATE.md)
- R-A081-1 Total device weight residency vs the shim's
  128 live-buffer cap (dominant: 377 of 670 ms/step).
  Necessary, not sufficient (residual ~293 ms/step ~
  3.4 tok/s is still below the CPU's 6.958).
- R-A081-2 Per-step dispatch / host round-trip overhead:
  ~485 dispatches/step, host KV pack linear in KV length
  (A-070: 12.11 ms/step at kv ~8.5), host RoPE permute
  round trip (A-070: 23.75 ms/step). Roads: persistent
  device KV (A-066 pattern), GPU RoPE bridge kernel,
  fused/batched per-layer dispatch.
- R-A081-3 Roadmap-wording observation (not a verdict
  input): the A-030 baseline is a 260K-fixture number;
  17,491.8 tok/s of 8B decode is beyond this hardware's
  memory-bandwidth ceiling for single-stream decode.
  Future gate bars should be stated same-fixture.

## Deliverables
- aesir_engine/tests/bench_part3_gate_a081.mojo — standalone
  gate bench (NOT in run_all; +0 cases, pin untouched).
- docs/bench/A081_PART_III_GATE.md — the gate record.
- CAPABILITY_LEDGER.md — NEW section 24 (Part III gate)
  with entry Z13-P3-081 recording the honest negative
  ("ledger updated either way" discharged here and in
  PROJECT_MEMORY_MAP at banking).
- hidden_files/run_a081_bench.sh, run_a081_suite.sh.

## Gate — E-MASTER (team worktree, base 3cfc4370)
- Attempt 1 (hidden_files/a081_run_all_attempt1.log,
  sha256 f175c9a7...4728): 563 passed / 3 failed / 2 skipped
  / 568 total. Failures: the pre-existing J-022 drift +
  gpu.amd_hip_stream_async_round_trip (named intermittent,
  MEM-004 class) + memory.budget_live_meminfo_pressure
  (the named intermittent under seat bisect for A-079;
  this run is one more data point for that investigation,
  in a team worktree with no seat gate running).
- Re-run (hidden_files/a081_run_all.log, sha256
  42ba2f26...2771): 565 passed / 1 failed / 2 skipped / 568
  total — EXACTLY the A-078 seat baseline. Sole failure =
  pre-existing gguf.tensor_directory_interface J-022 drift
  (roads A-165/A-121). Skips = the 2 pre-declared. Both
  intermittents passed on the re-run (the A-078 signature:
  each intermittent passes in one of the two attempts).
- A-081 changes no engine code, so neither intermittent is
  attributable to this slice; no new bug discovered by this
  slice's own code. The bench driver's first compile surfaced
  no defects (ran clean first attempt, MOJO_EXIT=0).

## Banking note
A-079 and A-080 are ahead in roadmap order and not yet
banked; A-081 banks only after them, at the seat. The
memory.budget_live_meminfo_pressure bisect (team-03
immediate next work, seat runs 10/11/12) is upstream of
A-079's banking and therefore of this slice's.
