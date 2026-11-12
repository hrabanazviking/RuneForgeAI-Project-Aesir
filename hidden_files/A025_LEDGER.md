# A-025 Ledger — Copy-path verdict

- Slice: A-025 — Copy-path verdict (Wave 3). Roadmap: docs/AESIR_Z13_MASSIVE_ROADMAP.md.
  "If any staged copy remains necessary, measure pinned-staging vs direct
  paths. Acceptance: numbers filed; the slower path removed or justified in
  the memory design doc."
- Team: team-02 lead + 6 Mythic Engineering sub-agents (audit, banked-evidence
  review, design-doc hunt, instrumentation survey, seat verification,
  baseline/suite mechanics) — reports folded in; every load-bearing claim
  re-verified by the lead from the banked tree at c009928c.
- Base: c009928c (A-021 banked; 21 of 216). A-016 banked by subject in seat
  main (65b84131) before reset; team branch reset --hard onto c009928c.
  Worktree: /home/volmarr/aesir-team-02, branch yrsa/aesir-team-02.
- Machine: purpleraider, AMD Radeon 8060S Graphics, gfx1151 (asserted by
  both probes at run time; run refused on any other arch).

## Audit — every staged-copy path in the tree at c009928c

Production code (aesir_engine/, tests excluded):

1. **cuda_upload.mojo `upload_cuda_bytes` / `upload_cuda_bytes_at`** — THE
   one production staged copy. Bounded pinned staging (64 MiB cap,
   `MAX_UPLOAD_STAGING_BYTES`) into a MAX `DeviceBuffer`; callers
   llama3_cuda.mojo (2 sites) and gemma4_cuda.mojo (1 site), i.e. the CUDA
   session upload only. Hard-gated: `context.api() != "cuda"` raises. It
   cannot execute on the Z13 (no CUDA device/context exists there).
   `inference_memory.mojo`'s `host_staging_bytes` is this path's admission
   accounting (weights + one chunk + 4 B), CUDA plans only.
2. **HIP path (the Z13 path): NO staged copy.** HipMemory.memcpy_* /
   HipTransfer.memcpy_* / memcpy_async_* (hip_memory.mojo, hip_transfer.mojo,
   hip_memory_shim.c) have ZERO production callers — every call site is in
   tests/test_amd_realm.mojo (the A-011/A-012 capability proofs). Production
   Z13 data movement is copy-free by construction:
   - kv_unified.mojo → ZeroCopy.allocate (HIP managed, A-019/A-021);
   - weight_residency.mojo → mmap + hipHostRegisterMapped, device pointer ==
     host pointer (A-020);
   - zero_copy_shim.c never resolves hipMemcpy (counter structurally 0);
   - vulkan_buffer_shim.c resolves no copy entry point at all (no
     vkCmdCopyBuffer; aesir_vk_copy_call_count structurally 0, A-019);
   - XRT BOs are map/write/read in place (A-016).
3. **CPU-simulated gates**: CUDAGate.memcpy_* are host unsafe_memcpy
   simulations (no device exists behind them); AMDGate/IntelGate memcpy_*
   raise "physical transfer is not implemented". None is a device copy path.
4. **Names that are not copies**: cli/storage.mojo staged-file writes are
   crash-atomic publication (write-temp/fsync/rename) for the model store,
   not memory staging; prefill_overlap.mojo's "staging" is plan arithmetic
   only; dense_*/packed_* "staging" is register/shared-tile language inside
   kernels; Turing "loop staging" is a GPU→CPU loopback of a different
   hardware line, not a host-memory copy path.

Seat observation (not judged here): the banking seat's uncommitted A-022
work-in-progress adds Vulkan staging helpers (aesir_vk_stage_upload/download)
to vulkan_buffer_shim.c for non-host-visible buffers. They do not exist at
c009928c. When A-022 banks, this verdict's rule applies to them: a staging
copy is admissible only where no host-visible mapping exists for the target
buffer, never as the default path.

## Measurements — real device, gfx1151 (A-025 probe)

Probe: hidden_files/a025_probe.c (sha256 fbe6e66e…c90ca), HIPRTC sum kernel,
every GPU read verified against the expected sum (all VERIFY lines OK,
rel err 0.00e+00). Sizes 1/16/64 MiB, 7 reps after a full warmup pass,
medians. Two runs (hidden_files/a025_probe_run1.log, a025_probe_run2.log)
agree within noise; run 1 filed here. A light Tensile job shared the
machine (per seat check); copy/kernel medians were stable across runs.

