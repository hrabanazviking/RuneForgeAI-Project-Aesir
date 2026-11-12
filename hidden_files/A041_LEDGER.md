# A-041 Ledger -- Thread scaling law (team-09)

- Base: 56d5606f6684b7d0f9de93b5bd30f384fe2ed7ab (seat main, A-039
  banked; 39 of 216). Branch yrsa/aesir-team-09 reset --hard onto
  it; prior CAMPAIGN_STATE.md/hidden_files backed up to
  /tmp/t09_a041_backup_state.md + /tmp/t09_a041_backup_hidden and
  restored. /tmp/toolstage*.log and /tmp/pkginstall.log absent
  (finished) at tick start; load 0.67/1.05/1.00 -- light.
- Roadmap: "A-041 -- Thread scaling law. Decode scaling 1->32
  threads measured; the choke-guard default (leave headroom for
  the machine's other work) chosen from the curve. Acceptance:
  scaling table filed; default thread policy implemented +
  tested." Census assignment: A-037's doc states "A-041 cites
  C-008", and team-04 recorded the C-008 fix's natural home as
  A-041 -- so the config-cache fix is IN this slice's scope.
- Filed law: docs/bench/A041_THREAD_SCALING_LAW.md (scaling
  tables, the three-part law, choke-guard rule, C-008 proof).

## What was built
- aesir_engine/tests/bench_thread_scaling_a041.mojo (new,
  sha256 485e225838fc077ff9fe1cba21a86bd136f796fc487b8f8729b28c15973ea2f8):
  per-process-rung bench -- A-037-fixture decode (oracle-exact
  every rep) + engaged-regime GEMV (K=4096 x N=11008 via
  par_for; checksum 1113.8164 at every rung, both sweeps).
- hidden_files/run_a041_sweep.sh (sha256
  88d93f602f78fb8fc3b35da7a228061391359613fc93dcf6bd2138d43ab1135d):
  rungs default,1,2,4,6,8,12,16,20,24,28,32 x 3 trials at
  AESIR_PAR_MIN_WORK=1 + production-threshold rows x 2 trials.
  Logs: a041_sweep_before.log sha256
  936ae9b9a4a43d849703bd2e95a3fc9a980614ad9906bf6b8f06239faaa3a678;
  a041_sweep_after.log sha256
  b373fef667e7dd892e8d1a1ca45101f6334838967471cfe7f1a1d7928857698f.
  The two curves agree in shape at every rung (stability check).
  Headline (after, medians): GEMV 69.952 ms @1 -> 7.286 @16
  (9.60x) -> 7.102 @24 (9.85x) -> 6.433 @32 (10.87x); decode
  with forced engagement 16028.4 tok/s serial, 1398.5 @2,
  62.8 @32 (threading sub-threshold dispatches is catastrophic
  at every count); production-threshold decode ~16050-16079
  tok/s regardless of thread count (threshold keeps it serial).
- Choke-guard default: 24 of 32 on the Z13 (~90% of peak GEMV
  speed, a quarter of the machine left for other work).
  Implemented as par_default_threads + par_resolve_threads in
  aesir_engine/core/parallel.mojo (sha256
  dc9b3b39bcae8eb2c4955ca307d0253ca69552e03f164cd3ecd12a4c325cd262);
  explicit AESIR_THREADS precedence unchanged.
- C-008 fix: aesir_engine/thread_par.c (sha256
  7f739aec3cfde21d4d2e6913dc21db65ab018846114ceeeeea4fa432ce01762a)
  -- sysconf result cached after one probe; AESIR_THREADS /
  AESIR_PAR_MIN_WORK parsed once into a shim snapshot with
  _env_int's exact semantics; counters aesir_par_sysconf_probes
  / aesir_par_env_reads expose the proof. parallel.mojo getters
  read the snapshot; par_refresh_config() is the only re-read.
  aesir_engine/core/thread_topology.mojo (sha256
  589a91e73f120f1a819fc7da2bd1faa098e516c2c293f76ff63446c2f5e6d58d):
  set/clear_thread_knobs call par_refresh_config() after each
  setenv/unsetenv, preserving the J-039 readback contract.
  aesir_engine/tests/test_thread_topology.mojo: the cleared-knobs
  expectation now names the A-041 default policy (was the raw
  online-CPU count); the file still compiles standalone
  (mojo build exit 0, only pre-existing alloc warnings). Its
  live-trials case still targets a 4-CPU VM by design and is
  not part of run_all -- unchanged from before this slice.
- Tests: aesir_engine/tests/test_thread_scaling.mojo (new,
  sha256 b8dbe434a41f608fe507fe1e443671073446ae98dcedda95a4bf5f558b72c39d),
  six cases cpu.thread_scaling_* registered in run_all.mojo;
  pin 389 -> 395.

## C-008 perf proof (A-037 method, unmodified A-037 driver)
- hidden_files/run_a041_perf.sh reruns the census exactly
  (perf record -F 997 -g, 1200 reps, oracle-exact; run printed
  16078.0 tok/s). Report: a041_perf_report_nochildren.txt
  sha256 85ea62cb5209e2a64175c597d502354fdb503e40018f9f6050e8a135fd3f7b61;
  perf.data sha256
  5d62dd262ac196265b9369a60c9d782fb8874ba3b786b3ce6312f325e6a038b2.
  All ten C-008 member symbols from the A-037 table are absent;
  residual config symbol aesir_par_cpu_count = 0.08% self-time.
  Grouped C-008: 12.81% -> ~0.08%. Absolute rates not compared
  across profile windows (boost/load state differed).

## E-MASTER suite
- hidden_files/run_a041.sh (sha256
  99764ffac1e644a19aa0f7dfb55a318351fff6bfbaa52d802176c8576a5d33a7),
  canonical seat-gate shape, gfx1151, all shims staged.
- Log hidden_files/a041_run_all.log sha256
  d330e5b50ae58b7d425d7999192228eaad3eaeaeabd7ea87f0df063191b946df:
  392 passed / 1 failed / 2 skipped / 395 total = baseline
  386/1/2/389 + six new cpu.thread_scaling_* cases, all PASS.
  Sole failure = pre-existing tolerated
  gguf.tensor_directory_interface (J-022 drift, roads
  A-165/A-121). Skips = the 2 pre-declared. MOJO_EXIT=1 is the
  suite's normal exit with that one known failure present.

## Bugs found / disposition
- C-008 itself (12.81% of decode cycles re-reading config per
  dispatch): FIXED in this slice, proof above.
- Measured hazard (not a code defect): per-call pthread_create
  in the shim makes forced threading of sub-threshold decode
  dispatches up to ~250x slower than serial. Disposition: the
  production engagement threshold already guards it (PROD rows
  prove rate independence); a persistent thread pool would
  change this law and is recorded in CAMPAIGN_STATE.md as
  candidate future work, NOT fixed here (out of A-041 scope).
- Independent review flagged a possible 23-vs-24 char scan-bound
  divergence between the C snapshot parser and _env_int.
  Verified from source: both scan indices 0..23 (i < 24 in
  both), same NUL stop, same non-digit fallback, same
  >100000000 early return -- no divergence; not a bug.
- Sweep process note: the first before-sweep launch used 200
  decode reps/rung; the first threaded rung showed ~102 s/run,
  so it was stopped (by PID) and relaunched at 25 reps with a
  production-threshold section added. Its partial log was
  overwritten by the relaunch; only the final logs are claimed.
- One anomalous pair of trials: before-sweep PROD default
  decode median 8158.6 tok/s vs its own PROD 32-thread sibling
  15617.5 (same effective config on pre-fix code) -- judged
  environmental (contention during those two trials); the
  after-sweep PROD pair agrees (16050.8 / 16078.6). No code
  conclusion was drawn from the anomalous pair.
- Carried next work (pre-existing, out of scope): A-019
  zero-copy HIP shim accounting hole (4096-slot table) -- still
  open, recorded in CAMPAIGN_STATE.md.
- No README touched. No merge/push -- keeper banks in order.
