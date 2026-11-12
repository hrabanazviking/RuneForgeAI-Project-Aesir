# A-024 Ledger - Thread placement map (team-01)

Slice: A-024 - Zen 5 topology-aware affinity helper for CPU work
(16 cores / 32 threads). Machine: purpleraider (ASUS ROG Flow
Z13, AMD RYZEN AI MAX+ 395, Strix Halo, gfx1151). Base: seat main
c009928c (A-021, 21 of 216 banked; ls-remote verified
c009928c273e... at tick start); A-015 confirmed banked in seat
main by subject (af7bc591) before the branch reset --hard onto
c009928c. A-022/A-023 were banking concurrently - no rebase.

## Acceptance verdict: PASS

- Affinity API built (below), E-MASTER cases green, and the
  benchmark shows the DEFAULT placed configuration (SPREAD) is
  never worse than unplaced at either measured worker count,
  under the pre-registered verdict rule. Two non-default variants
  measured WORSE in specific shapes and are filed as losing
  below - they are not the default and are kept for the coupled-
  work / single-CCD cases they exist for, with the numbers as
  the warning label.

## Topology facts (read from the machine itself, this run)

- lscpu: AMD RYZEN AI MAX+ 395, family 26 model 112; 32 CPUs
  online (0-31), 16 cores/socket, 2 threads/core, 1 socket,
  1 NUMA node (node0 = 0-31). L3 64 MiB in 2 instances.
- SMT pairs (thread_siblings_list): (n, n+16) for n in 0..15 -
  CPUs 0-15 are the first thread of cores 0-15, 16-31 the
  second threads (lscpu -p CPU,Core agrees exactly).
- L3 domains (cache/index3/shared_cpu_list, 32768K each):
  CCD0 = 0-7,16-23 (cores 0-7); CCD1 = 8-15,24-31 (cores 8-15).
- Process affinity at bench time: all 32 CPUs allowed.

## What was built

- aesir_engine/core/thread_placement.mojo - CpuTopology
  (validated parallel arrays: cpus / core_of / ccd_of),
  parse_cpu_list / format_cpu_list (kernel list grammar,
  fail-closed: empty, non-decimal, descending/open ranges,
  duplicates, ids > 8192 all raise), build_topology (sibling
  lists must partition the CPU set; L3 lists must be unions of
  whole cores covering every CPU - violations raise),
  observe_topology (live sysfs read; never raises, returns
  observed=False when unreadable), policy_order /
  placement_map / default_placement, apply_affinity /
  current_affinity (checked, read-back verified). Policies:
  SPREAD (default: physical cores first, interleaved across
  L3 domains, SMT siblings last), PACK (fill both SMT siblings
  per core in natural order), CCD_LOCAL (exhaust one L3 domain
  before spilling). Worker counts outside [1, logical] raise -
  nothing is clamped. Distinct from core/thread_topology
  (J-039 thread-COUNT ladder): A-024 owns WHICH CPUs.
- aesir_engine/affinity_shim.c - aesir_aff_apply /
  aesir_aff_read over sched_setaffinity/sched_getaffinity
  (0 ok, -1 invalid args, -2 syscall failure; the Mojo side
  raises on any non-zero, never assumes a placement took).
- aesir_engine/tests/test_thread_placement.mojo - 6 cases:
  cpu.thread_placement_list_parse (grammar + 13 malformed
  shapes rejected), cpu.thread_placement_topology_build
  (Z13 shape from the exact sysfs strings + overlap /
  core-split / missing-CPU rejections),
  cpu.thread_placement_map_spread (8 = [0,8,1,9,2,10,3,11];
  16 = one per physical core; 17th worker takes cpu16),
  cpu.thread_placement_map_pack_ccd (pack 4 = [0,16,1,17];
  ccd_local 8/16/20 incl. CCD1 spill),
  cpu.thread_placement_reject (workers 0/-1/33/1000, unknown
  policy, unobserved topology, empty affinity set),
  cpu.thread_placement_live_affinity (live sysfs: 32/16/2 +
  (0,16) pairing asserted; apply a 1-CPU placement, kernel
  readback equals, original mask restored and re-verified).
- run_all.mojo: +6 registrations, pin 338 -> 344.

## Benchmark (hidden_files/a024_bench.py; log a024_bench.log
## sha256 981e98a1d37ee6c58d440dc56522a7deaa446a6258177a7b167ab6ca8b77c52b;
## json a024_bench.json sha256 b9fc880ba2162a07298f8ede1239cc9dfabf06bd5282b8990670083e9b8aef56)

