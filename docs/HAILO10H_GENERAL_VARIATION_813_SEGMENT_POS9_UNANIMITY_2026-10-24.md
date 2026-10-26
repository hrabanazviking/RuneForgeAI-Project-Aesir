# AES-NUM-111 — cidx 44's distinctness outside its cell is general variation, never singleton-vs-many (all 31 outside events are all-distinct populations; the only 2 singleton-vs-shared-partner events in the whole profile are the mixed cell's own 2 offsets); the 813-reference segment is cc9b9d1c's ONLY size-304 segment, a 76-word segment whose entire rare-class membership rests on a single fd000000 word, referenced exactly 3 times by every one of the 271 contexts in a consecutive (pos,0),(pos+1,1),(pos+2,2) triple whose start position varies (4–10) with no stream period; heavy cc9 contexts are heavy only in the wider rare pool — the 182 exactly-3 contexts reference the 813 segment and nothing else in the class; and cidx 95's one non-distinct offset (11608, in 773470cd's pos-9 group) is a group-wide unanimity offset where all 8 instances share one neighbourhood, while the same group in 5ab3537d has 25 instances (cidx 95 not among them) and no common offset because its candidate grids split into sub-families sharing only 26 offsets and one instance (cidx 208) on a wholly disjoint grid

Slice 4.111, worked under `docs/TASK_CONTRACT_4.111.md`
(contract committed first @ 79509b43). Host/artifact
analysis only, on Mimir (purpleviking1) — no physical
child, no device run of any kind.

## Run and transfer record

hef111.py was built locally (hef110 lineage: hef110.py
with its final `print('DONE110')` replaced by the
4.111 arms, hef111_arms.py; arms sha256 693dd1c7…,
script sha256 c4440231…, gz sha256 92133e60…,
saved:53323 on the proxy upload). The one-shot
receiver landed on Mimir via file.write (recv111.py,
sha256 683d6884… verified identical on both sides),
the gz was proxy-uploaded through the tunnel proxy
while the receiver ran foreground on-device, gz and
script sha256 were verified on-device and py_compile
passed before the run. The script ran detached over
the 7-artifact corpus to DONE111 at line 10,855,
output 1,473,699 B, sha256 2200a472… (retrieved
gz sha256 2855a002… verified identical both sides).

## Controls

All controls reproduce exactly: 128,787 small actions;
79,001 bursts; 745,849 pointer actions; 1,504 contexts;
2,049 trailing pairs; 75,215 champion bursts. The
inherited DONE markers stand at the same lines as in
the AES-NUM-110 run (DONE105 at line 3,576, DONE106
at 3,670, DONE107 at 3,701, DONE108 at 3,910) — the
whole hef lineage stands behind every number below.
Arm-level controls also reproduce exactly: cidx 44
analysable offsets 295 with 33 distinct-from-all
(AES-NUM-110); the cc9 rare-containing union is 929
segments with per-word sets fd 569 / e9 170 / f6 497
(AES-NUM-108/109); the top size-304 segment carries
813 references; heavy contexts 36 and exactly-3
contexts 182 (AES-NUM-110); the 773470cd pos-9 group
holds 8 instances with 10 common offsets
(AES-NUM-110).

## (i) Cidx 44's distinctness events outside its cell

The 33 distinct-from-all offsets of AES-NUM-110 split
by (pos, size) as {(12, 32776): 3, (13, 22704): 9,
(16, 32584): 6, (20, 32752): 2, (21, 18608): 5,
(25, 13712): 7, (30, 1136): 1}. The 2 pos-20 events
are the mixed cell's own two offsets (13664, 17344).
Every event was enumerated pair by pair — full
neighbourhood partition, eq distributions against
cidx 44 and over all pairs, form/zero profiles, and
whether cidx 44's own neighbourhood recurs at any
other analysable offset.

Classification over all 33 events:

- singleton-vs-shared-partners (cidx 44 alone against
  one shared partner neighbourhood): exactly 2 — the
  mixed cell's own two offsets, and no others.
- general-variation-all-distinct: 31 — ALL of the
  outside-cell events, without exception.

In a general-variation event the partner population
is not shared at all: the number of instances standing
alone in their own neighbourhood is 7–15 per event
(distribution over the 31 events {7: 6, 9: 1, 13: 9,
14: 7, 15: 8} singletons, counting cidx 44), with
14–15 distinct neighbourhoods among 15 instances in
the fullest groups. Cidx 44 is one lone instance
among many: at pos 12 size 32776 offset 12752, for
example, all 15 instances are mutually distinct
(15 neighbourhoods; eq-vs-cidx-44 {1: 1, 4: 13},
all-pairs eq {1: 14, 4: 91}), the neighbourhoods
forming a ladder that differs essentially in the
centre ff-word's value byte (ff05, ff09, ff0d, …
stepping by 4) — every instance carries its own
value, so every instance is "distinct". Cidx 44's
own neighbourhood recurs at exactly 1 analysable
offset in these events — itself.

