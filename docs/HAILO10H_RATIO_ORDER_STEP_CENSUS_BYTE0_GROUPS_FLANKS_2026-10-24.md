# No ratio sequence is monotone in k — all 54 cidx-side sequences are NEITHER non-decreasing nor non-increasing (pairwise inversions 4–11 in each direction), with 15 distinct deviation sign patterns over the six ratios (modal +-+-+- ×10, -+-+-+ ×7, -+-++- ×6) — and the pooled step census of the multi-key byte-3 tables carries 161 steps in 32 distinct values (−19…+26), the step NOT a function of the sum pooled under either anchoring (27 violating sums each way) while per byte-3 it is a function only vacuously (each sum occurs once per table); byte 0's non-determination is localized: inside group (14, 9992) the full key still fails on exactly the two narrow keys, while groups (19, 7712) (3 pairs / 3 keys) and (20, 32720) (216 pairs / 216 keys) are exact functions with zero violations, and all eight narrow pairs carry B byte 0 == A byte 0 with XOR exactly 0x80000000; the before-flank (2817536, 24, 0) is end-anchored at position-from-end exactly 20 in all 271 of its contexts (20 distinct positions), followed by 51 distinct size-24 channel-0 acts (displaced-block-first in only the 3 block contexts, other in 268); the 30 class-271 shared acts stand in identical relative order in contexts 114 and 251 (0 inversions of 435 pairs; 29 at position difference 0, the lead act (2727936, 24, 2) at +4; 28 of the 30 take exactly 20 distinct corpus positions, the first two 51 and 54); and each after-flank following pair ((24, 0), (24, 1)) occurs consecutively exactly once corpus-wide, in its own block context, its (24, 0) member occurring at most twice and its (24, 1) member at most twice — mechanisms NOT PROVEN (AES-NUM-128)

Slice 4.128, worked under `docs/TASK_CONTRACT_4.128.md`
(contract committed first @ ceda81ea). Host/artifact analysis
only, on Mimir (purpleviking1) — no physical child, no
device run of any kind. All findings below are taken from
the sha-verified raw output; the few derived counts marked
as such were computed at closing from the run's own
printed tables, never sampled.

## Run and closing record

