# A-097 — NPU sampler experiment

Slice A-097 (Wave 11, NPU first light). Can the XDNA 2 NPU in
purpleraider (ASUS ROG Flow Z13, AMD Ryzen AI Max+ 395, Strix
Halo) usefully assist token sampling — argmax / sampling over a
bf16 logits row? Measured on real device runs, 2026-11-13,
reusing the banked A-092 stand-up (IRON / mlir-aie 1.4.5,
Peano, system XRT 2.25, C++ host runner pattern from
aesir_engine/npu_matmul_probe.cpp via the A-094 timing runner).
Design: spikes/a097_npu_argmax/design_argmax.py (single AIE
compute tile, IRON kernels.argmax over tiles of 8192 bf16
logits, one 2-word record per tile, host merges in tile
order). Host runner: spikes/a097_npu_argmax/npu_argmax_probe.cpp.

## Marking law

- **OBSERVED** — measured or listed by tooling run on this
  Z13 during this slice; the log file is named.
- **DERIVED** — arithmetic on OBSERVED values; derivation
  shown, inherits the weaker mark.
- **DOCUMENTED** — stated in an AMD-authored source or in
  the stood-up IRON 1.4.5 library source on this machine;
  never presented as a measurement.

## HEADLINE

**Verdict: NOT FIT for single-token decode sampling as stood
up — a measured no.** A real NPU argmax over a full vocab row
runs correctly and exactly (planted three-way tie for the
maximum resolves to the lowest index, matching the CPU
oracle and numpy.argmax semantics), but it loses to a plain
single-thread CPU scan at both vocab sizes measured:
104.8 us vs 19.9 us at V=32768 (run 2: 80.1 vs 19.2) and
165.2 us vs 76.7 us at V=131072 (run 2: 160.2 vs 74.7)
(OBSERVED, a097_run_v32k.log, a097_run_v128k.log and the
_run2 logs). The A-094 dispatch floor (~93 us warm) is the
whole story again: at 32k the NPU time is essentially the
floor; at 128k the single tile's streaming scan adds only
~60-75 us over the floor, and even that marginal rate
(~0.61 us per 1k logits, DERIVED) does not beat the CPU
fp32 scan's marginal rate (~0.48 us per 1k, DERIVED). With
both sides linear and the CPU slope lower, no vocab size
crosses over for a single row on one tile. A-094's table
already classed decode-side reduction work as fusion-only;
this slice measures that class directly for the sampler
and confirms it in numbers.

## 1. Measured argmax (all OBSERVED)

Method: per vocab size, a dedicated xclbin compiled from
the A-097 design (tile 8192 bf16, one AIE compute tile).
Logits are deterministic (fixed-seed LCG, bf16 values in
[-2, 2)) with a planted three-way tie for the maximum
(3.5 at indices 100, T+37, V-123, in three different
tiles). Host runner: first run verifies the merged argmax
(index and value bits) exact vs the in-program CPU oracle,
output buffer sentinel-prefilled (0 sentinels remained);
then 21 warm reps (fresh run object, BOs and hw_context
resident) and 21 CPU reps, medians reported. Every run
printed device_name=NPU Strix Halo from the live XRT
handle and ert_cmd_state=4 (ERT_CMD_STATE_COMPLETED).

| Vocab V | Tiles | NPU run median | CPU bf16 argmax | CPU fp32 argmax | NPU vs best CPU |
|---|---|---|---|---|---|
| 32768 | 4 | 104.8 us (run2 80.1) | 19.9 us | 16.5 us | 0.16x LOSE |
| 131072 | 16 | 165.2 us (run2 160.2) | 76.7 us | 64.0 us | 0.39x LOSE |

Correctness: merged idx=100 (the planted tie's lowest
index) and value bits exact at both sizes, both runs;
every per-tile record printed in the logs.

