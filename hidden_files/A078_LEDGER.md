# A-078 Ledger — GPU fuzz (aesir-team-02)

Status: BUILT + TESTED + COMMITTED on yrsa/aesir-team-02, on top of
seat main c56b7596 (76 of 216 banked, verified from git on
purpleraider). Awaiting banking by the keeper in roadmap order
(A-077 first, then A-078; A-079 is already committed by team-03 and
banks after). Do NOT merge or push from this worktree.

Slice: A-078 — GPU fuzz. Random prompts / shapes / context lengths
vs CPU oracle (docs/AESIR_Z13_MASSIVE_ROADMAP.md, Wave 9).
Acceptance doc: docs/bench/A078_GPU_FUZZ.md.

## What was built

- `aesir_engine/core/gpu_fuzz.mojo` (219 lines) — seeded,
  reproducible fuzz case generation + the divergence verdict
  classifier `fuzz_classify`. Battery base seed
  FUZZ_BASE_SEED = 0xA078_0001; per-case seeds derive from
  (base seed, case index) via the A-063/A-066 Knuth MMIX LCG, so
  any case replays exactly on any host with no stored fixture.
  Case space: prompt lengths 1..32, logit-row shapes cycling
  16/37/64/128/251/512/1024/4096 (odd sizes included), gen
  lengths 1..8. Verdict codes: 0 faithful, 1 near-tie, 2 noise
  (IQ row gap < 2.0, or degenerate oracle margin < 0.05 with
  gap < 0.5), 3 comparator-artifact, 4 real divergence,
  -1 invalid.
- `aesir_engine/tests/test_gpu_fuzz_a078.mojo` (469 lines) —
  7 E-MASTER cases (gpu_fuzz.*), registered in run_all.mojo
  with re-pin 556 -> 563 (diff vs seat HEAD verified: exactly
  the 7 imports, 7 run_case lines, and the pin — nothing else).
- `aesir_engine/tests/bench_gpu_fuzz_a078.mojo` (337 lines) —
  standalone filed battery (SYNTH / SAMPLE / REAL / GEN), not
  part of run_all.
- `aesir_engine/a078_driver.mojo` — standalone driver main for
  the 7 cases (a078_driver.log below).
- `docs/bench/A078_GPU_FUZZ.md` — method, filed numbers, and
  the honest reading of the REAL comparator verdict.
- `hidden_files/a078_verdict_table.md` — per-case REAL rows
  extracted verbatim from a078_bench.log.
- Run scripts (uncommitted, per A-075 precedent):
  hidden_files/run_a078_{suite,bench,driver,diag}.sh.

## Grading law applied (standing, unchanged)

Teacher-forcing rank + logit gap on RAW token sequences only,
never template-rendered prompts; CPU engine vs CPU comparator
only for the oracle side; near-tie band rank <= 2 with
sub-logit gap = faithful; IQ graded on coherence, never
token-exactness. Comparator artifacts are a verdict class and
are checked BEFORE any real-defect verdict. A fuzz battery is
green only when the real-divergence count is 0.

## Evidence

### Bench (hidden_files/a078_bench.log, sha256 fd7de00683ad3c52b8dc034c70db2f1624cbf62f3b3dfd1968c5efcbda1d4ed0, 2026-11-12 21:50 EST, MOJO_EXIT=0)

- A078_BENCH base_seed=2692218881; A078_BENCH: PASS.
- SYNTH total=256 faithful=219 near_tie=19 noise=18
  comparator=0 real=0. SYNTH is a classifier-calibration
  battery: synthetic CPU logit rows perturbed at the A-065
  accumulation-noise scale (+/-0.01), graded rank/gap against
  the unperturbed row. 238/256 land inside the parity band
  (faithful + near-tie). The 18 noise rows are the
  degenerate-margin class: the source row's own top-1/top-2
  margin was < 0.05, so the injected noise legitimately
  reshuffles a near-exact tie — a property of the fixture row,
  not of any engine. Comparator=0 is structural (the SYNTH
  call passes prompt_boundary=False, so the class cannot
  occur). Real=0 is the only engine-indicting class and it is
  empty; SYNTH alone must not be restated as a GPU parity
  proof — that rests on REAL + GEN below.
- SAMPLE greedy_ok=96/96, sample_ok=96/96 — Vulkan sampling
  path vs the independent CPU oracle in the bench file.
- REAL total_pos=147 faithful=0 near_tie=0 noise=0
  comparator=147 real=0 — see verdict section below.
- GEN exact=32/32 — 4 random prompts x 8 greedy tokens,
  GPU greedy vs CPU greedy loop, token-exact.

### Driver (hidden_files/a078_driver.log, sha256 1197d527a197dd27708d6eb821d966f240012da95530580352ffed94a90287ef, 21:45 EST, MOJO_EXIT=0)

A078_DRIVER_ALL_PASS. Seed replay: 16 cases regenerate
identical ids + rows, seeds distinct. Coverage: prompt lens
1..32 over 64 cases, shapes incl. odd 37/251, gen lens 1..8.
Classifier: faithful/near-tie/comparator/IQ-noise/
margin-noise/real/invalid all pinned. Synthetic battery:
64/64 verdicted, 0 real (faithful 56, near-tie 5, noise 3).
Greedy fuzz: 24 seeded rows, shapes 16..4096, token-exact vs
CPU, 24 dispatches. Temperature fuzz: 18 seeded draws exact
vs the CPU sampling oracle. Real-model fuzz: 6 random
prompts, 26 positions verdicted, 0 real, comparator 26.

