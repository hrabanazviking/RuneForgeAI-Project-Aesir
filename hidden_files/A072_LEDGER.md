# A-072 Ledger — Continuous batching v1 (team-02)

- Date: 2026-11-12. Lead + 6 Mythic Engineering sub-agents
  (design notes only, device work by the lead).
- Base: worktree reset onto the seat banking closure
  41ee6b77 (A-070 banked, 70 of 216) on yrsa/aesir-team-02.
  Previous slice A-069 verified banked by subject in the
  seat log (6a0b96dc "A-069: Chunked prefill" + closure
  faf8feb1) before the reset. A-071 banking was in flight
  in parallel at build time and landed during the gate
  runs (seat 7e550b82, 71 of 216); this slice was NOT
  rebased onto it — the keeper reconciles the union at
  banking, per orders.

## What was built

- aesir_engine/core/vulkan_batch.mojo — VulkanBatchDecode:
  an iteration-level scheduler decoding multiple sequences
  together on the GPU path, composed ONLY from banked
  gateways (the A-066 decode step: embed gather ->
  VulkanLayer.forward_kv -> final norm -> Q8_0 head ->
  greedy argmax). No new kernels, no new shim entries.
  Semantics: at most max_active sequences resident; free
  slots refill from the waiting queue in request order at
  iteration starts; a sequence admitted mid-run starts at
  position 0 with its own KV caches while batchmates are
  mid-context; one iteration advances every resident
  sequence by one position; a sequence leaves in the
  iteration of its final step and its caches are freed at
  once. Sequences share only the resident weights (A-064);
  KV caches, token streams, and positions are per-sequence,
  so each sequence performs bit-for-bit the solo A-066
  computation. Shared transients (x / normed / logits /
  tok_out / ping-pong scratch, A-070 discipline) are
  allocated once per run. VulkanBatchResult returns
  per-request outputs in request order plus admitted_at /
  finished_at / iterations for schedule verification.
  All validation is pre-dispatch and fail-closed,
  mirroring A-066; no host fallback.
- aesir_engine/tests/test_vulkan_batch_a072.mojo — 6
  E-MASTER cases (gpu.vulkan_continuous_batch_*) with the
  A-066 fixture and an independent sequential Float32 CPU
  oracle (raw prompt token ids, A-004 discipline).
- aesir_engine/tests/run_all.mojo — import + 6 run_case
  lines; pin 531 -> 537.
- aesir_engine/a072_driver.mojo (+ identical copy at
  hidden_files/a072_driver.mojo) — standalone driver.
- aesir_engine/tests/bench_continuous_batch_a072.mojo —
  aggregate tokens/s bench (4 solo serial vs 1 batch run).
- docs/bench/A072_CONTINUOUS_BATCHING.md — composition,
  scope honesty, measured numbers.

## Acceptance (standalone driver, hidden_files/a072_driver.log)

A072_DRIVER_ALL_PASS, MOJO_EXIT=0. All 6 cases PASS on AMD
Radeon 8060S (RADV STRIX_HALO; llvmpipe refused by identity
check), fixture dim 256 / 4 heads / GQA 2 / head_dim 64 /
ffn 512 / vocab 96 / 2 layers / max_len 16:

- 4-sequence run (prompts 3/2/5/1, 8 greedy tokens each,
  max_active 4): every sequence token-exact vs its
  VulkanDecode.generate solo run; sequence 0 also
  token-exact vs the CPU oracle (batch == solo == oracle).
  Dispatch deltas exactly the summed solo counts: embed
  39, KV-append 156 (39 x layers x 2), strided attention
  78, greedy 32. Live bytes back to baseline.
- Heterogeneous (gens 4/8/6/3): outputs match solo;
  finish iterations exactly 5/8/9/2 (totals 6/9/10/3).
- Dynamic admission (max_active 2): admissions 0/0/6/9,
  finishes 5/8/15/11, 16 iterations — freed slots refill
  the next iteration, mid-run, at position 0.
- Isolation: replacing sequence 0's prompt leaves
  sequences 1-3 token-identical (no KV cross-talk).
