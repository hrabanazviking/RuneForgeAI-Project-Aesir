# A-031 Ledger — Loader performance (team-08)

- Slice: A-031 — Loader performance. GGUF load + tokenizer init timed
  on NVMe, cold and warm cache. Acceptance: timings filed; any >2x
  cold/warm anomaly explained. -> MET (see anomaly section).
- Base: 05f61cd6f1a3f16556a57c3eb634fc3dc0b82bf3 (A-028 banked, 28/216)
- Branch: yrsa/aesir-team-08, worktree /home/volmarr/aesir-team-08
- Host: purpleraider (Ryzen AI Max+ 395 / Radeon 8060S gfx1151),
  kernel 7.3.0-10-generic, /home on /dev/nvme0n1p3 (btrfs, NVMe).

## Harness (committed)
aesir_engine/tests/bench_loader_a031.mojo — opt-in, NOT in run_all
(pin stays 359). Per rep, fresh GGUFSeer + RuneWeaver + MimirWell:
- meta_ns = inspect_metadata: open+mmap+header+metadata parse;
  metadata parse builds the RuneWeaver tokenizer vocabulary from
  tokenizer.ggml.* (tokenizer init is interleaved in this phase).
- load_ns = mmap_and_load: full load (same phases + tensor-descriptor
  mapping + required-tensor validation). NOTE: measured right after
  the meta pass in-process, so its file pages are already faulted in;
  the cold cost lands in meta_ns by construction (see anomaly).
- enc_ns = RuneWeaver.encode of a fixed probe sentence with the
  tokenizer built by the full load (proves init worked; 30 tokens).
Clock: clock_gettime(CLOCK_MONOTONIC) via armvegr.util.now_ns.
Build: pixi run --frozen mojo build -I aesir_engine -I .
  aesir_engine/tests/bench_loader_a031.mojo -o hidden_files/bench_loader_a031

## Fixture
stories260K.F16.gguf — GGUF v3, llama arch, 48 tensors, 21 KV,
601,248 bytes, in-repo test fixture (copied from team-04
hidden_files/fixtures; identical bytes).
sha256 57a81ed1c8b032ba29319eae80c3e568dbb5a16ce665a09da1a0efe2e4eb69e3
Small file: absolute times are sub-millisecond; ratios, not absolutes,
are the finding. A multi-GB model would scale the cold term with
bytes faulted in, not change the mechanism.

## Protocol (hidden_files/run_a031_bench.sh, log a031_bench.log)
- COLD: 5 x (sync; echo 3 | sudo tee /proc/sys/vm/drop_caches;
  fresh process, reps=3). Cold figure = rep 0 of each invocation.
- WARM: warmup process reps=3, then measured process reps=15.
- Conditions: quiet machine — loadavg 1.19 at start, no co-running
  builds/suites during the bench window (bench ran before the gate
  suite, sequentially). Walls are baselines for THIS fixture.

## Results (ns; medians)
| phase | cold (n=5, rep0) | warm (n=15) | ratio |
|---|---|---|---|
| meta (open+map+header+metadata+tokenizer init) | 559,126 | 57,467 | 9.7x |
| load (full mmap_and_load, in-process after meta) | 96,661 | 69,721 | 1.4x |
| total meta+load | 689,720 | 126,707 | 5.4x |
| enc (encode probe, tokenizer ready) | 36,849 | 24,285 | 1.5x |
Warm ranges: meta 54,392–132,087 (max = rep0 of measured process),
load 68,548–143,348 (same rep0 effect); steady-state reps cluster
meta 54–62k, load 69–76k, enc 24–34k. Every run: 48 tensors,
21 KV, 30 probe tokens — identical outputs, cold and warm.

## >2x anomaly — EXPLAINED (acceptance clause)
Cold/warm ratios of 9.7x (meta) and 5.4x (total) exceed 2x. Cause is
page-cache state, not loader code: the loader is mmap-based
(GGUFSeer._open_and_map) and tensor data is never copied at load —
 parse_tensors builds zero-copy descriptors. The first touch of the
file's pages therefore happens inside inspect_metadata (header +
metadata + tokenizer arrays are actually read), so after
drop_caches rep 0 pays the real NVMe read + page faults for the
601 KB file (~0.5 ms), while warm reps read the same bytes from
page cache (~57 us of pure parse CPU). load_ns shows no such ratio
because its pages were faulted in by the meta pass in the same
process, and tensor bytes are faulted lazily at first compute, not
at load. Prediction this makes: on a large model the cold penalty
concentrates in whichever phase first touches each region; load
itself stays descriptor-cheap. No code anomaly found.

## Suite gate
hidden_files/run_a031.sh — E-MASTER run_all, --target-accelerator
gfx1151, all 6 shims staged incl. libaesir_aff (affinity_shim.c).
- Attempt 1 (a031_run_all_attempt1.log, sha256
  4edd2050cc41021f721cefa90cee3acec28cab5ee7e004236492bf223bc9ebfd):
  355 passed / 2 failed / 2 skipped / 359. Extra failure =
  resilience.state_vault_rejects_growth — named member of the known
  rotating flake class.
- Re-run once, per flake protocol (a031_run_all.log):
  356 passed / 1 failed / 2 skipped / 359 total — exact seat
  baseline. Sole failure = gguf.tensor_directory_interface
  (pre-existing J-022 drift, tolerated). Skips = the 2 pre-declared
  (vision.cuda_session_image_chat, rag.real_engine_integration).
  FLAKE FILED: resilience.state_vault_rejects_growth, passed on
  the single re-run.

## Bugs
- None in loader/tokenizer code. One harness-side defect found and
  fixed during the run: first gate script's zero_copy shim compile
  line lost a path separator in transfer (libaesir_zc never staged,
  JIT symbol failure); fixed in run_a031.sh and re-run — recorded
  here so the failed attempt is not mistaken for an engine result.