hef128.py (the hef127 file verbatim as base — itself the
hef126 lineage — plus the new arms128) sha256
`4ae3056b6df2ff1c8892129f27608533188be21e500cc07dd7300d9cf5996cf8`
(395,619 B); arms128.py sha256
`ae4c79d1a23387af89af65591d1fb99184352715192218283c2e65501b0214d3`
(16,857 B), its gzip sha256
`0738c258ec34a57dfdb4abc9b42cfc9f12713e1a1b1a79f1d25a736cf90ddcdb`
(5,106 B). The transfer and launch were carried out by the
earlier 4.128 continuity workers (state file entries
02:03–02:21 EDT): arms128 crossed via the proxy-upload
route (no payload through model re-emission), hef128 was
assembled on-device sha-gated, and the one bounded
host-side child was launched with the contract corpus
argv (the six hailo-ollama blobs in glob order, then
MiniLM — the launch law recorded in the contract after
4.127's no-argv failure). The run finished on-device at
02:31 EDT with an empty error file; this closing worker
verified on-device that /tmp/hef128.py's sha256 equals
the VM-built file exactly and that /tmp/hef128.err is
0 B. The retrieved output is 17,368 lines / 2,949,346 B,
sha256
`725218d55c33f66d603350bf11ede4f0ff6337393c909bb4a2c2aaa99ff73fc7`;
retrieved gz sha256
`fb9f8a5950c18008cf1c849bc024b62f1c1963082842f76ad636ef56f509cd9a`
(377,619 B, fetched through a temporary on-device HTTP
server via the tunnel proxy; the fetched gz sha256
equals the on-device gz sha256 and decompresses to
exactly the output sha256, verified on the VM at
closing); DONE128 is the output's last line (17,368);
the 4.128 section begins at output line 16,637 —
exactly one past 4.127's total line count, the base
having reproduced line-for-line.

## Controls

Inherited controls reproduce EXACTLY: cells 55,902 /
obs 527,236; divergent triples 2,171, verdicts
CONT 12,411 / BREAK 476 / INDET 2,365; lane-1 pairs
224; (byte 3, byte 1, byte 2) keys 222; (byte 3, sum)
keys 222; trajectories 27 cidxs × (7 deltas / 6 ratios)
per side; byte-3 tables 61, multi-key values 37, with
the 4.127 monotonicity class distribution reproduced
{CONSTANT 2, NEITHER 25, NON-DECREASING 8,
NON-INCREASING 2, SINGLE-KEY 24}; wobble pooled
deviations 324, zero deviations 0; shared 114×251 acts
168; occurrence-2 population 127; non-occurrence-2
shared acts 41.

## (i)(a) The ratio sequences' internal order

Each of the 54 sequences (27 cidxs × sides A/B) printed
its six ratios in k order as exact fractions, its
sequence median ((3rd + 4th sorted)/2, as in 4.127),
the deviation sign of each ratio against that median,
the successive-ratio signs, and pairwise inversion
counts in both directions, all in full.

- Monotonicity in k: **NEITHER for all 54 sequences**
  (class distribution {NEITHER: 54}); the NON-DECREASING,
  NON-INCREASING and CONSTANT lists are all empty.
  Every sequence carries inversions in both directions:
  non-decreasing inversion counts and non-increasing
  inversion counts each range 4–11 over the 54
  sequences (derived at closing from the printed
  per-sequence counts).
- Deviation sign patterns (sign of ratio − median, in
  k order): 15 distinct patterns over 54 sequences —
  `+-+-+-` ×10, `-+-+-+` ×7, `-+-++-` ×6, `-++-+-` ×4,
  `++-+--` ×3, `++--+-` ×3, `+-+--+` ×3, `+--+-+` ×3,
  `-+--++` ×3, `--++-+` ×3, `+-++--` ×2, `+---++` ×2,
  `-+++--` ×2, `--+-++` ×2, `+--++-` ×1 (68, B). No
  pattern is constant-sign (none could be: the median
  of six distinct ratios splits them), and the two
  fully alternating patterns together account for
  17 of 54 sequences.

Verdict: the ratios have no monotone order in k, in
any sequence. Any closed form for the decay must
reproduce a non-monotone, mostly alternating sign
structure. Exact decay form NOT PROVEN (unchanged).

## (i)(b) Pooled step census of the multi-key byte-3 tables

All 37 multi-key tables printed in full (sums, diffs,
successive steps anchored at their starting sums);
each table's steps were asserted equal to the 4.127
recorded steps inside the run.

- Pooled: **161 steps, 32 distinct step values**
  (−19…+26; the full multiset is printed in the
  output: 0 ×24, 1 ×15, −1 ×13, −5 ×10, 5 ×10,
  7 ×9, −10 ×6, −4 ×6, 6 ×6, 3 ×7, and a long tail
  down to single occurrences of −19, 13, 16, 17, 18,
  26).
- By table class: NEITHER tables carry 144 steps in
  31 distinct values; NON-DECREASING 11 steps in 8
  values {0, 1, 7 ×2, 8, 9, 11, 12 ×2, 14 ×2};
  NON-INCREASING 2 steps {−5, −3}; CONSTANT 4 steps,
  all 0.
- Step as a function of the sum, tested exactly:
  pooled with steps anchored at their STARTING sum —
  NOT A FUNCTION (126 distinct anchor sums, 27
  violating sums, e.g. sum 254 → {−19, 1, 2}, sum 264
  → {1, 3, 12}, sum 161 → {−5, 0, 1}); pooled with
  steps anchored at their ENDING sum — also NOT A
  FUNCTION (129 distinct anchor sums, 27 violating
  sums, e.g. sum 264 → {−3, 2, 7, 11}). Per byte-3
  (starting-sum anchoring): 37 tables tested, 0 with
  any violating sum — but this is vacuous: within one
  table every sum occurs once, so no sum can carry
  two steps. The per-table verdict therefore proves
  nothing; the pooled verdict is the substantive one.

Verdict: pooled, the step is not determined by the
sum under either anchoring. Step closed form NOT
PROVEN.

## (ii)(a) Byte 0 determination inside each group

The map's three groups are the lineage (cell pos,
cell size) groups of a pair. Determination of B byte 0
by the full (byte 3, byte 1, byte 2) key was computed
separately inside each group, in full:

