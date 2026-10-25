# Cidx law corpus-wide, 113 schedule verdict, staircase regions (2026-10-24)

Roadmap Campaign 4 iteration, slice 4.88 (AES-NUM-088).
Populations: all seven corpus artifacts (MiniLM plus the
six hailo-ollama blobs), walked on Mimir with hef88.py
(sha256 65ae0a53...), sha-verified on-device after a
one-shot proxy-receiver transfer (receiver returned gz
sha256 438d6537..., matching). Output file
/tmp/hef88_out.txt sha256 547fb3f9.... Controls
reproduce AES-NUM-029/032...087 EXACTLY (128,787 pooled
small actions; 79,001 pooled 24 B bursts; 745,849
pointer actions; 1,504 contexts; trailing distinct
(channel, operand) pairs 2,049; champion-headed bursts
75,215). Definitions (camps, classes, cidx / ngpos) are
as in AES-NUM-061...087. Contract:
docs/TASK_CONTRACT_4.88.md (published @ 36f07682 before
implementation).

## (i) The cidx law is corpus-wide — but the constant is per-artifact, and context 92 itself is ordinary

The scan grouped every segment at action position <= 30
with size 8,000–40,000 B (the band holding both known ff
populations) by (artifact, position, size), kept groups
with >= 8 instances, and tested the aligned ff words
(ff <scalar> 00 00) common to every instance: 505 groups
in total (79 / 70 / 89 / 84 / 88 / 95 in the six blobs;
MiniLM holds no group in the band). Of those, 131 groups
share < 10 common ff offsets, 2 share >= 10 with no
variable offset, and 372 share >= 10 with at least one
variable offset.

- In 371 of the 372 variable groups the variable slots
  repeat ONE scalar per segment. The single exception
  (0a0d378c pos 25, size 32,632) has an adjacent offset
  pair (11820/11824) that breaks the repeat; even there
  the first variable offset's scalar obeys the law
  below exactly.
- In ALL 372 variable groups the per-segment scalar is
  an exact affine function of the context index with
  slope exactly 1: scalar = cidx + C, zero exceptions.
  Only six constants occur, and each artifact carries
  exactly two of them: C = +1 (181 groups, every blob)
  and one negative artifact constant — 0856a10c: -99
  (30 groups), 0a0d378c: -73 (32), 5ab3537d: -94 (32),
  76c3a8ff: -92 (43), 773470cd: -94 (35), cc9b9d1c:
  -133 (19). The sister pair shares its constant (-94).
  Where a population's cidx spacing is constant, the
  same law also reads as a rank ladder (slopes 3/4/6/8/9
  recorded); those are re-descriptions, not rival laws.
- The scan re-derives the three known populations
  untouched: 76c3a8ff pos 18 sizes 21392/21648 (43 common
  ff, 4 variable, C = -92) and pos 20 size 14528 (18
  common, 3 variable, C = -92, the 21 + 9 x rank ladder).
  AES-NUM-087's law is this artifact's instance of the
  corpus law, not a position-18 or sibling curiosity.
- Context 92 itself: MiniLM has no cidx 92 (6 contexts).
  In each blob, cidx 92 is an unremarkable context —
  0856a10c: ng 0, 928 actions, 18,302,104 B; 0a0d378c:
  ng 1, 280 actions, 3,288,696 B; 5ab3537d / 773470cd:
  ng 0, 752 actions, ~12,852,4xx B; 76c3a8ff: ng 0, 287
  actions, 3,447,232 B (the only context in its artifact
  with that action count, but its neighbours' counts are
  near-unique too); cc9b9d1c: ng 0, 259 actions,
  2,786,592 B. Every cidx 92 carries the standard burst
  head, the universal tail [(24,0),(24,1),(24,2),(24,0)],
  all 5 skeleton forms, and 50–57 bursts, like its
  neighbours 91/93. Nothing in its own segments marks
  it as an origin or boundary.

Verdict: scalar = cidx + C is MEASURED corpus-wide
(372 populations, slope exactly 1 everywhere); the
"-92" of AES-NUM-087 is 76c3a8ff's constant, not a
universal one. What sets each artifact's negative
constant, what distinguishes the C = +1 populations
from the C < 0 ones, and what any of it MEANS, are
NOT PROVEN.

## (ii) Cidx 113's schedule is a different multiset — neither permutation nor re-grouping

Against the consensus schedule (the per-position
(size, channel) pair unanimous among the other 25
sibling contexts, defined at 331 of 400 positions):