CPU pricing of the stochastic path (same runner, same
data, OBSERVED): top-40 by nth_element over the widened
row + full-row softmax (T=1) costs 186.4 us at V=32768
and 887.2 us at V=131072 — the full stochastic sampler on
CPU is dominated by the full-row exp pass, not by the
argmax/top-k selection. That cost is a CPU fact, not an
NPU opening: no stochastic NPU kernel was run in this
slice (see section 3).

Derived (DERIVED):

- Single-tile marginal scan rate: (165.2 - 104.8) us per
  98304 extra logits = ~0.61 us / 1k logits. CPU fp32:
  (64.0 - 16.5) / 98.3k = ~0.48 us / 1k. The NPU loses on
  slope as well as on the floor intercept, so a larger
  vocab does not rescue the single-row case.
- Whole-array bound: the array has 32 compute tiles
  (DOCUMENTED, A-091 census). Even if a 32-tile argmax cut
  the scan component to ~2-5 us at V=131072, the ~93 us
  A-094 dispatch floor alone exceeds the entire CPU scan
  (64.0 us). Single-row decode argmax cannot win on this
  NPU through this dispatch path, at any tile count.
- Where the arithmetic could flip is batch: B rows per
  dispatch amortise the floor. B=64 rows at V=131072 cost
  the CPU ~4.1 ms of scanning (64 x 64.0 us, DERIVED);
  an NPU design that streams rows back-to-back inside one
  dispatch would pay the floor once. Unmeasured — named
  as the only live road for sampler assist, e.g. batched
  / speculative-verification sampling.

## 2. What was built

- Design: spikes/a097_npu_argmax/design_argmax.py —
  kernels.argmax (bf16, vector path) per 8192-logit tile;
  records carry (value widened to float, bit-cast; index
  within tile); host merges with argmax_combine semantics
  (ties -> lowest index). One compile lesson filed in the
  design: the runtime sequence must group fills/drains
  <= 4 tiles per TaskGroup or the shim tile's 16 buffer
  descriptors overflow at 16 tiles.
- Host runner: spikes/a097_npu_argmax/npu_argmax_probe.cpp
  (sha256 822b7e78...c1b6) — A-094 timing-runner shape:
  sentinel-prefilled output, exact verify, 21-rep warm
  medians, in-program CPU baselines.
- xclbin sha256: V=32768: 90ad9e91...9943 (insts 660 B,
  cef831f4...d77d); V=131072: c7381779...33 (insts 2928 B,
  a4453172...67c). Binaries stay in scratch/a097
  (uncommitted), hashes here, per repo hygiene.

## 3. Honest scope limits

- Stochastic sampling (temperature / top-k / top-p draw)
  was NOT run on the NPU. The stood-up IRON 1.4.5 library
  ships a bit-exact top-k sampler (kernels/sample.py:
  sample_select + sample_combine, DOCUMENTED) but no
  design wiring it was built in this slice; only its CPU
  shape was priced (section 1). The argmax verdict covers
  greedy sampling (temperature 0), which is exactly
  argmax, and the floor argument applies a fortiori to
  any per-token standalone dispatch.
- The CPU comparators are this runner's single-thread
  scans at -O2 (scalar bf16 widen-and-compare; plain fp32
  scan) — engine-class simple scans, not SIMD-tuned. A
  wider CPU scan would widen the NPU's loss, not narrow
  it; the floor comparison is comparator-independent.
- Warm numbers exclude xclbin load and hw_context
  creation (once per process), per the A-094 method.
- Logits are bf16 because that is the dtype the stood-up
  argmax kernel supports (bf16/int32, DOCUMENTED). An
  engine holding fp32 logits pays a conversion the CPU
  does not; that only deepens the loss and is not priced
  separately.

## 4. Recommendation

Keep sampling on the CPU for decode. Do not build a
standalone NPU sampler dispatch. The live roads, in
order: (1) fuse a sampler into a resident NPU lm_head
design if A-095-class prefill offload ever extends to the
output projection (the logits are then already on-device
and no extra dispatch is paid); (2) a batched sampler
design (many rows per dispatch) for batched or
speculative workloads, sized from section 1's rates.
Both are future slices; neither is claimed here.
