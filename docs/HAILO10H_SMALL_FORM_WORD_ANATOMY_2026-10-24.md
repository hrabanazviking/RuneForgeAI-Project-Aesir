# Small-form word anatomy (2026-10-24)

Roadmap Campaign 4 iteration, slice 4.32 (AES-NUM-032).
Population: every pointer action of size <= 512 B in all
seven corpus artifacts — MiniLM plus the six hailo-ollama
blobs — walked on Mimir with hef32.py (sha256 6de61055…;
the AES-NUM-029 schema-guided walk, extended to full
word-level anatomy per size class), plus a pair segment
comparison with segcmp32.py (sha256 54e87947…).
Controls: the walk reproduces AES-NUM-029's pooled
small-form total EXACTLY (128,787 actions) and the
79,001 pooled 24 B bursts (43,486 ch0 / 17,761 ch1 /
17,754 ch2). Per-artifact small actions: 684 / 21,277 /
14,533 / 19,875 / 28,980 / 19,875 / 23,563.

## The population splits in two

- **42 size classes** at <= 512 B. One is the 24 B burst
  (79,001 actions, treated in AES-NUM-010…031). The
  other **41 classes hold 49,786 actions and 1,289,731
  words, of which 425,699 (33.0%) are the all-zero word**.
- The contrast with the burst is sharp: across all
  237,003 burst words the all-zero word occurs **zero
  times** — a burst never contains a NOP word, while a
  third of the small-form surface is NOP words.
- Zero-words-per-segment is bimodal: 15,795 non-24
  segments contain no zero word at all, and separate
  spikes sit at 5 (1,736), 6 (3,276), 7 (3,415) and 10
  (3,108) zero words per segment. Two species share the
  size ladder: dense data segments and sparse skeleton
  segments. No segment of any class is all-zero.

## Species 1 — skeleton classes (near-constant templates)

Several classes are a single fixed template, or a
handful, repeated thousands of times (channel 0 only
unless noted):

| size | actions | distinct segs | zero words | anatomy |
|---|---|---|---|---|
| 72 B | 1,504 | 1 | 66.7% | one segment, corpus-wide |
| 120 B | 1,504 | 1 | 80.0% | one segment, corpus-wide |
| 416 B | 1,504 | 1 | 96.2% | one segment; only 3 distinct words in the whole class |
| 96 B | 3,008 | 2 | 83.3% | positions 1–10 are zero in 100% of segments; only p0 and p11 are ever nonzero, each with exactly 2 values (1,504 each) — a two-word skeleton in a 12-word form |
| 64 B | 1,511 | 6 | 62.3% | p2 and p4 zero in 100%; the rest near-constant |
| 304 B | 3,207 | 21 | 18.5% | p0 constant in 99.7%; p30/p32/p34 zero in 100%; a templated tail |

The recurring count 1,504 is the pooled per-context
repetition of these templates across the corpus. These
forms are per-context constants, not per-layer data.

## Species 2 — framed sparse arrays

- **176 B** (6,016 actions, channel 0 only, 69.2% zero):
  position 18 is zero in 100% of segments; the zero
  fraction climbs from ~54% to ~98% across positions
  1–17; positions 0 and 21 are never zero (framing
  words; p0 has only 4 distinct values). A sparse array
  with a header, a tail, and a guaranteed-empty slot.
- **344 B / 376 B / 248 B**: long runs where most
  positions are zero in ~74–85% of segments and the
  recurring nonzero word is `0100000001000000` — a
  sparse array whose typical entry is a single marker
  word, with per-position distinct counts of ~50–97.
- **424 B** (1,609 actions): from position 13 on, every
  odd position is the constant `0100000000000000` in
  100% of segments (1,609/1,609) while every even
  position varies (81–226 distinct values) — a strict
  marker/data alternation across 40 positions.

## Species 3 — dense data classes

- **328 B** (4,986 actions, 0.2% zero): the word
  `7f0000007f000000` dominates most positions (up to
  90.5% at p34) — repeated-pattern packed data, not
  configuration words.
- **400 B**: top word `7f7f7f7f7f7f7f7f`; **512 / 504 /
  496 B**: top word `1111111111111111` (512 of the
  512-class's 640 words). Uniform-byte patterns —
  weights-class data riding small sizes.
- **80 B** (7,905 actions, all channels, 1.9% zero)
  carries the slice's most striking pattern: at
  positions 1–8 the modal word is a single byte `08`
  that walks one byte position per word position
  (`…08`, `…0800`, `…080000`, …), each in exactly
  2,219 segments (28.1%). A walking-bit ladder across
  the middle of the form; positions 0 and 9 are the
  variable ends (236 and 4,634 distinct words).

## The 24 B-chunk test — small forms are NOT burst strings

Every non-24 size divisible by 24 was re-chunked into
24 B triples and tested against the burst laws. The
burst champion word heads **zero** chunks in every
class, and the lane-2 width law fails broadly in the
data-bearing classes (48 B: 3,600 of 7,202 chunks bad;
216 B: 9,562 of 14,913; 504 B: 120 of 126). It holds
only in the zero-dominated skeleton classes (72/96/
120 B: 0 bad), vacuously — their third words are the
all-zero word, not burst lane-2 datums. The small forms
are their own word grammar, not concatenations of the
burst form.

## Cross-artifact sharing, and one pair examined

- Non-24 segments: 13,340 distinct pooled; **1,340
  occur in two or more artifacts, 111 in three or
  more** — a shared template pool across networks,
  mirroring the shared datum pool of AES-NUM-019.
- Blobs 5ab3537d and 773470cd have identical aggregate
  small-form counts in every measure (19,875 actions,
  212,788 words, 58,068 zero words, 12,160 bursts),
  though the files are NOT identical (sizes differ by
  ~24 MB; first difference at byte 10). A direct
  segment-multiset comparison (segcmp32.py) shows the
  truth between those poles: **16,588 of 19,875
  segments (83.5%) are shared byte-for-byte; 3,287
  segments on each side are unique**, and the unique
  segments differ in operand/ladder words (e.g. burst
  lane-1 `…2c002050…` vs `…3400205002…`). Same form
  census, mostly shared templates, different operands —
  two compilations of one architecture family, recorded
  as measured; which models these blobs are is NOT
  claimed.

## What this closes and what it queues

- MEASURED, corpus-wide: the <= 512 B surface is 42
  size classes in three species — skeleton templates,
  framed sparse arrays, dense data — with position-
  level anatomy recorded for the twelve largest non-24
  classes; the all-zero NOP word is a small-form
  inhabitant only (33.0% of non-24 words, 0 burst
  words); small forms are not burst concatenations.
- NOT established: the meaning of any small-form word
  or position (anatomy is statistical, as with the
  burst programme before AES-NUM-021); the walking
  bit's role; which species each remaining class's
  semantics belong to.
- NEXT (4.33): skeleton-class deep-dive — the 96 B
  two-word skeleton's value pairs, the 80 B walking
  bit's full distribution, and the single-segment
  classes' identity across contexts and artifacts
  (what, if anything, varies, and with what it
  co-varies). Host/artifact analysis only.

## Evidence boundary

Host/artifact analysis only; no physical child ran.
Counts are complete-population over the seven
artifacts; blob identities are sha prefixes only.
