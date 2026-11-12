# A-026 Ledger - Arena/pool allocator for inference (team-06)

- Slice: A-026 Arena/pool allocator for inference (Wave 3, roadmap order)
- Worktree: /home/volmarr/aesir-team-06, branch yrsa/aesir-team-06
- Base: c009928c (A-021 banked; 21 of 216). Verified at setup: seat log
  8c14c873 "A-020: Weight residency" present; team branch reset --hard
  onto c009928c per tasking (A-022/A-023 bank concurrently; no rebase).
- Status: COMPLETE - committed on yrsa/aesir-team-06, awaiting keeper
  banking in roadmap order. No merge/push by the team. No README touched.

## What was built

- aesir_engine/core/arena_allocator.mojo:
  - ArenaLedger: pure per-arena accounting in the A-023 governor style
    (exact integer ledgers; admission BEFORE charging; checked release).
  - RequestArena: one per-request arena over ONE A-019 ZeroCopy backing
    (HIP managed default). Bump carving admitted through checked_span;
    16-byte alignment; free_last stack-order rewind; mark/rewind
    (top or 0 only, else fail-closed); reset() frees ALL activations of
    a request in O(1) bookkeeping and returns carved/live/blocks
    exactly to baseline (cumulative history counters kept, governor
    style).
  - ArenaPool: fixed pool of arenas; acquire fails closed (MEM-003)
    when exhausted; release resets + returns the arena; double release
    refused (MEM-005); close() releases every backing exactly once.
  - Taxonomy (ERROR_TAXONOMY.md): MEM-001 non-positive size/capacity,
    MEM-003 over-capacity admit / pool exhaustion, MEM-005 non-top or
    double release.
- aesir_engine/tests/test_arena_allocator.mojo: 5 cases wired into
  tests/run_all.mojo (pin 338 -> 343 with re-pin comment).

## Fragmentation stress (acceptance evidence)

- gpu.arena_fragmentation_stress: 10,000 deterministic (LCG) mixed
  ops - alloc (55%), stack free (30%), reset (15%), sizes 16..8207 B,
  8 MiB arena; ledger invariants asserted every op.
- Measured (identical in both suite runs): ops=10000
  total_requested=26193248 peak_requested=106597 peak_carved=106800
  waste_bytes=203 allocs=6394 frees=2401 resets=1205.
- Waste definition: peak alignment padding = peak_carved -
  peak_requested = 203 B on 106,597 B peak live = 0.19%. External
  fragmentation is zero by construction (bump + stack/reset only);
  bound asserted in-case (padding <= 15 B per block). Baseline exact
  after final reset.

## Commissioned in-slice bug fix: zero_copy_shim 4096-slot registry

- Bug (team-09 A-023 audit): banked aesir_engine/zero_copy_shim.c
  recorded HIP allocation sizes in a fixed 4096-slot table. Past 4096
  concurrent allocations an allocation still succeeded and
  g_live_bytes was incremented, but the size was never recorded, so
  the matching free never decremented - live-bytes drifted upward
  permanently.
- Fix chosen: GROWABLE registry (the A-022 ownership law makes the
  registry, never the raw pointer, the ownership record - silently
  losing a record is the one outcome that law forbids; a hard cap
  would have changed allocator semantics for legitimate callers).
  g_ptrs/g_sizes are now heap arrays, capacity doubling from 1024
  via zc_registry_reserve(). Growth failure is fail-closed: the
  fresh HIP allocation is freed, accounting untouched, return -4.
  Every successful allocation is always recorded, so every free
  decrements exactly what its allocation added.
- A-022 union note: A-022 (team-08, unbanked at this base) adds a
  parallel g_states[] over the same slots plus peer cross-checks
  (aesir_zc_own_live / MEM-013). At banking union, g_states must
  grow inside the same zc_registry_reserve() helper so the arrays
  never diverge; the cross-check functions are unaffected (pure
  lookups over the same registry).
- Regression: gpu.arena_shim_registry_over_4096 - 5,000 concurrent
  ZeroCopy allocations (256..320 B, total 1,440,000 B): live-bytes
  delta exactly 1,440,000 while live; after freeing all 5,000,
  shim live-bytes returned EXACTLY to baseline 0 (both runs:
  SHIM_REGISTRY_OK concurrent=5000 bytes=1440000).

## Suite (counts read from log files, never memory)

- Runner: hidden_files/run_a026.sh (canonical E-MASTER shape).
- Run 1 (hidden_files/a026_run_all.log, sha256
  7c0b0848bcf1bae6598b0797943f7e43d36ab8d7bf7cd60434cae8203e2ae0e8):
  339 passed / 2 failed / 2 skipped / 343. Second failure was
  resilience.state_vault_rejects_growth - a fork/append TOCTOU race
  test (child appends 20,000 single bytes while parent reads); it
  flipped under concurrent Tensile jobs=12 load on the shared box.
- Run 2 (hidden_files/a026_run_all_run2.log, sha256
  070932b90cdb92c466839398b1bd0a0df81fd46c489710fe3f8bce296f5d06fb):
  340 passed / 1 failed / 2 skipped / 343 total = seat baseline
  335/1/2 of 338 + 5 new A-026 cases, ALL PASSING. Sole failure:
  pre-existing gguf.tensor_directory_interface J-022 drift
  (tolerated; roads A-165/A-121; NOT fixed here per tasking).
  state_vault_rejects_growth PASSED on re-run - run-1 verdict:
  comparator/load flake, not an A-026 regression (A-026 touches no
  file-IO path; the shim change is HIP registry bookkeeping only).
- All five A-026 cases PASS in both runs: gpu.arena_reset_semantics,
  gpu.arena_rejection, gpu.arena_fragmentation_stress,
  gpu.arena_pool_device (real HIP backings on the 8060S),
  gpu.arena_shim_registry_over_4096.