- Group (14, 9992): 5 pairs, 3 keys, A byte 0 and
  B byte 0 each {20, 24, 28, 32, 68} — **NOT A
  FUNCTION**: 2 violating keys, exactly the two
  narrow keys (128, 1, 176) → {28, 32} and
  (128, 1, 178) → {20, 24}.
- Group (19, 7712): 3 pairs, 3 keys — **IS A
  FUNCTION** (0 violating keys).
- Group (20, 32720): 216 pairs, 216 keys, A byte 0
  spanning 33 distinct values, B byte 0 26 — **IS A
  FUNCTION** (0 violating keys).

Verdict: the global non-determination of AES-NUM-127
is localized entirely to group (14, 9992) and, inside
it, to the two narrow keys. Determination inside the
other two groups is exact on the full populations.

## (ii)(b) The narrow population's eight pairs in full context

The eight narrow pairs (split: 5 in group (14, 9992),
3 in group (19, 7712)) were read with every record
(group, cell, cidxs, offsets, and the full A/B words
of each record) printed:

- Every one of the eight pairs has byte-3 difference
  exactly ±128, full difference exactly ±2³¹, A/B
  XOR exactly 0x80000000, and **B byte 0 == A byte 0**.
- The five (14, 9992) pairs each occur in 27 records
  (cells at pos 14, offsets 1744 / 7424 in the
  printed records; cidxs stepping by 4 from 101,
  centres stepping by 4, differing lanes [0, 1, 4]):
  key (0, 1, 162) sum 163, byte 0 68, diff +128;
  keys (128, 1, 176) sum 177, byte 0s 28 and 32,
  diff −128; keys (128, 1, 178) sum 179, byte 0s 20
  and 24, diff −128. The key collisions of (ii)(a)
  are exactly these: two different A byte 0s share
  each of the keys (128, 1, 176) and (128, 1, 178),
  and B byte 0 copies A byte 0 in each pair — so the
  key, which omits byte 0, cannot separate them.
- The three (19, 7712) pairs occur in 1 record each:
  key (0, 1, 176) sum 177, byte 0 20, diff +128;
  key (128, 1, 160) sum 161, byte 0 68, diff −128;
  key (128, 1, 177) sum 178, byte 0 20, diff −128.

Verdict: within the narrow population the byte-0
behaviour is a pure copy (B byte 0 == A byte 0 in
8 of 8 pairs); what breaks determination is that the
tested keys do not contain byte 0. A determination
that includes A byte 0 was NOT tested here and is
named for 4.129. Mechanism NOT PROVEN.

## (iii)(a) The before-flank across all 271 contexts

(2817536, 24, 0) printed in every one of its 271
contexts (position, context length, position-from-end,
following act), in full:

- **Position-from-end is exactly 20 in all 271
  contexts** (distribution {20: 271}) — the
  before-flank is end-anchored. Its absolute position
  takes 20 distinct values {165 ×2, 223 ×1, 224 ×55,
  226 ×1, 235 ×27, 238 ×28, 244 ×2, 411 ×1, 478 ×1,
  486 ×1, 585 ×29, 586 ×26, 605 ×6, 665 ×6, 706 ×2,
  717 ×55, 818 ×6, 821 ×6, 852 ×12, 853 ×4}.
