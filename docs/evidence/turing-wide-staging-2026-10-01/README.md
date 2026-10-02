# Wider shared-input Turing staging — 2026-10-01

Four explicit CTA/input choices pass unchanged primitive budgets: 6,635,520
complete native values, 8400 selected independent Float64 dots, 576 synthetic
tails, 48 invalid spans and 2240 paired timing records. Every sample remains.
All host compilation ends before serialized GPU work; independent CPU oracles
run after all captures. Original packed bytes and input formula are unchanged.

| CTA rows | Input columns | Shared bytes, batch32 | Best batch4 ratio | Best batch32 ratio |
|---|---:|---:|---:|---:|
| 32 | 64 | 12480 | .249 | 1.188 |
| 32 | 128 | 24768 | .232 | .803 |
| 64 | 64 | 20800 | .209 | 1.304 |
| 64 | 128 | 41280 | .148 | .941 |

Ratios compare equal existing four-token primitive work. Best means best of
seven tensor shapes. Every batch4 shape loses. Wider choices are worse than
prior32-column captures; keep that default. No hardware cause, whole-model
quality or provider score is inferred. F16 activation conversion still requires
its own ordinary-F32 and full-model gates; test inputs are binary fractions.

rows-*-columns-*.json retain all numerical/timing samples. provenance.json hashes
raw CSV/binaries/builds outside Git. Ten portable contracts preserve prior mode
identity; hosted CI compiles optional probes only. Production binary stays
f3442a1e with active service and authenticated HTTP200 readiness. Exact pushed
CI is separate. Next gate ordinary F32 activation precision before full-model
integration. [Operation](../../NATIVE_PACKED_TURING_MATRIX.md).