- Rejection: 7 of 7 invalid shapes raise pre-dispatch;
  embed/KV counters and live bytes unmoved.
- Single-slot (max_active 1): serialises to admissions
  0/10/19/31 over 39 iterations; outputs token-exact.

## Bench (hidden_files/a072_bench.log)

A072_BENCH: PASS, MOJO_EXIT=0. A-066 fixture at max_len
32, 4 prompts, 16 greedy tokens each (64 tokens/run),
median of 3 after a correctness-asserted warmup:
4 solo serial 0.6788 s = 94.28 aggregate tok/s; 1 batch
run (max_active 4) 0.6800 s = 94.11 aggregate tok/s;
ratio 0.998. Filed honestly: v1 issues the same
per-sequence dispatches under the scheduler, so it is
throughput-neutral by construction — the win is
continuous admission, bounded resident state, and
isolation. Fused batched dispatch is later work on the
A-068 GEMM road, not claimed here.

## Gate

Full E-MASTER suite (hidden_files/a072_run_all.log,
sha256 f3a3d36c38f0baa3278ec46415031b559cc0429c2b21b51d5e640810519cc90b):
534 passed / 1 failed / 2 skipped / 537 total = seat
baseline 528/1/2/531 + exactly the 6 new
gpu.vulkan_continuous_batch_* cases, all PASS. Sole
failure: pre-existing tolerated J-022 drift
(gguf.tensor_directory_interface). Skips: the 2
pre-declared. MOJO_EXIT=1 is driven solely by that
tolerated failure (same as every banked gate log).

Gate honesty — two flakes verdicted, not hidden: attempts
1-2 of the suite recorded extra intermittent failures
(attempt 1: gpu.amd_hip_stream_async_round_trip MEM-004 +
memory.budget_live_meminfo_pressure, log kept as
a072_run_all_attempt1.log; attempt 2: the HIP case only,
a072_run_all_attempt2.log). Neither case is touched by
this slice and the HIP case executes BEFORE any A-072 case
in run order. Verdict evidence: the HIP case PASSES in
isolation on this tree (hidden_files/a072_hip_isolation.log),
PASSED in the seat A-071 gate minutes earlier
(aesir-forge/hidden_files/seat_gate_a071.log: 534/1/2/537),
the meminfo flake is independently recorded by team-01
(a071_run_all_run1_flake.log, same case, re-run clean),
and attempt 3 on an idle machine is fully clean at the
expected counts. Verdict class: environment/timing
intermittents in neighbouring cases (async-copy ownership
race + live-meminfo sampling under parallel campaign
load), not A-072 regressions.

## Bugs / gaps found

- FOUND + FIXED in-slice (test hygiene): the A-072 test
  cases initially never freed their uploaded fixture
  weights; the Vulkan shim caps live buffers at 128 slots
  (AESIR_VK_MAX_BUFFERS), so the sixth case starved on
  allocation ("invalid buffer id") after five cases x 21
  weight buffers leaked. Fixed with _free_weights() at the
  end of every case; the bench frees its weights too. The
  A-066 test file has the same latent pattern with fewer
  cases (4 x 21 = 84 slots — under the cap, no failure
  observed); hardening it is NOT this slice's scope and is
  recorded here as the immediate candidate next work for
  whichever slice next touches that file.
- Dependency recorded (per orders): A-071 async dispatch
  was unbanked at build time. A-072 builds only on the
  banked A-066/A-069 synchronous interfaces and references
  no A-071 symbols. A-071 has since banked (46cefc41);
  its queued-submission model slots under this scheduler
  without changing scheduler semantics — re-wire is
  future work, not a defect in this slice.
- Scope boundary (honest): dense Q8_0 small-fixture model
  (A-066 class), one token per sequence per iteration;
  no prefix sharing, no preemption, no fused batched
  GEMV. A-046:B1 CPU remainder still open (from A-059) —
  unchanged, not this slice's scope.

## Banking

Committed on yrsa/aesir-team-02, subject "A-072: Continuous
batching v1". NOT merged, NOT pushed — keeper banks in
roadmap order from the seat (A-071 now banked, so A-072
is next in order).
