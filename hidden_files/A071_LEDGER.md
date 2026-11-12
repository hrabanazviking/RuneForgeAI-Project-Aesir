# A-071 Ledger — Async dispatch (team-01)

- Date: 2026-11-12. Lead + 6 Mythic Engineering sub-agents
  (design notes only, device work by the lead). This ledger
  and the commit were completed by a fresh lead finishing
  the slice: the previous lead had built and tested
  everything below and was cancelled after the suite
  finished, before committing (verified from disk).
- Base: worktree HEAD 8a548607 (banking closure, 68 of 216
  banked) on yrsa/aesir-team-01. Built ahead in parallel:
  A-069 and A-070 were being banked by a coordinator
  concurrently; A-071 banks only after A-070 in roadmap
  order. Keeper reconciles the run_all pin union at
  banking (A-068 precedent). Untracked
  aesir_engine/hip_bridge.c left untracked and out of the
  commit, per standing instruction.

## What was built

- aesir_engine/core/vulkan_async.mojo — VulkanAsync
  gateway: async mode over the A-014 shim context. With
  async ON, every banked dispatch gateway records two GPU
  timestamps (TOP_OF_PIPE at command-buffer begin,
  BOTTOM_OF_PIPE before end), submits with its own fence
  and returns WITHOUT any host wait — no vkQueueWaitIdle
  anywhere in the async path. Per-dispatch Vulkan objects
  move into a deferred ring in the shim and are destroyed
  only after their fence completes. Same-queue in-order
  execution preserves every data dependency between
  queued dispatches, so correctness needs no host sync
  inside a token; the host waits exactly once per drain
  (one vkWaitForFences for the whole pending batch),
  which is where host-wait time is measured. GPU busy
  time is the sum of timestamp-pair durations scaled by
  limits.timestampPeriod; a drain batch span is
  (max end - min begin), so busy fraction = busy / span.
  With async OFF every dispatch keeps the exact legacy
  submit + vkQueueWaitIdle tail (the banked synchronous
  path). Fail-closed: set_mode(True) raises when the
  loader, dispatch entry points, or fence entry points
  are unavailable — no host fallback is fabricated.
  Timestamp absence degrades honestly: stats.ts_ok is
  False and busy/span read 0 (filed as such).
- aesir_engine/vulkan_buffer_shim.c — the A-071 async
  section: queued submission path, per-dispatch fences,
  deferred-destruction ring, timestamp query plumbing,
  and the async counters (submits / completed / pending /
  max_depth / wait_idle_calls / fence_waits /
  host_wait_ns / gpu_busy_ns / gpu_span_ns) — the law-6
  device-execution evidence; counters move only on real
  device submissions. No host fallback: nothing in the
  shim computes model work on the CPU.
- aesir_engine/core/vulkan_decode.mojo — VulkanAsyncTrace
  + generate_async / generate_async_traced on
  VulkanDecode: the full decode loop driven through the
  queued path, returning per-token timeline rows
  (submissions drained, GPU busy ns, span ns, host wait
  ns per generated token).
- aesir_engine/tests/test_vulkan_async_a071.mojo — 6
  E-MASTER cases (gpu.vulkan_async_*) with the raw CPU
  oracle consuming the identical fixture (raw-oracle
  discipline: teacher-forcing token identity against the
  oracle, never a template-rendered prompt).
- aesir_engine/tests/run_all.mojo — import + 6 run_case
  lines; pin 518 -> 524.
- aesir_engine/a071_driver.mojo (+ working copies under
  hidden_files/) — standalone driver printing the
  per-token timeline trace (A071_TIMELINE_TRACE).
- aesir_engine/a071_sync_only.mojo /
  aesir_engine/a071_async_only.mojo — single-mode probes
  used to isolate the in-slice defects below.
- aesir_engine/tests/bench_async_dispatch_a071.mojo —
  sync vs async decode bench (same fixture, token
  identity gate before timing).

## Acceptance: token identity + timeline (raw-oracle)

Standalone driver (hidden_files/a071_driver_fixed2.log):
A071_DRIVER_ALL_PASS, MOJO_EXIT=0. All 6 cases PASS:

