# A-123 — Sliding-window attention parity

Wave 14 (Architecture breadth). Roadmap text:
"Sliding-window attention parity. Acceptance: rows
judged at window-boundary lengths specifically."

## What was built

- `aesir_engine/core/sliding_window_battery_a123.mojo` —
  the battery: windows (16, 512, 4096) x boundary
  lengths (W-1, W, W+1, 2W-1, 2W, 2W+1, query_pos =
  L-1) x 4 Z13 backends = 72 rows judged against the
  banked engine rule, plus 4 seeded synthetic defect
  cases. 4096 is the Gemma2 local-layer window the
  engine config carries; 512 and 16 are reduced
  windows over the same kernel rule, stated as such.
- `aesir_engine/tests/test_sliding_window_battery_a123.mojo` —
  13 E-MASTER cases (`sliding.battery_*`).
- `aesir_engine/tests/bench_sliding_window_battery_a123.mojo` —
  one-command driver; log `hidden_files/a123_battery.log`.

## The rule under test

`core/compute.mojo` `flash_attention_gqa` skips a
position when `sliding_window > 0 and query_pos -
position >= sliding_window` — a position is attended
iff `query_pos - position < sliding_window`. The CPU
rows execute that banked kernel against an
independent two-pass scalar reference written
in-module from the definition (not copied from the
kernel), and every CPU row's attended count must
equal min(L, W) exactly. `core/kv_window.mojo`
(the J-097 KV editor service) is a different surface
and is not the subject of this slice.

## Fixture honesty

The fixture is a deterministic LCG fixture labelled
SYNTHETIC in the module header and in every rendered
line. It carries a sharp boundary probe: boosted
keys (key += 6 x the mapped query row) and extreme
values (+4.0 / -4.0 on every dimension) at the
first-included and first-excluded positions, so an
off-by-one window moves the output by far more than
the parity bound. The parity bound is A-043's filed
LCG bound: max abs diff <= 0.01 (100 in x10000
units). Geometry: head_dim 32, 4 query heads, 2 kv
heads (GQA group 2).

## Verdict rule (pre-registered)

- non-cpu backend -> NOT_GRADED
  (BACKEND_NO_CPU_COMPARATOR; CPU vs CPU only, no
  device-execution evidence exists for these rows;
  accelerator-visible is not accelerator-run).
- cpu -> FAITHFUL iff attended == min(L, W) and the
  kernel output matches the reference within the
  parity bound; otherwise DIVERGENT.
- Every row carries the A-115 policy obligation of
  the Gemma witness quant, read from the banked
  `core/exactness_policy.mojo` by call: Q4_K_M ->
  TOKEN_EXACTNESS_OWED on all 72 rows.
- A-111's near-tie gate governs teacher-forcing
  token rows; this battery files none, so the gate
  is not invoked. A-116's localiser is the named
  tool for any genuinely DIVERGENT engine row; this
  battery files none.

## Filed results

Battery run (`hidden_files/a123_battery.log`,
MOJO_EXIT=0):

- Rows: total 72, FAITHFUL 18 (all cpu), NOT_GRADED
  54, DIVERGENT 0. Every CPU row at
  max_diff_x10000 = 0 — bitwise against the
  reference, inside the filed 0.01 bound.
- Policy: owed 72, coherence 0.
- Digest: 14784864525343607696 (deterministic;
  re-running the bench reproduces it — the
  `sliding.battery_digest_deterministic` case
  asserts exactly that).
- Seeded synthetic defects, each discriminated on
  this very fixture: SYN_OFF_BY_ONE DIVERGENT
  (reference admitting `query_pos - p <= W`,
  max_diff 3.4849), SYN_WINDOW_IGNORED DIVERGENT
  (full attention, max_diff 3.7456), SYN_WINDOW_FREE
  FAITHFUL (full attention at L = W, where a window
  cannot bind), SYN_MISMATCH COMPARATOR_ARTIFACT
  (BACKEND_MISMATCH).

## Suite

SUITE_RESULT_A123

Pin: 814 -> 827 (+13 run_all cases).
