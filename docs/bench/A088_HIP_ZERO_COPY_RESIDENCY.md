# A-088 - HIP zero-copy measurement: managed memory vs the
# Vulkan weight-residency path (A-064)

Slice A-088 (Wave 10). Acceptance (roadmap): numbers filed;
residency design updated if HIP's model is better.
Host: purpleraider, AMD Radeon 8060S (gfx1151). Bench:
aesir_engine/tests/bench_zero_copy_residency_a088.mojo
(standalone proof, not an E-MASTER case - timing assertions
do not belong in the suite; A-085 doc+bench precedent, +0
suite cases, run_all pin untouched at 594).

## VERDICT

**The A-064 residency design STAYS for static weights. HIP's
managed-memory model is NOT better for the weight-residency
workload - and A-085 is untouched by this slice (Vulkan
PRIMARY GPU road, HIP PARKED probe-only; nothing here is a
bake-off input).** One sub-case clarification IS adopted
(see Design update): the A-064 residency type must never
back a buffer the CPU reads.

Why: the residency workload is write-once (CPU fills weights
at load), GPU-read-many (every decode dispatch), CPU-read-
never (weights are not read back in decode). On exactly
those axes the two models are at parity (below): GPU
streaming bandwidth within ~10% (different kernels, so
path-specific, not a head-to-head), CPU write bandwidth
indistinguishable, and Vulkan residency allocation is
~400x cheaper than hipMallocManaged at 64 MiB. HIP managed
wins only on axes the residency workload never exercises:
CPU read-back and alloc-free reuse across CPU/GPU phases.

## Method

One size, weight-scale: N = 16,777,216 Float32 = 64 MiB per
buffer, three buffers per Vulkan path (a, b, c), two per HIP
path (src, dst). Identical CPU code on every path (median
of 3 writes, median of 3 eight-accumulator checksum reads -
the A-008 ruler fix). GPU: 2 warmup + 7 timed reps, median.
Two full bench runs filed (hidden_files/a088_bench.log =
run 3, load 2.92/1.54/1.10 at start; a088_bench_run2.log,
load 0.74/1.07/0.93); every headline number agrees in kind
across both runs (ranges below span the two runs).

Device-execution evidence (law 6), both runs: HIP device
count=1, mem total 133,143,986,176 B, kernel launch delta
exactly 9 per run with memcpy_calls=0 (the zero-copy shim
resolves no copy entry point - structural zero). Vulkan
vendor 0x1002, RADV asserted (llvmpipe refused),
type_flags printed per path (residency 7, cached 14),
copy_call_count=0, residency accounting byte-identical
across all repeats, Q8_0 GEMV dispatch delta exactly 9.
Oracles: every GPU output verified elementwise (bad=0 on
all paths); resident GEMV vs the sequential CPU oracle
worst max_abs 2.48e-05, inside the A-064 filed 1e-3 bound,
bit-identical across both runs.

## Numbers (64 MiB buffers, medians; ranges = run2..run3)

| axis | HIP managed | VK residency (flags 7) | VK cached (flags 14) |
|---|---|---|---|
| alloc 64 MiB | 1.79-1.87 ms | 0.004-0.005 ms | 0.69-0.75 ms |
| CPU write | 13.4-19.3 GB/s | 14.4-20.3 GB/s | 18.6-19.0 GB/s |
| GPU streaming* | 211-221 GB/s | 193-200 GB/s | 194-199 GB/s |
| CPU read | 37.4-41.9 GB/s | 0.21-0.23 GB/s | 33.1-40.8 GB/s |
| copy calls | 0 (memcpy) | 0 | 0 |

* GPU kernels differ (HIP transform: read+write, traffic
2N; Vulkan vec_add: 2 reads + write, traffic 3N) - the
GB/s are traffic-normalised per path and reported
path-specific, never as a kernel head-to-head (comparator-
artifact law). Both sit in the A-008 warm GPU band.

Resident Q8_0 GEMV (A-064 section, timed): 64x1024 shape,
69,632 weight bytes resident once, median dispatch
140-143 us across 7 reps, dispatch delta exactly 9
(2 warmup + 7), accounting unchanged, oracle worst
2.48e-05. Repeated dispatches against the residency do
not re-upload - the A-064 proof, re-measured.

## Reading the numbers

- GPU side: parity. Residency's GPU streaming (193-200)
  matches cached (194-199) and sits ~8-10% under HIP's
  transform number on a lighter kernel - inside the
  noise/kernel-difference band, not a residency defect.
- CPU write: parity. The write-once cost A-064 pays at
  load is the same cost HIP managed pays; nothing to win.
- Alloc: residency is nearly free (4-5 us - the RADV pool
  returns a ready allocation); hipMallocManaged pays
  1.8 ms of mapping/first-touch setup per 64 MiB. At model
  scale (hundreds of tensors) this favours residency, and
  it is paid once per buffer either way.
- CPU read: the one blowout. The A-064 residency type
  (flags 7, DEVICE_LOCAL|HOST_VISIBLE|HOST_COHERENT)
  reads back on the CPU at 0.21-0.23 GB/s - 160-180x
  slower than managed (37-42) or cached (33-41). This
  quantifies on the flags-7 type the same trap A-008
  measured at 0.11 GB/s on the flags-0xc7 type: device-
  local coherent memory is device-uncached for CPU reads.
  In the residency workload this never fires - decode
  never CPU-reads weights - which is why A-064 stands.

## Design update (sub-case only, adopted)

A-064 residency is unchanged for static, GPU-only weight
traffic. The residency DESIGN gains one explicit rule,
measured here for the first time on the flags-7 type:
**no buffer the CPU must read may be allocated with the
A-064 residency type.** CPU-read or frequently CPU-updated
buffers (activations read back, dynamic scales, adapters
under CPU update, any shared CPU<->GPU working buffer)
belong on HIP managed memory or the Vulkan HOST_CACHED
type (A-019) - both measured 33-42 GB/s CPU read here.
This is a clarification of the existing split (A-019
already defaults shared buffers to managed/cached), now
backed by flags-7 numbers; it changes no allocation in
the engine today, because no CPU-read buffer uses the
residency type.

## Ruler defects found and fixed in this bench (mine)

1. First bench run measured CPU write at 6.17 GB/s on ALL
   paths: the fill pattern used a 64-bit modulo per element
   ((i*37+11) % 997), so the timed loop measured ALU, not
   memory. Pattern changed to cheap bitmask forms; writes
   re-measured at 13-20 GB/s. (The A-008 lesson, again:
   suspect the ruler before the hardware.)
2. First GEMV section used _fa-scale inputs (|x| up to
   ~400, ~250x A-064's input scale) against A-064's
   absolute 1e-3 bound and reported worst 8.3e-03 - a
   scale artifact, not a parity failure. Inputs reset to
   the A-057/A-064 scale (|x| <= ~1.05); worst is now
   2.48e-05, deterministic across runs.

## Bugs

None discovered in engine code. Both defects above were
in this slice's bench ruler, fixed before filing.