| Path (median GB/s) | 1 MiB | 16 MiB | 64 MiB |
| --- | --- | --- | --- |
| STAGED end-to-end H2D (pageable → pinned memcpy → hipMemcpy → device) | 25.77 | 22.26 | 16.19 |
| STAGED end-to-end D2H (device → pinned → pageable) | 27.06 | 24.68 | 16.77 |
| STAGED copy-only (hipMemcpy pinned → device) | 39.35 | 62.35 | 81.98 |
| DIRECT copy (hipMemcpy pageable → device, no staging) | 40.25 | 77.39 | 80.82 |
| DIRECT managed GPU read in place (no copy call) | 42.61 | 59.77 | 118.10 |
| DIRECT pinned zero-copy GPU read in place (no copy call) | 45.98 | 59.66 | 72.62 |
| E2E load staged (host bytes → GPU read complete) | 12.93 | 20.35 | 13.70 |
| E2E load managed direct | 12.75 | 21.62 | 24.98 |
| E2E load pinned zero-copy | 12.65 | 21.29 | 22.66 |

Method note (honest): the A-025 probe refills the managed/pinned buffers
from the CPU before every timed in-place read, so its in-place rows pay
per-rep page migration. The banked A-008 probe (256 MiB, buffer left
GPU-warm across reps) was re-run in the same session as a cross-check
(hidden_files/a025_a008_crosscheck.log) and reproduced its banked numbers
on today's machine: managed GPU read 200.28 GB/s, pinned zero-copy GPU
read 176.66 GB/s, hipMemcpy H2D pageable 80.59 / pinned 82.45 GB/s,
D2H 67.54 GB/s. Both methods agree on the ordering; the staged path is
slowest under each.

Reading of the numbers:
- The staging memcpy is pure serialization: staged end-to-end (16.2 GB/s
  at 64 MiB) is ~5x slower than the copy it feeds (82.0 GB/s) and ~1.8x
  slower end-to-end than writing the managed buffer directly (25.0 GB/s).
- hipMemcpy pinned vs pageable differ by <2% at 64 MiB (81.98 vs 80.82):
  on this APU pinning buys the copy nothing — the A-008 verdict
  (hipMemcpy 20–83 GB/s, never best) is re-confirmed at three sizes.
- Direct in-place reads (118–200 GB/s managed; 73–177 GB/s pinned
  zero-copy) beat every copy route at every size ≥16 MiB; at 1 MiB all
  routes are launch/latency-bound and within noise of each other.

## Verdict

1. **Z13 / unified-memory path: the slower (staged) path does not exist in
   production code, so there is nothing to remove.** The audit above is the
   evidence: zero production callers of every HIP/Vulkan copy entry point;
   the shims for the zero-copy paths resolve no copy entry point at all.
   The HIP memcpy primitives are RETAINED as measured capability surface
   (device-buffer D2D, the A-011/A-012 test proofs, future discrete-buffer
   work) — they are a library, not a path the engine takes.
2. **The one remaining staged copy (CUDA pinned upload staging) is
   JUSTIFIED** in the repo's memory design documentation,
   docs/NATIVE_RUNTIME.md (new "Copy-path verdict (A-025)" section beside
   the existing host-staging accounting): a discrete CUDA device cannot
   read pageable host memory directly, the MAX host-buffer API enqueues
   copies out of pinned memory, the chunk is bounded at 64 MiB and
   synchronized before reuse, and the uploader refuses non-CUDA contexts,
   so it can never run on the Z13. Removing it would remove the
   discrete-GPU upload, not a staging inefficiency.
3. Rule going forward (filed in the same doc section): on unified memory,
   stage nothing; pinned memory is reserved for external APIs that
   require pinned buffers (A-008 rule 3, re-confirmed).

## Suite

Canonical E-MASTER shape (hidden_files/run_a025.sh, derived from the seat
gate A-021 script; log hidden_files/a025_run_all.log), run at pristine
c009928c BEFORE the doc edit and re-run after it:
- Before: 335 passed / 1 failed / 2 skipped / 338 total.
- After: see addendum below.
Sole failure both runs: gguf.tensor_directory_interface — the pre-existing
J-022 drift the brief names as tolerated (do not fix; roads A-165/A-121).
Skips: the 2 pre-declared. Zero regressions vs the seat baseline
(335/1/2 of 338, WAVE_PLAN.md seat gate A-021).

## Bugs found

None in repo code. One process finding: two sub-agent reports described
files (aesir_engine/docs/HIP_GATE_DESIGN.md, docs/MEMORY.md, Vulkan staging
helpers) that exist only in the banking seat's uncommitted A-022 tree, not
at banked c009928c; the lead re-verified every such claim against the
banked tree and this ledger records only banked-base facts.

## Addendum - post-edit suite (2026-11-12)

- After (docs/NATIVE_RUNTIME.md verdict section added; no code change):
  335 passed / 1 failed / 2 skipped / 338 total
  (hidden_files/a025_run_all.log; run 1 preserved as
  hidden_files/a025_run_all_before.log with the identical counts).
  Sole failure gguf.tensor_directory_interface (pre-existing J-022).
  Zero regressions vs baseline and vs the seat gate A-021.