Method (pre-registered in the script header): W forked worker
processes run fixed deterministic integer work (900k iterations,
checksum verified against the serial oracle in every worker);
placed workers pin themselves via os.sched_setaffinity and
verify the readback before timing. 7 rounds per config, configs
interleaved in rotating order; parent wall seconds per round.
Verdict rule: WORSE iff median > unplaced median x 1.05 AND
min > unplaced min x 1.02 (the J-039 5% noise band). Run at
load ~2.9 after other campaigns' probes drained (an earlier
attempt under a 28-thread neighbour probe was discarded).

Rounds (s) and medians, verbatim from a024_bench.json:
- 8w unplaced: [0.1239 0.1138 0.1124 0.1166 0.1169 0.1166
  0.1170] median 0.1166, min 0.1124, max 0.1239
- 8w spread (default): [0.1227 0.1162 0.1156 0.1203 0.1167
  0.1168 0.1171] median 0.1168, min 0.1156, max 0.1227
  -> NOT-WORSE (+0.2% median, inside the noise band)
- 8w ccd_local: median 0.1138, min 0.1100, max 0.1161
  -> NOT-WORSE (fastest at 8w; one CCD's physical cores)
- 8w pack: median 0.1872, min 0.1822, max 0.1926 -> WORSE
  (+61% median: 8 workers on 4 physical cores x SMT pairs.
  Filed as losing for independent work; the module header
  carries the same warning. NOT the default.)
- 16w unplaced: median 0.1451, min 0.1407, max 0.1537
- 16w spread (default): [0.1521 0.1445 0.1437 0.1424 0.1466
  0.1439 0.1453] median 0.1445, min 0.1424, max 0.1521
  -> NOT-WORSE (-0.4% median vs unplaced)
- 16w ccd_local: median 0.1966, min 0.1949, max 0.2028
  -> WORSE (+35%: all 16 workers incl. SMT siblings inside
  CCD0 while CCD1 idles - the expected shape limit of the
  policy at full-core counts; fine at <=8 workers.)
Default decision: SPREAD stays the default - it is the only
policy never worse at both counts. No adjustment needed.

Bug found + fixed in-slice (bench harness, first bench run):
Python 3.14 multiprocessing defaults to forkserver, whose
children re-import the module and saw the serial-oracle global
as None, so every worker reported a checksum mismatch. Fixed
by passing the oracle as an explicit process argument and
pinning the fork start method via get_context('fork'). The
workload itself was verified deterministic in-process first.

## Suite (hidden_files/run_a024.sh - the A-021 canonical shape
## re-pointed at team-01 + libaesir_aff staging)

Gate run (hidden_files/a024_run_all.log, sha256
1182aa1fc6c156fa473ac23e00450f59b9174a2a56939fe3a3ff83cdf554c4e2):
341 passed / 1 failed / 2 skipped / 344 total. Baseline at
c009928c: 335 / 1 / 2 / 338 - delta is exactly the 6 new
A-024 cases (all [CASE PASS]), zero regressions. Sole failure
= gguf.tensor_directory_interface, the pre-existing J-022
drift (roads A-165 / A-121), unchanged and tolerated.
Skips = same 2 pre-declared. MOJO_EXIT=1 is by suite design.

Flake record (filed honestly, logs kept as *_run1/2/3.log):
runs 1-2 also failed resilience.state_vault_rejects_growth
(an intentional TOCTOU race test: a forked 1-byte-at-a-time
appender vs repeated reads) and run 3 instead rotated in
gpu.amd_hip_mem_get_info_accounting (free-memory baseline off
by exactly 1 MiB - a neighbour process touched the shared
iGPU mid-run), while state_vault passed. Neither case is in
code this slice touches, and the same state_vault failure +
pass-on-rerun pattern appears in team-06's A-026 logs and
team-09's A-023 logs from the same night - shared-machine
contention flakes, resolved by the clean gate run above,
which is the run this slice banks on.

## Files in this slice

- aesir_engine/core/thread_placement.mojo (new)
- aesir_engine/affinity_shim.c (new)
- aesir_engine/tests/test_thread_placement.mojo (new): 6 cases.
- aesir_engine/tests/run_all.mojo: +6 registrations, pin 344.
- hidden_files/a024_bench.py (new, benchmark harness),
  hidden_files/run_a024.sh, hidden_files/A024_LEDGER.md
  (tracked, per house precedent); run logs + bench json stay
  on-device. NOTE: untracked aesir_engine/hip_bridge.c
  (unconfirmed provenance) deliberately left untracked and
  out of this commit, as instructed.