Verdict: outside its cell, cidx 44's distinctness
is NEVER the singleton phenomenon of AES-NUM-109/110.
It is the ordinary background of general variation,
in which most or all instances at an offset are
mutually distinct and cidx 44 happens to be one of
them. The singleton-vs-unanimous-many structure
remains confined to the mixed cell's group, now
proven from the event side as well as the profile
side.

## (ii) The 813-reference segment, its rotation, and heavy vs exactly-3 contexts

Identity: cc9b9d1c contains exactly ONE distinct
referenced size-304 segment — offset 0, size 304 —
and it is the 813 segment. There are no ordinary
size-304 segments to compare it against: the
multiplicity distribution over size-304 segments is
{813: 1}, and the segment is in the rare-containing
union (1 in union, 0 not).

Anatomy (304 bytes = 76 words): 59 distinct words,
17 all-zero words (including a run of 13 consecutive
zero words at word indices 62–74, near the tail),
exactly 1 ff-word (ff000000). Its rare-word contents
are a SINGLE fd000000 at word index 20 (byte offset
80) — e9ff0000 count 0, f6000000 count 0. The
segment's membership in the 929 class therefore
rests on one word. The remaining words are a
structured population of small-value words
(0000002e, 01000000 ×2, 0f/10/f0/02/f1/11/fe/0e/1f/
f2/12/ef/03/20…000000-style values, and one
non-trivial word 562e3400 at word index 75, the
last word). What the segment IS remains NOT PROVEN.

Referencing law: all 271 cc9 contexts reference it
exactly 3 times — the per-context distribution is
{3: 271}, with zero contexts at any other count.
Within a context the three references are always a
consecutive triple (pos, ch 0), (pos+1, ch 1),
(pos+2, ch 2). Across the 271 contexts only 7
distinct triple sequences occur: starts at pos 7
(×83), 8 (×56), 5 (×47), 9 (×44), 6 (×31), 10 (×9),
4 (×1) — start positions 4–10, i.e. the triple sits
in the head region but its start is not fixed. In
stream order the (pos, channel) sequence has NO
exact period ≤ 64, and sequence-index mod k does
not determine (pos, channel) for k ∈ {3, 4, 6, 8,
9, 12}: the rotation is a per-context placement,
not a stream-level cycle. The dominant transitions
are the within-triple steps (7,0)→(8,1) and
(8,1)→(9,2) (×83 each); between contexts the
sequence resets to a channel-0 head position.

Heavy vs exactly-3 contexts — the picture inverts
the naive reading of AES-NUM-110's bimodality:

- The 182 exactly-3 contexts: their 3 class
  references are EXACTLY the 813 segment's triple,
  and nothing else. Distinct class segments
  referenced: 1. Sizes {304: 546}; channels exactly
  {0: 182, 1: 182, 2: 182}; per-word referencing
  footprint fd 546 / e9 0 / f6 0 (the 546 = 182 × 3
  all land on segments whose class membership comes
  through the fd word — here, the single fd word of
  the 813 segment). Mean total acts 425.9
  (min 186, max 842).
- The 36 heavy contexts (21–48 class refs): each
  ALSO references the 813 segment exactly 3 times
  (n813-per-context distribution {3: 36}) — heaviness
  is never more 813 references. The excess is the
  wider rare pool: 1,071 class references in total,
  856 distinct class segments beyond (and including
  counts beyond) the 813 segment, dominated by size
  32784 (573 refs), then 17936 (130), 14864 (106),
  2576 (68), 3856 (68), 304 (108 = the 813 triples),
  18320 (18). Per-word footprints fd 710 / e9 189 /
  f6 528 — heavy contexts are the ones that touch
  the e9- and f6-carrying segments at all. Beyond-813
  segments are referenced at most twice per context.
  Mean total acts 787.0 (min 626, max 874) — heavy
  contexts are also simply larger contexts.

Verdict: the cc9 class's pointing structure is a
universal constant (one segment, one fd word,
exactly one channel-rotating triple per context)
plus a heavy-context phenomenon that lives entirely
in the wider rare pool. The exactly-3 contexts are
the pure form: the universal triple and nothing else.

## (iii) Cidx 95's non-distinct offset, and the sister pos-9 asymmetry

773470cd pos-9/size-32784 group: 8 instances
[95, 103, 107, 111, 115, 119, 123, 127], 10 common
offsets [7232, 7304, 7376, 7448, 7520, 7592, 7664,
7724, 7736, 11608]. At 8 of the 10 offsets cidx 95
is the singleton in a two-neighbourhood split
(partner neighbourhood sizes [7, 1]) with eq 3
against every partner (SPARSE, 3 zero words); at
7724 the distance is eq 2 (MID, 2 zeros). At the
remaining offset the structure collapses entirely:

