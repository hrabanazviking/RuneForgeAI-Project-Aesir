# A-098 -- NPU power profile

Slice A-098 (Wave 11, NPU first light). Question: what is the
perf-per-watt of the offloaded op (the A-095 prefill projection
GEMM, 128x1024x1024) on NPU vs GPU vs CPU on this Z13?
Acceptance: power table from A-018 sensors, filed. This is it.

## Verdict: GPU wins perf-per-watt by ~10x; NPU ties CPU on
## gross package efficiency, wins 1.5x net of idle, at 22 W

The GPU is the perf-per-watt winner for this op by an order
of magnitude (51.2 vs 5.4 GFLOP/s/W gross package). The NPU
path's gross package J/op is the same as the optimized CPU's
(0.0499 vs 0.0502 J/op) because its 3.6x time disadvantage
eats its power advantage; net of idle it is 1.5x better
(0.0298 vs 0.0446 J/op) and draws only 22.1 W package vs
79.4 W -- real value for thermally/power capped or overlapped
work (A-096), not for raw efficiency at this shape. All NPU
numbers are the single-AIE-tile design (1 of 32 tiles,
A-094 census); the multi-tile lever is unchanged.

## Power sources (named, A-018)

- PRIMARY: RAPL package-0 energy_uj
  (/sys/class/powercap/intel-rapl:0), read in-process at the
  boundaries of each sustained dispatch window. On Strix
  Halo the package domain covers CPU + GPU + NPU (one APU),
  so this is whole-APU energy per op for every path -- the
  only like-for-like rail this machine exposes. Readable
  only as root: all runners ran via sudo -n (rapl_ok=1 in
  every POWER line). Max range 65,532,610,987 uJ, no wrap.
- SECONDARY (the A-018 sensor): amdgpu hwmon power1_average
  (PPT) + temp1_input, sampled at 5 Hz through every phase
  (hidden_files/a098/ppt_samples.log). It corroborates RAPL:
  idle 8.1-9.3 W, CPU 72-82 W, NPU 21-22 W medians. GPU PPT
  median reads low (53 W) because the GPU window is ~2 s and
  PPT is a smoothed average; the RAPL energy integral is
  the authority there.
- No per-engine rail (no NPU-only or GPU-only watt source)
exists on this machine; none is invented. XRT exposes no
power telemetry here. Package energy is the honest table.

## Method

- Op: prefill projection GEMM 128x1024x1024, 0.2684 GFLOP
  (2*M*K*N), the A-094 FIT / A-095 offloaded shape.
- NPU path: spikes/a098_power/power_runner.cpp (the banked
  A-095 runner + in-process RAPL window around its E2E
  loop), A-094 p128 xclbin uuid
  184c0a55-97ee-d107-bad0-060c59a9a278, resident context,
  4,096 dispatches per run x 3 runs.
- CPU path: same runner, flag off (A-095 optimized 32-thread
  i16->i32 GEMM), 16,000 dispatches per run x 3 runs.
- GPU path: spikes/a098_power/gpu_power.cpp + gemm.comp,
  Vulkan compute GEMM on the Radeon 8060S; fp32 buffers fed
  from the SAME A-092 LCG i16 stream (values in [-8,8];
  every partial sum is an integer < 2^24, so fp32 is EXACT
  vs the int64 oracle -- verified, not assumed). 30,000
  dispatches in one submission per run x 3 runs (~2 s;
  window is short because the GPU is ~33x faster per op;
  energy is integrated, not sampled, so the window length
  does not bias J/op).
- Idle: two 10 s package-energy reads bracketing the run
  set: 8.462 W and 9.290 W (mean 8.876 W). Net figures
  subtract idle power x window from gross energy.
- Correctness (raw-oracle discipline): every path verified
  EXACT vs the naive int64 CPU oracle on the full 131,072
  elements before/within its window. NPU: 0 mismatches,
  checksum 2848816214485251074 (== A-095 banked), device
  evidence device_name=NPU Strix Halo from the live XRT
  handle, ert_cmd_state=4 (COMPLETED) on verify + all runs
  (4,118 submitted per run). GPU: 0 mismatches,
  max_abs_err 0.000000, gpu_device_name=AMD Radeon 8060S
  Graphics (RADV STRIX_HALO) from VkPhysicalDeviceProperties,
  final window output re-verified exact. CPU: exact vs
  oracle (runner memcmp) every run.
- Solo machine: ps checked before launch; the A-097 seat
  gate had finished; no other suite/NPU probe live.

## Power table (pooled, 3 runs per path; RAPL package-0)

| Path | us/op | GFLOP/s | Pkg W (gross) | J/op gross | J/op net | GF/s/W gross | GF/s/W net |
|---|---|---|---|---|---|---|---|
| GPU (Vulkan, 8060S) | 67.5 | 3,976 | 77.7 | 0.00524 | 0.00464 | 51.20 | 57.81 |
| CPU (opt, 32 thr) | 632.5 | 424 | 79.4 | 0.05023 | 0.04462 | 5.34 | 6.02 |
| NPU (XDNA 2, 1 tile) | 2,258.2 | 118.9 | 22.1 | 0.04985 | 0.02980 | 5.39 | 9.01 |
| Idle package | - | - | 8.88 | - | - | - | - |

Per-run spread is tight: J/op gross CPU 0.0496-0.0511,
GPU 0.00522-0.00526, NPU 0.0482-0.0514. Per-run POWER /
E2E lines: hidden_files/a098/{cpu,gpu,npu}_r{1,2,3}.log;
driver + phase marks: hidden_files/a098/driver.log,
phases.log. A-018 PPT medians per phase: idle 8.1 / 9.3 W,
CPU 82.1 / 72.3 / 72.4 W, GPU 52.9 / 53.9 / 52.8 W
(smoothed, short window -- see note above), NPU 21.2 /
22.4 / 21.8 W; GPU edge temp median 62-64 C during GPU
phases, NPU phases 38-42 C (amdgpu temp1_input).

## Reading the table honestly

- Same shape, same inputs, same oracle on all three paths;
  GPU arithmetic is fp32-exact for this input range, CPU
  and NPU are i16->i32 integer -- the comparison is of the
  offloaded op as each engine actually runs it (A-095
  runner semantics), filed as such.
- Gross = whole package while the path runs (what the
  battery/PSU sees); net = gross minus measured idle.
  Rankings agree on both bases except NPU-vs-CPU, where
  gross is a tie and net favors the NPU 1.5x.
- The NPU number is a single-tile floor, not the array's
  ceiling: A-094's census and A-095's verdict name the
  whole-array design as the lever that moves both the
  latency and this table's NPU row.
- A-096's overlap result is the NPU's best current use:
  at 22 W package it computes a prefill chunk inside the
  GPU decode shadow; A-098 adds that this costs about the
  same joules per op as doing it on the CPU, at 1/4 the
  package power and 3.6x the latency.
