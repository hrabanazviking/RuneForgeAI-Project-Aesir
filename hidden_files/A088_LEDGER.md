# A-088 Ledger - HIP zero-copy measurement (team-18)

- Slice: A-088 - HIP zero-copy measurement. Managed-memory
  path vs the Vulkan residency path (A-064). Acceptance:
  numbers filed; residency design updated if HIP's model
  is better.
- Worktree: /home/volmarr/aesir-team-18, branch
  yrsa/aesir-team-18. Base: 3822d595 (banked main, 85 of
  216, A-085 closure). Banks only after A-086/A-087, in
  roadmap order, by the keeper at the seat. Never merge
  or push from this worktree.
- Team: 1 lead + 6 Mythic Engineering sub-agents (design
  axes, timing methodology, device-evidence checklist,
  comparability/oracle, verdict framing, suite
  integration - all six returned; consensus followed:
  doc+bench only, +0 suite cases, pin stays 594).

## Verdict (full doc: docs/bench/A088_HIP_ZERO_COPY_RESIDENCY.md)

A-064 residency STAYS for static weights; HIP managed is
NOT better for the residency workload (write-once, GPU-
read-many, CPU-read-never): GPU streaming and CPU write at
parity, residency alloc ~400x cheaper at 64 MiB. ONE sub-
case design rule adopted, measured first time on the
flags-7 type: no CPU-read buffer may use the A-064
residency type (CPU read 0.21-0.23 GB/s, 160-180x slower
than managed/cached at 33-42 GB/s); CPU-read/shared
buffers stay on HIP managed or Vulkan HOST_CACHED (A-019
split, now flags-7-quantified). A-085 NOT re-litigated:
Vulkan PRIMARY, HIP PARKED probe-only, unchanged.

## Deliverable

- aesir_engine/tests/bench_zero_copy_residency_a088.mojo
  (new, standalone bench; sha256 b2275a38...): three paths
  at 64 MiB (HIP managed / VK residency flags 7 / VK
  cached flags 14), identical CPU code, 2 warmup + 7 timed
  GPU reps median, plus a timed resident Q8_0 GEMV section
  on one A-064 allocation.
- docs/bench/A088_HIP_ZERO_COPY_RESIDENCY.md (new): the
  filed numbers + verdict + design rule.
- hidden_files/run_a088_bench.sh, run_a088_suite.sh.
- Doc+bench only: +0 run_all cases, pin stays 594.

## Numbers (READ FROM hidden_files/a088_bench.log run 3 +
## a088_bench_run2.log; both PASS, BUILD_EXIT=0, RUN_EXIT=0)

Filed ranges span runs 2-3 (run 2 load 0.74/1.07/0.93;
run 3 load 2.92/1.54/1.10): HIP managed alloc 1.79-1.87 ms,
CPU write 13.4-19.3 GB/s, GPU traffic 211-221 GB/s, CPU
read 37.4-41.9 GB/s, launches_delta=9, memcpy=0, bad=0.
VK residency flags=7: alloc 0.004-0.005 ms, CPU write
14.4-20.3 GB/s, GPU 193-200 GB/s, CPU read 0.21-0.23 GB/s,
copy=0, acct_unchanged=true, bad=0. VK cached flags=14:
alloc 0.69-0.75 ms, CPU write 18.6-19.0 GB/s, GPU 194-199
GB/s, CPU read 33.1-40.8 GB/s, copy=0, bad=0.
Resident GEMV 64x1024: dispatch_delta=9, median
140-143 us, oracle worst 2.48e-05 (inside A-064's 1e-3
bound, bit-identical across runs), acct unchanged.
Log sha256: a088_bench.log be10b78a..., run2 2ab9892a...
Bench source sha256 b2275a38...
Device evidence: HIP count=1, total 133,143,986,176 B;
Vulkan vendor 0x1002 RADV type=1 (integrated), llvmpipe
refused by assertion.

## Ruler defects found and FIXED in-slice (bench only)

1. Run 1 (superseded, not filed): CPU write 6.17 GB/s on
   all paths - fill pattern used 64-bit % 997 per element
   (ALU-bound ruler). Fixed to bitmask patterns; re-run.
2. Run 1 GEMV worst 8.3e-03 vs the 1e-3 bound: bench
   inputs were |x| up to ~400 (~250x A-064 scale) - a
   scale artifact. Inputs reset to A-057/A-064 scale;
   worst 2.48e-05. No engine bug found.

## Suite (counts READ FROM LOGS)

- Run 1 (a088_run_all_run1.log, sha256 df3bb286...):
  589 passed / 3 failed / 2 skipped / 594. Failures:
  J-022 (pre-existing) + BOTH named pre-existing
  intermittents (resilience.state_vault_rejects_growth,
  gpu.amd_hip_stream_async_round_trip).
- Run 2 (a088_run_all.log, sha256 5547ef93...), solo,
  ps-verified no other suite live: 591 passed / 1 failed
  / 2 skipped / 594 = EXACTLY the base baseline. Sole
  failure J-022 gguf.tensor_directory_interface. Both
  intermittents PASSED run 2. Delta vs baseline: +0/+0/+0
  (doc+bench slice). MOJO_EXIT=1 is the J-022 failure
  alone. Bench runs were deferred while team-19 suites
  were live (09:44 and 09:51 starts); suite run solo.

## Bugs

None in engine code. No bug carried forward from this
slice; the two intermittents remain pre-existing with
their named homes (A-053 / A-022 lines), unchanged.
