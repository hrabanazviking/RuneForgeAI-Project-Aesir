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

## QS-2.5.2 — DE-FUSED SwiGLU (DONE, banked)

Attack: _ffn no longer calls _gemm_silu. The SwiGLU
activation is precomputed ONCE per layer into o_fu in place
by the pre-existing _silu_mul_kernel (its arithmetic is
_silu_pair verbatim: f16r(f16r(g*sigmoid(g)) * up)), then the
down projection runs the plain _q8_gemv_kernel_v8. The fused
silu kernels stay in-file as reference (QS-2 precedent).
Cost: +1 tiny launch/layer (17,408 elements). Saves the
5,120x redundant silu+exp evaluation.
- Fixture: ALL PASS; (d)/(f) EXACT 0.0; (b) rank 1 gap 0.0,
  worst logits diff 0.0078125 (QS-2 band). Session ALL PASS.
- Real-file grade (lock held, QS-5 co-resident): P0 4/4,
  P1 18/18, P5 49/49 — 71/71 rank 1 gap 0.0 FAITHFUL.
- FFN segment (prof3): 196.4 -> 100.4 ms/token (floor 88.7).
  Profiled wall: 271.4 -> 181.3 ms/token.
- Long gen pairs (4/140, profile off, QS-5 rehearsal serve
  co-resident, load1 ~8.5): pair 1 (44.61-15.28)/136 =
  0.2156 s/token = 4.64 tok/s; pair 2 (44.89-15.00)/136 =
  0.2198 = 4.55 tok/s. GEN TEXT coherent (Paris.).
  vs QS-2 clean-window 0.2608-0.2815 (3.55-3.83 tok/s):
  ~1.21x. NOT across the 7.65 line — see ceiling below.

## QS-2.5.3 — attributed remainder (mode 4 sub-brackets)

Mode 4 (adds alpha/beta, conv+l2, delta sub-brackets;
fixture ALL PASS) per-SSM-layer: proj 658 us (alpha+beta
only 52; qkv+gate stream at ~129 GB/s in-engine vs 199
isolated), conv+l2 114 us, delta+ssm_out+add 435 us
(ssm_out stream ~168 -> delta_norm itself ~260 us/layer
= ~12.5 ms/token; state-traffic floor ~80 us — the delta
kernel is latency/occupancy-bound on dependent state RMW
chains). ATTN chain 1,314 us/layer vs ~392 us GEMV floor
(~10-15 ms/token across the 9-kernel small chain + GEMV
rate gap). FFN residual excess over stream floor ~12-25
ms/token, variable across runs (co-residency/clocks).
No further slice taken: each remaining item is ~5% class
and the delta/attention kernels are numerics-sensitive
rewrites that deserve their own graded campaign, not a
rush under a noisy co-resident window.

## Honest ceiling statement
Q8_0 streams 28.6 GB/token; at the best sustained rate
this memory system has shown (205-210 GB/s isolated) the
stream floor alone is 0.137-0.140 s/token = 7.2 tok/s.
Crossing Ollama's 7.65 needs >219 GB/s sustained IN-ENGINE
plus zero overhead — beyond the demonstrated memory rate.
Current: 0.216-0.220 s/token (4.55-4.64) co-resident;
remaining gap = ~35 ms small-chain/delta + ~40 ms GEMV
in-engine rate shortfall vs isolated bench. The 12.11
tier remains QS-3's (Q4_K_M, 16.2 GB/token).

## Lock record
Claimed 2026-11-15 02:51:29 EST (atomic mkdir + OWNER.txt);
released at QS-2.5.2 banking (see ledger). All heavy runs
above ran inside fenced systemd units (80G/96G) under the
claim, QS-5 rehearsal co-residency recorded per run.
