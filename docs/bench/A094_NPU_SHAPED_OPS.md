# A-094 — NPU-shaped ops analysis

Slice A-094 (Wave 11, NPU first light). Which engine ops fit
the XDNA 2 NPU in purpleraider (ASUS ROG Flow Z13, AMD Ryzen
AI Max+ 395, Strix Halo), with size thresholds measured from
the banked A-092 stand-up. All measurements are real device
runs on this machine, 2026-11-13, reusing the A-092 recipe
(IRON / mlir-aie 1.4.5 single-core design compiled with
Peano for npu2, system XRT 2.25, C++ host runner derived
on-device from aesir_engine/npu_matmul_probe.cpp; the
timing variant is filed at spikes/a094_npu_timing/).

## Marking law

- **OBSERVED** — measured or listed by tooling run on this
  Z13 during this slice; the log file is named.
- **DERIVED** — arithmetic on OBSERVED values; derivation
  shown, inherits the weaker mark.
- **DOCUMENTED** — stated in an AMD-authored source or in
  the stood-up IRON 1.4.5 library source on this machine;
  never presented as a measurement.

## HEADLINE

The NPU dispatch floor is the whole story at small sizes
and irrelevant at large ones. One warm NPU matmul dispatch
costs a median of 93.0 us at 32x32x32 — the floor is
launch + DMA, not math (OBSERVED, a094_run_32.log). Cubic
i16 GEMM crosses the in-program CPU oracle between 32^3
(NPU loses, 0.29x) and 64^3 (NPU wins, 1.88x), and the
win grows to 37.7x at 512^3 (OBSERVED). Projection-shaped
GEMMs (the prefill shape class) win by two orders of
magnitude against the oracle CPU. Decode-shaped work
loses structurally: true M=1 GEMV is not expressible in
the stood-up design (tile m=32), and per-op dispatch at
the measured floor would cost ~19 ms/token in dispatch
alone across a 32-layer model (DERIVED). Layernorm-class
ops are fusion-only: kernels exist in the library, but a
standalone dispatch can never repay the floor at decode
sizes. **A-095 recommendation: prefill projection GEMM.**

## 1. Measured matmul sweep (all OBSERVED)

Method: per shape, a dedicated xclbin compiled from the
A-092 single-core design (tile 32x32x32, i16 in, i32 out,
one AIE compute tile). Host runner: first run verifies
every output element exact vs the in-program CPU oracle
(int64 accumulate), output buffer sentinel-prefilled;
then 21 warm reps (fresh run object, BOs and hw_context
resident) and 5 CPU-oracle reps, medians reported. Every
run printed device_name=NPU Strix Halo from the live XRT
handle and ert_cmd_state=4 (ERT_CMD_STATE_COMPLETED);
every shape verified with 0 mismatches and 0 sentinels
remaining. Logs: hidden_files/a094/a094_run_*.log.

| Shape MxKxN | MACs | NPU run median | NPU run+sync median | CPU oracle median | NPU vs CPU |
|---|---|---|---|---|---|
| 32x32x32 | 32,768 | 93.0 us | 93.3 us | 27.2 us | 0.29x LOSE |
| 64x64x64 | 262,144 | 102.6 us | 102.9 us | 192.8 us | 1.88x |
| 128x128x128 | 2,097,152 | 105.9 us | 106.6 us | 811.4 us | 7.66x |
| 256x256x256 | 16,777,216 | 349.0 us | 351.4 us | 12,065.4 us | 34.6x |
| 512x512x512 | 134,217,728 | 2,094.0 us | 2,106.0 us | 78,933.5 us | 37.7x |
| 32x1024x1024 | 33,554,432 | 654.5 us | 655.7 us | 67,617.5 us | 103x |
| 128x1024x1024 | 134,217,728 | 2,558.3 us | 2,566.3 us | 254,169.3 us | 99x |

The 64x64x64 checksum (16383547698108786409) reproduces
the banked A-092 checksum exactly — same design, same
inputs, same device result (OBSERVED).

Derived from the sweep (DERIVED):

- Dispatch floor: ~93 us per warm dispatch (32^3 median;
  min 88.5 us). At 128^3 the NPU is still floor-dominated
  (105.9 us for 8x the 64^3 work).
