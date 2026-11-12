# A-012 — HIP transfer + streams (team-03 ledger, filed 2026-11-11)

Slice: Memcpy H2D/D2H and stream sync vs a CPU oracle buffer, incl.
async overlap smoke. Acceptance: byte-exact round trips; timing filed.
OUTCOME: PASS with REAL device execution on the Radeon 8060S via the
distro HIP runtime (libamdhip64.so.7) — not honest-absent.

## Basis

Built on team-02's A-011 (HIP memory) exactly as directed: A-011 commit
83c9fdf9 cherry-picked onto this branch as fab684da (identical content,
new hash), so this slice's commit stands on the A-011 shim + HipMemory.
Banking stays in roadmap order: A-004..A-011 bank first; this worktree
never merges or pushes. The A-011 pattern is reused throughout: all
dynamic loading lives in the C shim (Mojo 1.0 dlopen/OwnedDLHandle
conflict, see A011_LEDGER.md); scripts/launch.py still does NOT stage
libaesir_hip — the first slice that calls HIP from the main engine
path must wire it (unchanged from A-011's note; A-012 is test-path).

## What was built

- aesir_engine/hip_memory_shim.c (extended): resolves + wraps
  hipStreamCreateWithFlags / hipStreamDestroy / hipStreamSynchronize /
  hipStreamQuery / hipMemcpyAsync / hipHostMalloc / hipHostFree /
  hipEventCreate / hipEventRecord / hipEventSynchronize /
  hipEventElapsedTime / hipEventDestroy behind flat aesir_hip_* ABI
  (handles as uint64 addresses). New probe symbol
  aesir_hip_transfer_available() keeps A-011 availability semantics
  untouched. Streams are created hipStreamNonBlocking.
- aesir_engine/core/hip_transfer.mojo (new): HipTransfer (pinned
  hipHostMalloc/hipHostFree + synchronous device-to-device hipMemcpy),
  HipStream (create/destroy/synchronize/query_complete +
  memcpy_async H2D/D2H/D2D), HipEvent (create/record/synchronize/
  elapsed_ms/destroy). Byte counts admitted via core/checked_span;
  zero/destroyed handles rejected locally before any FFI call;
  fail-closed when the runtime or transfer symbols are absent.
- aesir_engine/tests/test_amd_realm.mojo: +5 cases (below), each with
  an honest-absent fail-closed branch; uses monotonic_milliseconds
  (core/generation_control) for wall timings.
- aesir_engine/tests/run_all.mojo: +5 registrations, pin 285 -> 290,
  canonical command unchanged (already stages libaesir_hip, A-011).
- hidden_files/run_a012.sh + this ledger (tracked, per A-011/A-003
  precedent); run logs + probe source stay on-device (untracked).

## Semantics proven on-device BEFORE the wrapper was written

C probe (dlopen/dlsym, no headers; hidden_files/a012_c_probe.c, log
below): DEVICE_COUNT 1; sync round trips byte-exact (1B/4097B/1MiB);
async pinned 64 MiB H2D+D2H round trip on one stream byte-exact;
hipStreamQuery returns 600 (hipErrorNotReady) while a 64 MiB H2D is in
flight and 0 (hipSuccess) after hipStreamSynchronize — the wrapper's
query_complete() encodes exactly those two codes and raises on any
other. Stream handles are non-null.

## Timings filed (all on purpleraider, this slice)

C probe (clock_gettime wall; hidden_files/a012_c_probe.log):
- Event-timed async 16 MiB H2D + 16 MiB D2H: 1.271 ms
  (hipEventElapsedTime).
- Sync hipMemcpy: 16 MiB x 20 (H2D+D2H) in 12.3 ms = 54.57 GiB/s.
- Async pinned hipMemcpyAsync (enqueue 20 pairs, one sync): 7.5 ms =
  89.78 GiB/s, byte-exact.
- Overlap smoke: 4 streams x 8 MiB (H2D+D2H), enqueue-all/sync-all:
  1.6 ms, byte-exact on all streams. Same work sequentially on one
  stream: 1.0 ms. NO OVERLAP SPEEDUP — see honesty note.

Mojo battery (suite log; monotonic_milliseconds wall, 1 ms grain):
- Sync: 10 x (4 MiB H2D + 4 MiB D2H) = 80 MiB in 2 ms.
- Overlap smoke: 4 streams x (2 MiB+2 MiB) enqueued-then-synced 1 ms;
  same work on one stream 1 ms.
- Event: 4 MiB H2D + 4 MiB D2H async on one stream = 0.473 ms
  (hipEventElapsedTime, device-measured; runner log run: 0.472 ms).

OVERLAP HONESTY: at every probed size, concurrent streams were
byte-exact but never faster than one stream (twice marginally slower).
On Strix Halo's unified-memory pool these transfers appear bounded by
the shared memory path, not by stream parallelism. The acceptance's
"async overlap smoke" is therefore filed as a concurrent-stream
CORRECTNESS smoke with timings — no speedup is claimed anywhere.

## Test evidence (counts read from logs, never memory)

- Standalone AMD/HIP runner (13 cases: 3 gate + 5 A-011 + 5 A-012):
  ALL PASS, A012_RUNNER_ALL_PASS. hidden_files/a012_runner.log
  sha256 cf4a77db0bd28122dd2ec3e7358ce6bda8be052512042066c20f00ec61a6d67d
- New A-012 cases, all PASS with real execution:
  gpu.amd_hip_sync_oracle_round_trip (1B/7B/4KiB/1MiB+1 via
  H2D + D2D + D2H vs CPU oracle pattern, byte-exact),
  gpu.amd_hip_stream_async_round_trip (1 MiB+13 pinned, async
  H2D+D2H, stream sync, query-complete afterwards, byte-exact),
  gpu.amd_hip_stream_overlap_smoke (4 streams enqueue-all/sync-all,
  byte-exact per stream + one-stream comparison timings printed),
  gpu.amd_hip_event_timing (device-measured elapsed, plausible-range
  asserted, byte-exact), gpu.amd_hip_stream_rejection (zero handle,
  double-destroy, use-after-destroy, record-after-destroy,
  non-positive pinned size — all rejected).
- E-MASTER full suite (hidden_files/run_a012.sh; log
  hidden_files/a012_run_all_canonical.log sha256
  bc1d0b564d1830d5d015c535e698869a1beefb8e7ed3ac5b1ef8ffd195493821):
  Passed 287 / Failed 1 / Skipped 2 / Total 290, wall 1:11.21.
  Baseline (A-003) 277/1/2/280 + A-011's 5 + A-012's 5 = exactly this;
  zero regressions. Sole failure = gguf.tensor_directory_interface,
  the pre-existing J-022 drift triaged in A-003 (roads A-165/A-121) —
  unchanged. Skips = the same 2 pre-declared
  (vision.cuda_session_image_chat, rag.real_engine_integration).
  MOJO_EXIT=1 is by suite design (any failed case raises in
  ledger.finish).
- C probe log: hidden_files/a012_c_probe.log sha256
  12520c63cb47cc910b487dcbdf5989405406ef54a1b81c66d7a7078deb0336ce

## Bugs / notes

- No new repo bug discovered this slice. (Two authoring slips of my
  own — a POSIX feature-macro in the probe and an unwritten import
  edit — were caught by compile/run evidence and fixed before any
  test ran; neither touched shipped code.)
- Neighbours: A-082/A-083 (HIP GEMV) build on this gate: streams,
  pinned staging and event timing are now available from
  core/hip_transfer.mojo. scripts/launch.py libaesir_hip staging is
  still owed by the first main-engine-path HIP slice.
