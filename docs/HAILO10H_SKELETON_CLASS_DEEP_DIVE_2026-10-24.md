# Skeleton-class deep-dive (2026-10-24)

Roadmap Campaign 4 iteration, slice 4.33 (AES-NUM-033).
Population: the skeleton classes named by AES-NUM-032 —
96 B, 80 B, and the single-segment classes 72/120/416 B —
in all seven corpus artifacts (MiniLM plus the six
hailo-ollama blobs), walked on Mimir with hef33.py
(sha256 9b40ded2…) plus the labelled end-word follow-up
hef33b.py (sha256 ca62a59d…). Controls: the walk
reproduces AES-NUM-029/032 EXACTLY (128,787 pooled small
actions; 79,001 pooled 24 B bursts).

## The 96 B two-word skeleton — a fixed pair of pairs

- 3,008 actions, channel 0 only, exactly **2 distinct
  segments**, 1,504 occurrences each. Positions 1–10 are
  the all-zero word in every segment (0 segments carry
  any nonzero middle word); only p0 and p11 ever vary.
- The two values at each end are **perfectly paired**
  (a bijection, no cross-pairings in 3,008):
  - `02289000d007002c` (p0) with `cd391d0000000000` (p11)
  - `002890009013002c` (p0) with `7f5c740000000000` (p11)
- Every artifact carries **both variants in exactly
  equal numbers** (6/6, 256/256, 180/180, 219/219,
  353/353, 219/219, 271/271), and every context carries
  exactly 2 segments — one of each variant (1,504
  contexts, per-context count histogram {2: 1504}).

## The 80 B walking bit — one diagonal block, all-or-nothing

- The walking word at position p (1–8) is a single `08`
  byte at stored byte offset 8−p of the word (p1:
  `0000000000000008`, p8: `0800000000000000`), each in
  exactly 2,219 segments — the count equality across
  positions is not a coincidence of marginals:
- **The ladder is all-or-nothing.** Counting positions
  carrying the exact ladder word per segment: 2,219
  segments carry it at **all 8** positions, 5,686 carry
  it at none, and **zero** carry a partial ladder
  (hef33b, exact-ladder definition). The middle of
  these segments is one fixed 8-word diagonal block.
  (A broader single-`08`-byte count in hef33 found 10
  further segments with a lone off-ladder single-`08`
  word at p4, byte offset 1 — not a partial ladder.)
- The 2,219 walking segments are exactly **148 distinct
  segments** (reuse up to 109×). Their end words are in
  bijection: p0 has 148 distinct values, p9 has 148,
  and the (p0, p9) pair has exactly 148 distinct values
  — a walking segment is fully determined by either
  end. Top pair: `00087000c0bf0316` +
  `78770d0000000000`, 109 segments.
- Walking segments occur in **all seven artifacts**
  (2/52 of MiniLM's 80 B actions; 214–452 per blob)
  and on **all three channels** (1,062 ch0 / 617 ch1 /
  540 ch2 of the 2,219).

## The single-segment classes — one corpus-wide quartet

- 72 B, 120 B and 416 B each remain **exactly one
  distinct segment corpus-wide** (sha prefixes
  4893a2010919 / 675bd65091f4 / a1f6073fc7ef), 1,504
  occurrences each — the identical segment in every
  artifact that carries the class, and **every**
  artifact carries it.
- Per-artifact counts are identical for all three
  classes and equal each artifact's context count:
  6 / 256 / 180 / 219 / 353 / 219 / 271 (sum 1,504).
  Each class occurs **exactly once per context**
  (1,504 contexts, histogram {1: 1504} for each).
- The 416 B segment's full anatomy: 52 words holding
  only **3 distinct words** — the all-zero word ×50,
  `03281003f005002c` at p0, and `18c2780000000000` at
  p51. A header word, a trailer word, and 400 zero
  bytes between them.
- **Co-variation is total.** Across all 1,504 contexts
  in the corpus, the presence combination is a single
  value: every context contains exactly {72 B ×1,
  96 B ×2 (one of each variant), 120 B ×1, 416 B ×1}
  and no context contains any other combination. The
  skeleton is a fixed per-context quartet; nothing in
  it varies with the artifact, the network, or the
  context's own layers. (Sole recorded resemblance:
  the 96 B p0 words and the 416 B p0 word share the
  trailing bytes `002c` — an observation, not a
  claimed meaning.)

## What this closes and what it queues

- MEASURED, corpus-wide: the 96 B skeleton is two
  perfectly paired end-word variants in fixed 1+1
  balance per context; the 80 B walking bit is a
  single fixed diagonal block carried whole by 148
  distinct end-determined segments; the single-segment
  classes are byte-identical across all seven
  artifacts; and the four skeleton classes form an
  invariant per-context quartet (1,504/1,504 contexts).
- NOT established: the meaning of any skeleton word,
  end-word, or of the quartet itself; what the 148
  walking segments' end pairs encode.
- NEXT (4.34): walking-segment pool sharing across
  artifacts (are the 148 a shared pool, and how does
  reuse distribute?); the skeleton quartet's
  intra-context ordering; the 96 B / 416 B shared
  `002c` fragment against the wider word vocabulary.
  Host/artifact analysis only.

## Evidence boundary

Host/artifact analysis only; no physical child ran.
Counts are complete-population over the seven
artifacts; blob identities are sha prefixes only.