- Offset 11608 is a UNANIMITY offset: all 8
  instances share ONE neighbourhood —
  00000000 / 01000000 / ff010000 / 00000000 /
  000e0000 (MID, 2 zero words) — a single partition
  cell of size 8. Cidx 95 fully agrees (eq 5) with
  ALL 7 partners; indeed all 28 pairs in the group
  are eq 5 with 0 differing bytes. The
  non-distinctness is not a property of cidx 95:
  at 11608 NO instance is distinct. (The centre
  word ff010000 is the value-1 ff-word — the lowest
  rung of the value ladder seen in arm (i).)

The same group in 5ab3537d — why no common offset:
the group there holds 25 instances
[103, 111, 115, …, 208] — cidx 95 is NOT a member
of this group in 5ab3537d at all — and the
candidate-offset structure splits:

- Instances 103–127 carry ~94–95 candidate offsets
  on one grid (the 7232-family grid, plus 11608 and
  a shared tail); their mutual intersection is 94.
- Instances 135–203 carry 94 candidates on a
  SHIFTED grid (7252-family); pairwise they share
  94 with each other but only 26 offsets with the
  first sub-family (7192, 7220, 7236, 7264, 7292,
  7308, 7336, 7364, 7380, 7408, 7436, 745-two, …,
  7724, 7740, 11608 — 11608 is among the 26).
- Instance 208 carries 159 candidate offsets on a
  wholly different grid (8728 upward, step 4) and
  shares 0 offsets with every other instance.

The sequential intersection therefore runs
95 → 94 (first sub-family) → 26 (after cidx 135)
→ 0 (after cidx 208). Offset frequency across the
25 instances is {1: 165, 6: 68, 18: 68, 24: 26} —
26 offsets occur in 24 of 25 instances, but none
occurs in all 25; the union is 327 offsets. So the
absence of a common offset in 5ab3537d is a
population fact (a bigger, split group with one
off-grid member), NOT the absence of shared
structure: near-common offsets exist (24/25), and
11608 — the unanimity offset in the sister — is
shared by both sub-families here.

Verdict: cidx 95's one agreement offset is a
group-wide constant neighbourhood (value-1 centre)
at which the singleton structure switches off for
everyone; and the sister asymmetry is explained —
773470cd's pos-9 group is a single tight population
of 8 on one grid, 5ab3537d's is a split population
of 25 whose grids never all intersect.

## Grades

- Cidx 44 outside-cell distinctness: all 31 events
  general variation (7–15 singleton neighbourhoods
  per event, partners mutually distinct, centre
  ff-word value ladder); singleton-vs-shared-partners
  occurs at exactly the mixed cell's own 2 offsets
  in the entire 295-offset profile: MEASURED.
- The 813 segment: cc9's only size-304 segment
  (offset 0); 76 words, 59 distinct, 17 zero words,
  1 ff-word; rare contents = exactly one fd000000
  (word 20), no e9, no f6: MEASURED.
- Referencing law: exactly 3 references from every
  one of the 271 contexts, always a consecutive
  (pos,0),(pos+1,1),(pos+2,2) triple; 7 start
  positions (4–10, mode 7 ×83); no stream period
  ≤64 and no mod-k determinism (k ∈ {3,4,6,8,9,12}):
  MEASURED.
- Heavy vs exactly-3: exactly-3 contexts reference
  the 813 segment ONLY (1 distinct class segment,
  channels exactly 182/182/182, fd-only footprint);
  heavy contexts add the wider pool (856 distinct
  class segments, size 32784 dominant, e9/f6
  footprints nonzero) on top of the same universal
  triple, and are larger contexts (mean acts 787
  vs 426): MEASURED.
- Cidx 95 @11608: unanimity offset — one
  neighbourhood shared by all 8 instances, all 28
  pairs eq 5, centre ff010000: MEASURED. At the
  other 9 offsets the [7,1] singleton split holds
  (eq 3 ×8, eq 2 ×1): MEASURED.
- 5ab3537d pos-9 asymmetry: 25 instances, cidx 95
  not a member; two sub-family grids sharing 26
  offsets; cidx 208 on a disjoint grid (0 shared
  with all); max offset frequency 24/25, 26 offsets
  at 24: MEASURED.
- What the 813 segment is, why cidx 44's cell and
  cidx 95 are singletons in their home groups, and
  what determines the 813 triple's start position
  per context: NOT PROVEN.

## Next (slice 4.112)

(i) The centre ff-word value ladder as a population:
in the general-variation groups, is the per-instance
centre value a strict function of instance index
(the 12752 ladder stepped by 4 in cidx order), and
does the unanimity value ff010000 sit at its base?
(ii) The 813 triple's start position: is start pos
a function of the referencing context (its size,
its ng, its own index mod something wider than the
tested k, or the position of the context's other
head actions)? (iii) 11608-class unanimity offsets
across the corpus: how many (group, offset) cells
are unanimous, and do they share the value-1 centre
pattern? Host/artifact analysis only — no
physical child.