- Joint (size, channel) multiset on those 331 positions:
  symmetric difference 176 — NOT equal. Size-only
  symdiff 112, channel-only symdiff 28. So even the size
  vocabulary counts differ; it is not the consensus
  multiset rearranged, and not a channel relabelling.
- Against each other context in full: joint multiset
  equal to 0 of 25 (symdiffs 242–260; from position 41,
  212–230, equal 0 of 25). Total referenced bytes also
  differ: cidx 113 carries 6,434,744 B, the others
  6,416,880–6,434,800 B (113 is second-largest; only
  cidx 311, at 6,434,800 B, exceeds it, by 56 B).
- Re-grouping test (consecutive-sum boundary matching
  from position 41): 23 of 25 pairings match 0–2
  boundaries in 359 actions — the large actions are NOT
  consecutive re-groupings of one another. Two partial
  exceptions: cidx 302 (22 matched boundary groups) and
  cidx 311 (16), whose schedules are also the closest
  by symdiff (244/252 full, 214/222 from 41).

Verdict: MEASURED — cidx 113's schedule is a genuinely
different (size, channel) multiset built from a similar
size vocabulary, not a permutation and not a
re-grouping of the consensus or of any sibling. The
302/311 partial kinship is recorded for 4.89. Why the
first context is built differently remains NOT PROVEN.

## (iii) Each staircase +64 lives in the single inter-ff region before its threshold word

Rank-aligned diff of the two position-18 camps (43 ff
words each; region k = the bytes between ff word k-1
and ff word k):

- Per-region length differences (camp 21648 minus camp
  21392) are exactly +64 in FOUR regions and 0 in the
  other 40: the regions immediately preceding ff ranks
  2, 8, 22 and 26 — precisely the AES-NUM-086 threshold
  ranks. Region lengths: 472 -> 536 (rank 2), 488 ->
  552 (rank 8), 544 -> 608 (rank 22), 544 -> 608
  (rank 26). The cumulative +64/+128/+192/+256 offset
  drift of AES-NUM-086 is these four region insertions
  accumulating.
- The region immediately AFTER each carrying region is
  byte-identical between the camp representatives
  (188 B, 0 differing bytes, all four times): the
  insertion is confined to its one region.
- The carrying regions are constant within each camp
  (0 variable positions in both camps) but differ
  between camps across the overlap (106–107 differing
  bytes of 472–544, first difference at +132/+148/
  +204/+204). Camp 21648's extra 64 B tail in each
  carrying region begins with the SAME 32-byte pattern
  in all four regions (00000000 10570000 00800000
  00800802 88006c00 00001000 80000000 080080...),
  zero fraction 0.61–0.63, 12–13 distinct bytes.

Verdict: MEASURED — each +64 step is one 64 B longer
inter-ff region directly before its threshold ff word,
and the four longer tails open with an identical
32-byte pattern. Whether the four extra tails are
byte-identical in full, and what the insertion IS,
are NOT PROVEN (queued for 4.89).

## What this closes and what it queues

- MEASURED: the variable ff scalar is cidx + C in all
  372 scanned ff populations across all six blobs
  (slope exactly 1; C = +1 in 181 groups and one
  negative per-artifact constant in 191; sisters share
  -94). Context 92 is ordinary in every artifact that
  has one; MiniLM has none.
- MEASURED: cidx 113's schedule is a different multiset
  (not a permutation, not a re-grouping; totals differ;
  partial kinship with cidx 302/311 only).
- MEASURED: the staircase's four +64 insertions live
  one per inter-ff region, immediately before ff ranks
  2/8/22/26; each following region is byte-identical
  across camps; the four extra tails share a 32-byte
  opening pattern.
- NEXT (4.89): what distinguishes the C = +1 ff
  populations from the negative-C ones (network group,
  position, size, cidx range) and what sets each
  artifact's negative constant; the cidx 113 vs 302/311
  partial kinship (where their boundary matches sit);
  the four extra 64 B tails compared byte-for-byte
  (identical, shifted, or merely same-headed?).
  Host/artifact analysis only — no physical child.

## Evidence boundary

Host/artifact analysis only; no device child ran.
Grades: the counts, the cidx + C identities, the
multiset/boundary verdicts and the region anatomy are
MEASURED over the complete stated populations
(controls exact). Every meaning — why the first
context differs, what the constants encode, what the
insertions are — is NOT PROVEN and nothing here
invents one.