- Single-tile throughput at 512^3: 2*512^3 / 2094 us =
  ~128 GFLOP/s on ONE compute tile. The array has 32
  compute tiles (DOCUMENTED, A-091 census); whole-array
  designs are future headroom, not measured here.
- Cubic crossover vs the oracle CPU: bracketed between
  32^3 and 64^3; interpolating the CPU curve against the
  floor puts it near 48^3 (~0.1M MACs).

## 2. Candidate table (acceptance deliverable)

Engine shapes assume the Llama-family 7-8B class the
engine targets (hidden 4096, 32 layers; A-094 analysis
assumption, stated not measured).

| Candidate op | Regime | Verdict | Crossover / threshold |
|---|---|---|---|
| Prefill projection GEMM (QKV, out-proj, MLP gate/up/down; M = prompt tokens) | Prefill | **FIT — best candidate** | Wins from M=64 cubic-equivalent up; at the projection proxy 128x1024x1024 measured 99x vs oracle CPU. Threshold: >= ~0.1M MACs per dispatch and M >= 64. |
| Embedding projection (token embedding output projection / lm_head class GEMM) | Prefill + last-token | **FIT, same class as above** | Same measured GEMM economics; lm_head at 4096x128256 is a large-K GEMM — the 1024-K proxies bound its per-MAC cost, the full shape was not run. |
| Embedding lookup (gather) | Both | **NOT FIT** | No arithmetic; a DMA/gather, not a matmul. No crossover exists. Keep on CPU/host. |
| Small GEMMs below crossover (attention score tiles, per-head blocks) | Both | **LOSE standalone** | 32x32x32 measured 0.29x vs CPU. Any op under ~0.1M MACs per dispatch pays the 93 us floor and loses. Fuse or batch, never dispatch alone. |
| Decode GEMV (M=1 projections) | Decode | **NOT FIT as stood up** | True M=1 is not expressible: the design requires M % 32 == 0 (OBSERVED from the design asserts), so M=1 pads to 32 rows. The padded proxy 32x1024x1024 measured 103x vs the naive oracle, but that CPU comparator is not the engine CPU path (see caveats) — no honest engine crossover can be filed from it. Structural blocker (DERIVED): ~6 projection dispatches x 32 layers x 93 us floor = ~19 ms/token of dispatch alone. |
| Layernorm / RMSNorm-class ops | Both | **FUSION-ONLY, unmeasured** | rms_norm / layer_norm kernels exist in the stood-up IRON 1.4.5 library (OBSERVED: aie/iron/kernels/norm.py) but no design was compiled or run for them in this slice — no measured crossover is claimed. Standalone is ruled out by arithmetic (DERIVED): a decode norm row is 4096 elements, microseconds of CPU work against a 93 us dispatch floor. Value only fused inside a resident GEMM design. |
| Softmax / RoPE / SiLU / residual (elementwise + reduction class) | Both | **FUSION-ONLY, unmeasured** | Same floor arithmetic as norms; never standalone offload units. |

## 3. Caveats (filed honestly, for A-095)

- The CPU comparator is the in-program oracle: single-
  thread, naive triple-loop i16->i32 at -O2 — the same
  oracle class A-092 verified against. It is NOT the
  engine's optimized CPU GEMM/GEMV path. Crossovers
  against the engine CPU will sit at larger sizes; the
  99-103x projection margins are upper bounds, while the
  floor (~93 us), the 32^3 loss, and the single-tile
  throughput are comparator-independent NPU facts.
- Warm numbers exclude xclbin load and hw_context
  creation (once per process). An offload design must
  keep context and BOs resident across calls, or the
  cold cost — unmeasured here — eats the win.
- All NPU numbers are ONE compute tile of 32. A
  whole-array or cascade design changes absolute times
  (downward) but not the floor argument for tiny ops.
- i16 inputs only: the stood-up design's dtype set is
  i16/i8/bf16 in, i32 out. Engine weights are Q4/Q8 —
  a quantize/dequant boundary cost exists and is not
  measured here; A-095 must price it in.

## 4. Recommendation to A-095

Implement ONE candidate: **prefill projection GEMM**
(M >= 64 tokens, K/N in the 1024-4096 class) behind the
registry, reusing this slice's per-shape xclbin recipe
and the resident-context host pattern. Do not pick
decode GEMV or any standalone norm/elementwise op —
this table's measured floor is the reason, in numbers.
