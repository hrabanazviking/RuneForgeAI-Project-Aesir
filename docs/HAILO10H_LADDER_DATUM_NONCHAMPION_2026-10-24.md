# Ladder origin/range, datum identity test, non-champion anatomy (2026-10-24)

Roadmap Campaign 4 iteration, slice 4.18 (AES-NUM-018).
Method: hef18.py (sha256 3ec7963f…) on Mimir over the
AES-NUM-017 populations — every 24-byte channel-1/2 burst
in MiniLM (153 bursts, 132 champion) and ollama blob
5ab3537d (5,546 bursts, 4,819 champion), with context
index and pointer offset retained per burst.

## 1. The ladder is a fixed six-value slot set — origin/range ANSWERED

Lane-1 u16 pos 3 in champion bursts takes almost no values:

- **MiniLM: exactly 6 distinct values** —
  `0x10f0, 0x12f0, 0x14f0, 0x16f0, 0x18f0` (five rungs,
  stride `0x200`, common residue `0xf0`) plus `0x2d80`.
  The per-context value sets are **identical in all 6
  contexts** (union = intersection = 6).
- **Blob 5ab3537d: the same 6 values are the intersection
  of all 219 contexts**; the union adds exactly one more,
  `0x2a8e`, occurring in a single context (recorded as an
  anomaly, not smoothed — the same class as AES-NUM-017's
  single `0x02c8`).
- Counts: the five rungs carry 120/132 MiniLM bursts;
  `0x2d80` carries exactly **2 per context** in both
  artifacts (12 MiniLM; 438 blob). In context 0's sequence
  the `0x2d80` pair sits mid-skeleton, after a descending
  paired run of rungs (`18,18,16,16,14,12,12,10,10,14`
  ×0x100 + 0xf0) and before the ascending repeat.
- The ladder does **not** track the burst's own file
  position: MiniLM's 132 champion bursts have 132 distinct
  pointer offsets spanning 2,511,360 → 11,698,456 while
  the ladder reuses its 6 values.

**Reading:** origin `0x10f0`, range `0x10f0–0x18f0` (five
`0x200`-strided slots) plus one special slot `0x2d80` —
the SAME set in a 6-context embedding network and a
219-context LLM. The ladder walks no network-specific
region; it is a fixed slot table (behavioural grade).
What the slots *are* is still not named.

## 2. Datum identity: float reading excluded; shared pool MEASURED

Lane 2's 24-bit datum (bytes 16–18, LE) at full width:

- The two leading values are **identical across both
  networks at full 24-bit width**: `0x60e517` and
  `0x56898c`, each repeated **exactly context-count
  times in both artifacts** (6× MiniLM, 219× blob).
  AES-NUM-017 called them per-network constants; at
  u24 resolution they are **cross-network** constants.
- The datum vocabulary is a **shared pool**: 38 of
  MiniLM's 62 distinct u24 values also occur among the
  blob's 417. Next-frequency values repeat ~55× in the
  blob (≈219/4) and 5× in MiniLM — context-count-scaled
  repetition, not network-private data.
- **Float identity NOT PROVEN, one reading excluded:**
  read as float32 with a zero high byte, every top datum
  is a ~1e-39 subnormal — not a plausible network
  constant. No searched known-constant match is claimed.
  The datum behaves as a compiler-emitted token drawn
  from a cross-network pool; its identity stays open.

## 3. Non-champion lane-0 families: a different, data-bearing kind

- MiniLM: 21 bursts, 17 distinct lane-0 words — near-
  unique, data-like. Blob: 727 bursts, 43 distinct
  lane-0 words with structured counts (56, 56, 29, 29,
  29, 28, 28…).
- Lane-0 low halves cluster in two classes: `0x28xx`
  (champion is `0x2805`; families `0x2800`, `0x2802`,
  `0x280c`) and `0x08xx` (`0x0801`, `0x0803`). One MiniLM
  family (`03080000f8bf…`, 12 bursts by prefix) carries a
  nonzero high half in lane 0 itself — data riding in
  the header lane.
- **The champion's lane-1 anatomy does NOT carry over:**
  in the top non-champion families there is no `0x0250`
  constant, no tiny enum, no ladder — lane 1 is
  high-entropy / data-class (blob families concentrate
  just below `0x7fff`, unlike any champion field).
- **The lane-2 width law DOES carry over:** bytes 19–23
  are zero in every burst of every top family sampled
  in both artifacts (n/n in all five top families each).

## 4. Refinement of AES-NUM-017's enum

Blob champion lane-1 pos 1 counts: `0x2000` ×1,676,
`0x1000` ×1,676, `0x2001` ×514, **`0x1001` ×514** (new),
`0x0000` ×439. The field is a class (`0x0000/0x1000/
0x2000`) × a low bit (0/1) — five of six combinations
observed. MiniLM shows the three bit-0 classes only
(60/60/12).

## Evidence boundary

Exact counts over the stated populations; the two
single-context anomalies (`0x2a8e` ladder value, and
AES-NUM-017's `0x02c8`) are recorded, not smoothed.
No field is semantically named. Enum/flag *meanings*
still need a one-parameter differential, and no
same-family pair is in hand yet — that remains the
recipe/model-zoo pair's job (AES-NUM-012 design).
Next (4.19): the `0x2d80` special slot's burst context
(what precedes/follows it in the skeleton); datum-pool
structure across the full 7-artifact corpus; the
`0x08xx` lane-0 class anatomy.
