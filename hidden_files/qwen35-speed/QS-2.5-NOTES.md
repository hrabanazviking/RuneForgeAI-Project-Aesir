# QS-2.5 NOTES — HIP per-phase attribution + attack (team QS-2.5)

Seat: QS-2.5 team lead runs the six Mythic Engineering roles
sequentially in one seat (no sub-agents; depth limit — recorded
per commission). Sole writer in ~/aesir-qs-phase on branch
yrsa/qs-phase @ d1e5815f (QS-2 merged). Main (31ab9363),
~/aesir-q35-7, the aesir-gate service, Ollama, Voxta untouched.

## QS-2.5.1 — PER-PHASE PROFILE AT REAL GEOMETRY (DONE)

Method (rocprof absent, per QS-0/QS-2): engine timers added to
Qwen35HipExecutor behind env AESIR_QS_PROFILE (unset = zero
behavior change; production builds untouched):
- mode 1: host enqueue attribution — monotonic_ns around every
  enqueue_function group (GEMV helpers vs small-kernel helpers
  vs direct-enqueue sections), timed synchronize() calls, and
  the forward_chunk wall, printed per decode token.
- mode 2: mode 1 + a synchronize bracket around every layer
  (per-layer-type GPU walls: SSM vs ATTN).
- mode 3: mode 2 + synchronize brackets at segment boundaries
  inside each layer (SSM: proj GEMMs | conv/l2/delta chain;
  ATTN: proj+small chain; both: FFN segment).
Fixture gate first: test_qwen35_hip_q35_6 ALL PASS with the
profiler off, mode 1, mode 2 and mode 3; session test ALL PASS
(POS1=72/POS2=106). Real-file runs under HEAVY.lock claimed
2026-11-15 02:51:29 EST (OWNER.txt, this team). CO-RESIDENCY
(recorded, per protocol): QS-5 rehearsal serve (qs5-rehearsal,
:18438, CPU path) was decoding the same 27B concurrently
(load1 7.6-9.5 at run starts; MemAvailable 123 GB pre-HIP).
Control for that: the isolated v8 GEMV bench re-run in the
same window still streams 199.3 GB/s (FFN shape) / 209.6 GB/s
(output shape) — QS-2 clean-window class — so co-residency
does NOT explain the in-engine shortfall below.

### Launch census per decode token (mode 1, exact counters)
GEMV launches 497 (48 SSM x 8 + 16 ATTN x 7 + lmhead 1).
Small-kernel helper calls 449 + section launches (SSM conv
chain 3/layer, ATTN small chain 9/layer). Total ~1,440
launches/token. Host enqueue cost for ALL of them:
3.4-4.5 ms/token (~3 us/launch). Host non-enqueue ~0.4-3 ms.
THE HOST/LAUNCH PATH IS EXONERATED: ~1.5% of the token.

### Per-phase budget (mode 3 means, 21 tokens, wall 271.4 ms;
### mode 1 cross-check 37 tokens, wall 271.7 ms — matches the
### QS-2 clean-window 260.8-281.5 ms band)
| phase | ms/token | share | stream floor @205GB/s | excess |
|---|---|---|---|---|
| FFN segments (64x) | 196.4 | 72% | 88.7 (284MB/layer) | ~107.7 |
| SSM proj GEMMs (48x) | 27.3 | 10% | ~19 | ~8 |
| SSM conv/l2/delta chain + out (48x) | 22.3 | 8% | ~7 | ~15 |
| ATTN proj + small chain + out (16x) | 18.1 | 7% | ~8 | ~10 |
| final norm + lmhead + copyback | ~7 | 3% | 6.6 | ~0 (AT RATE) |
| host enqueue + other | 3.4-7 | ~2% | — | — |
Layer walls (mode 2): SSM 194.9 ms total (4.06/layer), ATTN
61.4 ms (3.84/layer); per-FFN 3.07 ms vs 1.43 ms of pure
streaming at bench rate (3 x 0.475 ms).

### Indictment
The ~0.13 s/token of non-GEMV-stream time QS-2 named is NOT
launch gaps, NOT host sync, NOT contention. ~0.108 s of it is
INSIDE the FFN down projection: _q8_gemv_silu_kernel_v8 calls
_silu_pair() in its inner loop, recomputing silu(gate[k])*up[k]
— one exp() via _sigmoid — for every (output row, k) pair.
The SwiGLU activation has 17,408 distinct values per layer;
the fused kernel evaluates it 5,120x redundantly: 89M exp per
layer, ~5.7 BILLION exp per token, saturating the math pipes
while DRAM idles (FFN effective ~92 GB/s vs 199-210 isolated).
The lmhead — a single plain GEMV — runs AT bench rate in the
same stream, proving the stream itself is healthy. Remainder
(~0.03 s): small-kernel chains (SSM delta/l2norm segments,
ATTN 9-kernel chain) + tiny alpha/beta GEMVs.

## QS-2.5.2 — ATTACK (next entry)
