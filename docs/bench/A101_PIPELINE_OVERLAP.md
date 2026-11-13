# A-101 -- Pipeline overlap

Slice A-101 (Wave 12, Heterogeneous scheduling). Roadmap:
Prefill (GPU) in parallel with sampling prep (CPU) in parallel
with NPU assist where enabled. Acceptance: timeline trace
showing real overlap; end-to-end latency delta filed.

## Verdict: POSITIVE, measured (3 runs, 21 reps each)

All three legs run concurrently and the overlapped wall tracks
the longest leg (CPU sampling prep, about 10.0 ms) instead of
the serial sum (about 19.0 ms). Median end-to-end delta over
serial: 8,882 / 9,129 / 8,881 us across the three runs
(46.8 / 47.7 / 47.0 percent of the serial wall).

## Pipeline (one step)

- Prefill (GPU): Vulkan compute GEMV 1024x1024 fp32 x 64 reps
  in one dispatch on AMD Radeon 8060S Graphics (RADV
  STRIX_HALO, gfx1151) -- the prefill-shaped GPU leg, submitted
  on the main thread; a waiter thread timestamps fence
  completion, so the trace end is device completion, not the
  main thread waking up.
- Sampling prep (CPU): deterministic preparation over
  previous-token logits (vocab 32,768; max, fixed-point softmax
  denominator, top-1/top-2 selection) x 260 rounds on the main
  thread while both devices work.
- NPU assist: prefill projection GEMM 128x1024x1024 i16 to i32,
  the A-094 FIT shape, banked A-092/A-094 xclbin (uuid
  184c0a55-97ee-d107-bad0-060c59a9a278), XRT 2.25, sudo. Async
  XRT run started first; a waiter thread timestamps run
  completion plus BO sync. The leg is planned only where the
  banked A-095 registry dispatch selects AMD_XDNA, and drops
  out per the A-099 fallback contract otherwise (the in-engine
  plan model is core/pipeline_overlap.mojo).
- Modes per rep: serial (NPU, then GPU, then CPU, each waited)
  vs overlap (NPU start; GPU submit; CPU prep on main; waiter
  threads collect both devices).

## Results (medians of 21 reps, us)

| Run | Serial wall | Overlap wall | Delta | Delta pct |
|---|---|---|---|---|
| 1 | 18,961.3 | 10,079.0 | 8,882.3 | 46.84 |
| 2 | 19,144.7 | 10,015.3 | 9,129.4 | 47.69 |
| 3 | 18,900.2 | 10,019.5 | 8,880.7 | 46.99 |

Overlap-mode leg medians (us): NPU 2,335 / 2,372 / 2,316;
GPU 5,123 / 4,813 / 5,167; CPU 10,052 / 9,985 / 9,988.
The overlapped wall sits within 1 percent of the CPU leg
alone: both device legs are fully hidden under sampling prep.

## Timeline trace (run 1, rep 0, us from step start)

- serial: npu 0.0 to 2,499.5; gpu 2,499.6 to 7,441.7;
  cpu 7,441.8 to 18,150.5; wall 18,151.0. No shared interval.
- overlap: npu 0.0 to 2,567.2; gpu 40.0 to 5,643.0;
  cpu 222.2 to 10,331.9; wall 10,341.3.
- Median pairwise overlaps (21 reps), run 1 / 2 / 3:
  NPU-GPU 2,332 / 2,368 / 2,312 us; GPU-CPU 5,101 / 4,788 /
  5,140 us; NPU-CPU 2,307 / 2,340 / 2,284 us. Every pair
  shares a real interval in every run. Full traces in
  hidden_files/a101/run{1,2,3}.log.

## Correctness (device-execution evidence, every run)

- NPU: device_name=NPU Strix Halo from the live XRT handle,
  ert_cmd_state=4 (COMPLETED), 131,072 elements exact vs the
  in-program CPU oracle, 0 mismatches, 0 sentinels, checksum
  2848816214485251074 -- identical to the A-095/A-096 runs of
  the same shape and design.
- GPU: device named from VkPhysicalDevice properties; GEMV
  max abs err 0.000035 vs the CPU oracle (fp32 tolerance).
- CPU: sampling prep checksum 3359139257229004943, identical
  on a repeat run in-process and across all three runs
  (deterministic; the prep has no device leg to fake).
- Raw-oracle note: correctness here is tensor-level exact
  (integer GEMM), fp-tolerance (GEMV) and exact determinism
  (CPU prep); no model-level logit claims are made.

## Relation to banked work, and the A-100 dependency

A-096 proved the two-leg version of this premise (NPU prefill
overlapped with GPU decode, 3,819 to 4,289 us saved). A-101
adds the third leg the roadmap names -- CPU sampling prep --
and files the end-to-end delta for the full three-leg step.
A-100 (placement planner, team-27) was building in parallel
and had NOT landed when A-101 ran, so the plan model consumes
only banked surfaces: the A-017 policy through the A-095
registry dispatch in core/npu_offload.mojo, and the A-086
winner registry (Vulkan primary). No planner code is
duplicated; when A-100 banks, it can feed the same
PipelinePlan struct. Harness: spikes/a101_pipeline/
pipeline_probe.cpp (+ gemv.comp); ledger:
hidden_files/A101_LEDGER.md.
