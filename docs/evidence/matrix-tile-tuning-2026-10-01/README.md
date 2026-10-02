# Matrix tile tuning — 2026-10-01

Six actual strict3B sm_75 configurations pass fixed numerical/guard contracts.
All9,953,280 native-reference outputs and12600 selected independent Float64 dots
pass unchanged budgets.864 synthetic tails and72 invalid-span rejections pass.
Complete3360 paired timing records are preserved. Original32/32 stays callable.

| Rows / staged columns | Shared bytes at batch32 | Best batch4 ratio | Best batch32 ratio |
|---|---:|---:|---:|
| 32 / 32 | 8448 | 0.446 | 1.255 |
| 32 / 64 | 16640 | 0.433 | 1.290 |
| 32 / 128 | 33024 | 0.388 | 0.719 |
| 16 / 64 | 12480 | 0.457 | 0.809 |
| 16 / 128 | 24768 | 0.459 | 0.834 |
| 8 / 128 | 20640 | 0.495 | 0.862 |

Ratios compare equal existing four-token primitive work against each candidate.
Best means the best of seven actual tensor shapes, not a whole-model score.
Every candidate loses at batch4 on every shape; none is promoted. Larger staging
can reduce barrier count while worsening occupancy/register use; the measured
results do not identify the precise hardware cause without another trace.

The original exploratory sweep overlaps host compilation during its first case;
it is preserved but excluded from scoring. The final complete sweep runs after
all compilation ends, with owned GPU work serialized. Each sample repeats three
calls, with ten alternating pairs per real tensor/batch. Both exact input formula
and original model bytes are unchanged. Raw CSVs/binaries stay outside Git and
their hashes are in provenance.json. Public JSONs retain all paired samples.

The best batch32 FFN observation is about1.29x, while K/V still lose. Full-model
control/numerical integration and the2x fresh-prefill target remain open. The next
prerequisite is physical locked-runtime Turing Tensor-Core execution; standard
F32 SIMT staging alone has not earned default dispatch. Native binary remains
f3442a1e, original service active. No model/provider/corpus policy changes.
[Operation](../../NATIVE_MATRIX_CANDIDATE.md). Exact pushed CI is a separate receipt.