- Following-act census: 51 distinct following acts,
  **every one a (·, 24, 0) act**; grouped census
  {DISPLACED-BLOCK-FIRST-ACT: 3, OTHER-SIZE-24-ACT:
  268}. The modal followers are (5703168, 24, 0) ×28,
  (900764672, 24, 0) ×27, (109663232, 24, 0) ×26,
  (1255548416, 24, 0) ×25, (1258193920, 24, 0) ×25;
  the displaced block follows in exactly the three
  block contexts (128 / 251 / 265) established before.

Verdict: the before-flank's place is fixed from the
end, not from the start; what follows it varies over
51 acts of one shape. Mechanism NOT PROVEN.

## (iii)(b) The 30 class-271 shared acts in full

All 30 acts printed in full (corpus occurrences 271
each, in 271 distinct contexts each; positions in
cidx 114 and cidx 251; full occurrence position
summaries):

- Relative order: the order of the 30 by 114 position
  and by 251 position are **identical** — 0 relative-
  order inversions of 435 pairs.
- Position differences (251 − 114): +0 for 29 of the
  30; the sole exception is the lead act
  (2727936, 24, 2) at +4 (114 pos 780, 251 pos 784).
- Position spread: 28 of the 30 take exactly 20
  distinct corpus positions; the exceptions are the
  first two in the shared order — (2727936, 24, 2)
  with 51 distinct positions and (2774016, 24, 1)
  with 54. The remaining 28 are the rigid end block:
  their 20-position distributions are the before-
  flank's own 20-position distribution shifted by a
  fixed per-act offset (e.g. (172544, 376, 0) at
  distribution {131 ×2, 190 ×55, …, 819 ×4} against
  the before-flank's {165 ×2, 224 ×55, …, 853 ×4}).
  The before-flank itself is the last of the 30 in
  the shared order (114 pos 821, 251 pos 821).

Verdict: the class-271 population is one conserved
end-anchored block of 28 rigid acts preceded by two
looser acts, holding the same order in both contexts.
Mechanism NOT PROVEN.

## (iii)(c) The after-flank's following pairs

In each block context the act pair immediately after
the after-flank (1113626112, 24, 0) is a (24, 0) act
followed by a (24, 1) act; each act and each pair was
profiled corpus-wide in full:

- Cidx 128: (839257600, 24, 0) @823, (839342080, 24, 1)
  @824. The (24, 0) act occurs twice corpus-wide
  (also cidx 111 pos 6, between two (·, 24, 2) acts);
  the (24, 1) act occurs twice (also cidx 111 pos 19).
  The consecutive pair occurs exactly once.
- Cidx 251: (2056343552, 24, 0) @826, (2056344064, 24, 1)
  @827 — each occurs exactly once corpus-wide; the
  pair occurs exactly once.
- Cidx 265: (2207048704, 24, 0) @823, (2207049216, 24, 1)
  @824 — each occurs exactly once corpus-wide; the
  pair occurs exactly once.

Verdict: what follows the after-flank is private to
each block context (the 128 pair's members recur only
separately, in cidx 111, never as a pair). No shared
continuation exists. Mechanism NOT PROVEN.

## NEXT — slice 4.129

- (i) Byte-0 determination with A byte 0 admitted to
  the key: B byte 0 as a function of (byte 3, byte 1,
  byte 2, A byte 0) globally and inside each group —
  in particular whether group (14, 9992)'s failure
  closes under the admitted key, and whether the map
  is the identity on byte 0 beyond the narrow
  population.
- (ii) The deviation sign patterns paired across the
  two sides of each cidx (27 A/B pattern pairs in
  full: equality, complement and reversal tests), and
  the pooled step census refined by anchor class —
  step as a function of (starting sum, starting diff)
  tested exactly.
- (iii) The class-271 end block's position-from-end
  structure across all 271 contexts (each of the 30
  acts' from-end distribution; whether the 28 rigid
  acts hold fixed from-end offsets in every context,
  as the before-flank's constant 20 suggests), and
  the two loose lead acts' (2727936, 24, 2) /
  (2774016, 24, 1) positions against the block in
  every context.

Host/artifact analysis only — no physical child.
