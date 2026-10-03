# Bounded packed-block header reuse — 2026-10-02

Numerical gates pass; performance is rejected for the targeted batch32 FFN.
Each thread caches16 per-row d/dmin F32 scales once per256-column block, reusing
them across eight staging sections. Q6 only needs d; inactive rows initialize
zero. A separate kernel preserves the original staged entry definition exactly.
All dequantization/F16 high-residual/barrier/MMA accumulation/store order remains;
no additional shared/global/device buffer. Default cache_headers stays False.

All144 synthetic Q4/Q5/Q6 tails,12 invalid spans,1622640 real unowned/input guards,
1658880 complete native/cached/original F32 outputs and2100 selected independent
Float64 dots pass unchanged .002 scaled/.0002 normalized RMS budgets. Every cached
output bit equals original staging, including signed zero. Original real model
uses Q4/Q6; Q5 is synthetic. Binary/CSV/model hashes bind complete evidence.

Ten rotating native/cached/original samples per each28 real cases, three actual
calls each, retain840 timing records. Host-monotonic launch/synchronize medians
exclude allocation/export. All six builds finish before one serial GPU capture;
pinned gguf0.19.0/NumPy2.4.4 oracle follows and rehashes model/CSV. Ratios below1
mean cached headers are slower than original staging in the SAME capture:

| Batch | Q | K | V | Output | Gate | Up | Down |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 4 | 0.9219 | 1.0423 | 0.8133 | 0.9297 | 0.9692 | 0.9529 | 0.8341 |
| 8 | 0.9751 | 1.0167 | 1.0301 | 0.9810 | 0.9631 | 0.9584 | 1.0270 |
| 16 | 0.8682 | 0.8090 | 0.8018 | 0.8622 | 0.8285 | 0.8244 | 0.8610 |
| 32 | 0.7589 | 0.7661 | 0.9699 | 0.8120 | 0.6843 | 0.6890 | 0.9025 |

Batch32 gate/up/down ratios .6843/.6890/.9025 mean about46.1%/45.1%/10.8% more
elapsed time. This rejects reuse as the next speed improvement. The hypothesis
that extra register lifetimes reduce occupancy is unproved: no counter/resource
measurement is inferred from a ratio. Preserve all raw samples and defaults.

Fourteen portable matrix contracts include complete three-owner rotation/exact
F32/signed-zero, wrong geometry/missing column/totals/newline, complete numerical
failure retention, source mutation, interruption and exclusive output. Previous
schemas remain admitted. Both targets, legacy collector, master190 passes/zero
fails/one skip, normal rebuild/check pass. Normal f3442a1e binary and authenticated
active/ready/prefill4/cpuoffload0 remain. Initial Float32.bitcast compiler failure
and initial combined-entry prototype remain private and unscored.

No full-model/captured-activation/service/provider/production32 claim is earned.
Keep the original staging path. Next scope larger CTA row reuse with bounded
shared storage and exact original output bits, rather than longer-lived per-thread
header arrays. Exact push/CI receipts are separate.
[Operation](../../NATIVE_TURING_BLOCK_HEADERS.md).