- Token identity: 8 generated tokens async == sync ==
  oracle at every step (12, 72, 74, 66, 66, 23, 26, 86);
  oracle logit gaps filed per step in the log.
- No per-token host sync: submits 374, completed 374,
  pending 0, max_depth 108, wait_idle 0, fence_waits 8
  (one fence drain per token, zero vkQueueWaitIdle).
- Timeline sane: busy fraction 0.109 in the suite case;
  driver trace totals submits 374, gpu_busy_ns
  1,445,943, gpu_span_ns 14,515,916, busy_fraction
  0.0996, host_wait_ns 4,380,117 over 8 tokens;
  per-token rows filed in the trace.
- Dispatch queueing: 16 queued GEMV submissions held
  pending mid-flight (pending 16, max_depth 16) with
  results exact after drain.
- Rejection: validation before mode-on, no residue.
- Dispatch evidence: submits 374, 37 per step,
  host_wait_ns/token 283,500 in the suite case.

Device-execution evidence (law 6): AMD Radeon 8060S
(RADV STRIX_HALO), llvmpipe refused by identity check.

Bench (hidden_files/a071_bench.log, ends A071_BENCH:
PASS, MOJO_EXIT=0): bench gate token identity sync ==
async PASS before timing. Sync generate median 96.90 ms
(12.11 ms/token) vs async generate median 33.79 ms
(4.22 ms/token) for the 8-token bench generation —
async ~2.9x faster end to end on this fixture. Async
totals on the last bench run: submits 374, max_depth
108, wait_idle 0, fence_waits 8, host_wait_ns total
2,684,793 (335,599 per token), busy_fraction 0.1045.

## Gate

Full E-MASTER suite (hidden_files/a071_run_all.log,
sha256 ead89ab03b1f592e4dded21964d7286609c81893a41cbaadcec98bc1d6bf5366):
521 passed / 1 failed / 2 skipped / 524 total = seat
pin 518 + exactly the 6 new gpu.vulkan_async_* cases,
all PASS. Sole failure: pre-existing tolerated J-022
drift (gguf.tensor_directory_interface). Skips: the 2
pre-declared.

Run-1 flake disclosed: the first suite run
(hidden_files/a071_run_all_run1_flake.log) counted
520 passed / 2 failed / 2 skipped / 524 total — the
second failure was memory.budget_live_meminfo_pressure
(live MemAvailable implausibly small under shared-
machine load), which passed on the counted re-run
above. Not an A-071 regression; filed, not hidden.

## Bugs / gaps found

- FIXED IN-SLICE (driver bring-up, from the diag logs):
  the first driver runs died with VkResult -4
  (VK_ERROR_DEVICE_LOST) inside the queued path —
  hidden_files/a071_driver.log at VulkanEmbed.gather,
  hidden_files/a071_driver_diag1.log at
  VulkanNormRope.rmsnorm. After that fix the cases all
  passed but teardown raised VAL-003
  (VulkanBuffers.allocate: invalid buffer id) in
  hidden_files/a071_driver_fixed1.log. The final driver
  (a071_driver_fixed2.log) is fully clean:
  A071_DRIVER_ALL_PASS, MOJO_EXIT=0, and the counted
  suite run carries the same final code. The sync-only
  probe passed throughout (SYNC_ONLY_PASS), pinning the
  defects to the async path, not the banked sync path.
- Scope boundary (honest): async dispatch covers the
  decode loop gateways on the one shim queue; same-queue
  in-order execution is the dependency mechanism — no
  cross-queue scheduling or multi-stream overlap is
  claimed. Prefill-side async overlap is future road,
  not claimed here.
- A-046:B1 CPU remainder still open (from A-059):
  core/compute.mojo gemm_iq demands cols % 256 for
  IQ4_NL (GPU path proven at K=288); fix home
  unchanged — not this slice's scope.

## Banking

Committed on yrsa/aesir-team-01, subject "A-071: Async
dispatch". NOT merged, NOT pushed — keeper banks after
A-070 in roadmap order.
