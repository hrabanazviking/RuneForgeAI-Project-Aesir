# BENCHMARK_METHOD.md — MÍMISBRUNNR C2 performance methodology (H038)

The honest numbers in `data/armvegr/kernel_perf.json` were produced by this
method. Any future perf claim for an ARMVEGR kernel must cite this method
or document its deviation.

## 1. What is measured

`armvegr/perf_bench.mojo`, built with the pixi-shim Mojo and run **on Mimir**
(Raspberry Pi 5, aarch64 — real ARM64 NEON, never x86_64, never simulated).
Each kernel is timed at one representative shape (recorded per kernel in the
JSON). Two derived units are used:

- **GFLOPS** = FLOP count / median_ns. (FLOP/ns is GFLOPS: 1e9 FLOP per
  1e9 ns cancel exactly.)
- **GB/s** = bytes moved / median_ns, same cancellation.

FLOP/byte counts are the algorithmic ones (e.g. GEMM = 2·M·N·K; GEMV =
(M·N+N+M)·2 bytes; softmax = 3·n·2 bytes for max-pass + exp/sum-pass +
write). They are stated per kernel in `perf_bench.mojo` comments.

## 2. Repetition and outliers

- **3 warmup runs** per kernel (page faults, allocator and branch-predictor
  warmup, first-touch NUMA placement — on a Pi this is mostly dTLB/page
  warmup), discarded.
- **11 timed runs** per kernel. Reported: **median**, min, max of the 11.
- Median is the headline number: it is robust to the occasional slow run
  (IRQ, thermal step, kswapd) without hiding the spread — min/max are
  published alongside so a cherry-picked best case is impossible to pass
  off as typical. The 11 samples are sorted in-MoJo (insertion sort) and
  element 5 is taken.

## 3. Dead-code elimination (DCE) — the sink

Mojo's optimizer **will delete side-effect-free kernels** out of a timing
loop. Observed during development: an 8192² GEMV timed at 74 ns — faster
than light, i.e. the whole call was eliminated. Every timed region therefore
accumulates a checksum of the kernel's outputs (`c[0] + c[last]`) into a
module-level `sink` that is printed at the end. The sink creates a real data
dependency the compiler cannot see through, so the timed work is genuinely
executed. The final `{"sink": ...}` line in the output is the proof the
sinks were live.

## 4. Clock pinning

- The benchmark is **pinned to one core** (`taskset -c 3`). All C2 kernels
  are single-threaded, so this removes scheduler migration noise without
  changing what is measured.
- The cpufreq governor is set to **`performance`** for the run (verified
  via sysfs) and restored to `ondemand` afterwards. This pins the clock
  instead of letting ondemand ramp mid-benchmark.
- Ambient temperature (thermal_zone0) is recorded at run start and end;
  both go into the JSON. A run where the end temperature exceeds ~70°C
  would be discarded for thermal throttling (did not occur: 35.9 → 37.0°C).

## 5. Inputs

Deterministic: splitmix64-seeded `fill_rand_f16` from `armvegr/util.mojo`
(fixed seeds per kernel, recorded in `perf_bench.mojo`). Inputs are
representative magnitudes (GEMM/GEMV in [-1,1], norms in [-3,3], activations
in [-10,10], quant in [-6,6]) — no denormals, no NaNs, no adversarial
sparsity. Same inputs every run, so re-runs are comparable.

## 6. What the numbers mean (and do not)

- These are **single-threaded, -O2, NEON** numbers on a passively-cooled
  Pi 5. They are the baseline all later optimization claims are judged
  against — not a ceiling, not a marketing figure.
- `stream_triad` (8-wide SIMD, 8M fp32) is the memory-bandwidth reference.
  Ratios derived from it (GEMV = 73% of STREAM; q80 GEMM = 53% of GEMV)
  are computed from medians and recorded in the JSON.
- The GEMM number (7.16 GFLOPS at 1024³) is below the H023 ≥32 GFLOPS
  target. That shortfall is analyzed honestly in DEVLOG.md (the H007-era
  16 GFLOPS used fp16 accumulation; the shipped kernel widens to fp32,
  trading speed for accuracy) — the baseline stands as measured.

## 7. Reproducing

```
# on Mimir, from the repo root:
/usr/local/bin/mojo build -I. -o /tmp/perf_bench armvegr/perf_bench.mojo
echo performance | sudo tee /sys/devices/system/cpu/cpufreq/policy0/scaling_governor
taskset -c 3 /tmp/perf_bench
echo ondemand | sudo tee /sys/devices/system/cpu/cpufreq/policy0/scaling_governor
```

Expect run-to-run median variation of a few percent (thermal/voltage
noise); a >10% deviation from the JSON medians warrants investigation,
not a new baseline.
