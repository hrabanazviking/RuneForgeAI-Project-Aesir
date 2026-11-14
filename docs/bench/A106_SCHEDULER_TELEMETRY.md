# A-106 - Scheduler telemetry

Per-device utilisation + placement decisions, exposed in
status/doctor, validated against external observation
within a stated tolerance. Wave 12 (Heterogeneous
scheduling), on banked A-100 (planner), A-103 (replan),
A-105 (fairness).

## What was built

- `aesir_engine/core/scheduler_telemetry.mojo` - the single
  telemetry source both doctor renderings consume:
  GPU utilisation from amdgpu sysfs `gpu_busy_percent`,
  GPU memory from the `mem_info` pools (GTT on this
  unified part, labelled as such), CPU memory from
  /proc/meminfo, CPU utilisation as an honest two-sample
  /proc/stat delta, NPU presence from the accel node with
  utilisation reported UNKNOWN (the kernel states no
  counter; none is invented), and the A-100 planner's 12
  standard-fixture placement decisions tallied by device
  class with every decision line preserved verbatim and
  an FNV-1a digest as the reproducibility anchor.
- `aesir_engine/cli/doctor.mojo` - doctor text gains a
  "Scheduler telemetry (A-106)" section; doctor JSON gains
  a `scheduler_telemetry` object (per-device rows,
  placement tally, tolerance constants).
- 8 in-suite cases `sched.telemetry_*`
  (tests/test_telemetry_a106.mojo) and the standalone
  bench tests/bench_telemetry_a106.mojo.

## Tolerance law (the acceptance comparison)

- GPU utilisation: +/-15.0 percentage points (both
  gpu_busy_percent and external tools interval-average
  over different windows).
- Memory: 256 MiB absolute or 5% relative, whichever is
  larger (allocator granularity on a 128 GiB pool).
- Unknown readings match nothing, not even each other.

## Measured validation (bench, hidden_files/a106_bench.log)

- Idle: internal GTT used 71,376,896 B class reading vs
  external `cat` 71,376,896 B - agreement inside tolerance;
  busy 0% both observers.
- Load: 300 real RADV vec_add dispatches (vendor 0x1002,
  device type 1, RADV by name; llvmpipe refused by
  identity) with a 512 MiB buffer resident - sampled GPU
  busy rose 0.0% -> 5.0%; during residency internal and
  external GTT reads agreed EXACTLY (71,630,848 B both);
  after free the pool returned inside tolerance and the
  shim returned to baseline live_bytes.
- Placements over the live registry: 12 total - GPU 6,
  NPU 2, CPU 4, none 0; digest 14661850525200458208,
  reproduced exactly by a second tally.
- NPU external observer: `xrt-smi examine` was run by the
  bench runner and FAILED on this machine with an mmap
  "Resource temporarily unavailable" error (filed in the
  bench log) - so no NPU utilisation figure exists from
  either side, and the telemetry says unknown rather
  than inventing one. rocminfo confirms the GPU identity
  (AMD Ryzen AI MAX+ 395 w/ Radeon 8060S).
- Honest note: RADV allocations move mem_info_gtt_used
  only slightly on this unified part (the residency delta
  was sub-MiB); the acceptance comparison is internal vs
  external agreement on the kernel's own counters, which
  held exactly - not a claim that GTT accounts every
  Vulkan heap.

## Suite

E-MASTER run 2 (solo): 655 passed / 1 failed / 2 skipped /
658 total = banked baseline 647/1/2/650 + 8 new cases, all
PASS. Sole failure is the pre-existing tolerated
J-022 gguf.tensor_directory_interface. Run 1 was
654/2/2/658 with one in-slice defect (an absolute-zero
live_bytes assert, wrong in-suite where the baseline is
not zero; fixed to the A-105 baseline-relative pattern
and re-proven in run 2). No named intermittent fired.
