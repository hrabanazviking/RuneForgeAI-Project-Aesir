# Coalesced shared Turing matrix staging — 2026-10-01

Three CTA row configurations pass unchanged primitive budgets:4,976,640 complete
native output pairs,6300 selected independent Float64 real dots,432 synthetic
tails,36 invalid spans and1680 paired timing records. Original packed bytes,
exact input formula, warmup/alternating order and all-output guards are unchanged.
Host compilation ends before every capture; GPU work is serialized16/32/64 and
independent CPU oracles run only after GPU work ends. All samples remain.

| CTA rows | Shared bytes, batch32 | Best batch4 ratio | Best batch32 ratio |
|---|---:|---:|---:|
| 16 | 4224 | .318 | .860 |
| 32 | 6336 | .328 | 1.506 |
| 64 | 10560 | .294 | 1.920 |

Ratios compare complete equal existing four-token primitive work. Best means
best of seven tensor shapes; there is no whole-model/provider score. Every
batch4 shape loses. Rows64/batch32 Q/K/V/output/gate/up/down ratios are1.782/
1.054/.771/1.797/1.920/1.876/1.524. V still loses. No default is promoted.

All-thread barriers protect coalesced32-column staging at padded33 pitch. F16
high/residual weights and once-converted inputs feed public m16n8k8/F32 MMA
using the proved isolated sm_75/PTX6.5 target. Shared bytes<=10560, no added global
workspace. Real Q4_K/Q6_K and synthetic Q5_K scope remains; current binary test
activations are F16-representable. Full-model activation quality is still open.

rows-*.json retain every numeric/timing gate; provenance.json hashes all raw
CSV/binary/build artifacts outside Git. Nine portable tests pass; hosted CI only
compiles optional probes. Original native executable stays f3442a1e and service
active. Next measure wider staging while preserving budgets, references and
separate full-model/control/recovery/provider acceptance. No hardware-cause claim.
[Operation](../../NATIVE_PACKED_TURING_MATRIX.md). Exact pushed CI is separate.