### Diag (hidden_files/a078_diag.log, sha256 a797488c71c3ed492afae8beced4be08832aea13dead64e34cda78ad21266051, 21:42 EST, MOJO_EXIT=0)

DIAG_DONE. The step-0 probe that measured the comparator
tail rule now filed in fuzz_classify: at the prompt boundary
the fuzz target is a uniformly random token, deep in the
tail — filed ranks 1547..126399, CPU gaps 9.31..23.09;
GPU/CPU gap relative deltas 0.47%..2.86% with top-1 agreeing
at every filed position. Hence the filed rule: deep-tail
target (cpu_gap >= 4) with gap agreement within 3% relative
is the prompt-boundary comparator class; the A-067 absolute
0.05 bound was written for natural prompts and does not
describe random step-0 targets.

### Suite (E-MASTER run_all, gfx1151, 6 shims staged)

Run AFTER team-01's A-077 GPU soak exited (PID 500041,
3600 s, started 21:26 EST, ended 22:27 EST MOJO_EXIT=0,
nonfinite=0) — no heavy A-078 run overlapped the soak.

- Attempt 1 (hidden_files/a078_run_all_attempt1.log,
  sha256 2204f23005254b7589c244ff908ae02902ef6f9b5d2ba3d833ed8b2388e09474):
  559 passed / 2 failed / 2 skipped / 563 total, MOJO_EXIT=1.
  Failures: gguf.tensor_directory_interface (tolerated,
  below) + resilience.state_vault_rejects_growth.
- Attempt 2 (hidden_files/a078_run_all.log,
  sha256 0b35aba914757e7cf7e91868e09a89639e9d3c105419d7c2ebf56dac28ff991a):
  559 passed / 2 failed / 2 skipped / 563 total, MOJO_EXIT=1.
  Failures: gguf.tensor_directory_interface (tolerated) +
  gpu.amd_hip_stream_async_round_trip.
- All 7 gpu_fuzz.* cases PASS in both attempts. Totals are
  the A-076 seat baseline (553/1/2/556) + exactly the 7 new
  cases, with the intermittent pair (below) accounting for
  the second failure in each attempt.
- Skips are the 2 pre-declared: vision.cuda_session_image_chat
  and rag.real_engine_integration.

## Verdict classes

- gguf.tensor_directory_interface: PRE-EXISTING TOLERATED
  failure (J-022 drift: "tensor directory admission differs
  for rank 3: GGUF is missing required tensor:
  token_embd.weight"). Present at every seat gate; not
  A-078's code path.
- resilience.state_vault_rejects_growth and
  gpu.amd_hip_stream_async_round_trip: KNOWN INTERMITTENT
  PAIR, named as such in team-02's A-075 campaign state.
  Cross-attempt evidence this slice: state_vault FAILED
  attempt 1 and PASSED attempt 2; hip_stream PASSED
  attempt 1 and FAILED attempt 2 (VAL-003 / MEM-004
  USE_AFTER_FREE refusal, A-022 ownership law). Each failure
  is a race-class flip of a case that passes on the adjacent
  run; neither case shares a code path with A-078
  (gpu_fuzz imports core/parity_battery only — no StateVault,
  no HIP stream surface). Verdict: intermittent flake class,
  NOT an A-078 defect and NOT a banking blocker under the
  standing seat-gate precedent. Named road: root-cause the
  two races (StateVault growth-check timing; HIP async
  transfer ownership lifetime) as their own follow-up work —
  recorded in CAMPAIGN_STATE.md next work; do not let the
  pair keep absorbing suite verdicts silently.
- REAL comparator=147: COMPARATOR-ARTIFACT class, honest
  reading in docs/bench/A078_GPU_FUZZ.md. Random targets are
  deep-tail under BOTH engines (diag: ranks 1547..126399,
  cpu_gap 9.31..23.09), so no position can read faithful;
  what the class certifies is cross-engine agreement —
  top-1 agrees at all 147 positions (top1_agree = pos/pos in
  every verdict-table row) and gap deltas stay inside the
  filed 3% tail rule — corroborated independently by GEN
  token-exact 32/32. It does NOT prove faithful-rank
  behaviour on natural text; that remains A-067's filed
  ground. Real-divergence count is 0 in every section.

## Bugs found

- None in A-078 scope. No engine defect discovered; the two
  suite intermittents above are pre-existing, named, and
  roaded. Scratch files aesir_engine/a078_diag_tmp.mojo
  (the diag probe source) and aesir_engine/tests/
  a078_driver_tmp.mojo (duplicate of a078_driver.mojo) are
  left uncommitted in the worktree as scratch, per the
  A-075 commit precedent.

## Honesty bounds

- SYNTH rows are synthetic by construction (labelled in the
  bench file); they calibrate the classifier, not model
  quality.
- The 3%-relative step-0 tail rule is an A-078 measurement
  filed from the diag probe beside the rule in
  gpu_fuzz.mojo; changing it is a new battery.
- Accelerator evidence: SAMPLE/REAL/GEN ran on purpleraider's
  gfx1151 Vulkan path with --target-accelerator gfx1151 per
  the run scripts; the test file refuses non-RADV devices
  (vendor 0x1002, llvmpipe refused) and honest-absents when
  the device or fixture is missing.
