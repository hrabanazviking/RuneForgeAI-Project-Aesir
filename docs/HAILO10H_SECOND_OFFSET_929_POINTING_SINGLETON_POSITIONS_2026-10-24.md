# AES-NUM-110 — cidx 44 is the singleton again at the mixed cell's second common offset (13664), but at distance eq 1, not 0, and its singleton status is confined to that one group (distinct at only 33 of 295 analysable offsets elsewhere, fully agreeing with a partner at 262); the cc9 929 are pointed at by every cc9 context, with 43.8% of their references landing on a single 304-byte segment referenced 813 times at head positions 5–12; and the cidx-95 singleton's distances 2/0/2/1 are carried by fixed position sets (the centre and −4 words differ at all four offsets, the agreeing positions are always zero words, no position is ever mixed), while its cross-group test is vacuous in 5ab3537d (no second analysable group) and near-total but not absolute in 773470cd (distinct at 13 of 14 offsets, one full-agreement offset in the pos-9 group)

Slice 4.110, worked under `docs/TASK_CONTRACT_4.110.md`
(contract committed first @ bcdf0d43). Host/artifact
analysis only, on Mimir (purpleviking1) — no physical
child, no device run of any kind.

## Run and transfer record

hef110.py was built locally (hef109 lineage: hef109.py
with its final `print('DONE109')` replaced by the
4.110 arms, hef110_arms.py; arms sha256 e2966a00…,
script sha256 372fdba3…, gz sha256 8f0f5e9d…,
saved:48418 on the proxy upload). The one-shot
receiver landed on Mimir via file.write (recv110.py,
sha256 c1239c29… verified identical on both sides),
the gz was proxy-uploaded through the tunnel proxy,
gz and script sha256 were verified on-device and
py_compile passed before the run. The script ran
detached over the 7-artifact corpus to DONE110 at
line 10,260, output 1,309,054 B, sha256 b420b5d7….

## Controls

All controls reproduce exactly: 128,787 small actions;
79,001 bursts; 745,849 pointer actions; 1,504 contexts;
2,049 trailing pairs; 75,215 champion bursts. The
inherited DONE markers stand at the same lines as in
the AES-NUM-109 run (DONE105 at line 3,576, DONE106
at 3,670, DONE107 at 3,701, DONE108 at 3,910) — the
whole hef lineage stands behind every number below.
Arm-level controls also reproduce exactly: the mixed
cell holds 7 instances with common offsets
[13664, 17344] (AES-NUM-109), and the cc9 rare-
containing union is 929 segments with per-word sets
fd 569 / e9 170 / f6 497 (AES-NUM-108/109).

## (i) The mixed cell's second common offset, and cidx 44 elsewhere

The cell (group 0a0d378c pos 20 size 32752) has
exactly two common offsets: 17344 (AES-NUM-109) and
13664. At 13664 the structure is the same
two-neighbourhood split, read at a different
distance:

- cidx 44 alone: 01000a00 / 4801a200 / ff2d0000 /
  00000000 / 01000a00 (DENSE, 1 zero word).
- The other six instances, byte-identical to each
  other: 00000000 / 03000000 / ff0f0000 / 00000000 /
  00100000 (MID, 2 zero words).

All 21 pairs enumerated: the 6 cross pairs
(44 × each other) have eq 1, differing in exactly
9 bytes, per-position (2, 3, 1, 0, 3) in all six —
the one agreeing position is position 3 (+4), where
both neighbourhoods carry the all-zero word. The 15
within-six pairs are identical (eq 5). So cidx 44
IS the singleton again at the second offset —
same neighbourhood identity, same singleton-vs-six
structure — but total disagreement is NOT repeated:
the distance is eq 1, not eq 0. And the separator
picture inverts relative to @17344: here form DOES
separate (DENSE vs MID) and the zero-count pair is
(1, 2), where at @17344 both sides were DENSE with
zero pair (0, 1). What is common to both offsets is
the identity split itself, nothing else.

Cross-group profile of cidx 44 in 0a0d378c: 321
groups contain it, but only 11 admit the common-
offset test at all (298 groups have no common
offset, 12 are single-instance for cidx 44's key).
Over the 295 analysable offsets in those 11 groups:

- distinct from all partners at 33 offsets (11.2%);
- form unique at 1 offset, zero-count unique at 2;
- the two-neighbourhood singleton pattern (44 alone
  against one shared partner neighbourhood) occurs
  at exactly 2 offsets — both are the mixed cell's
  own two offsets, in its own group (pos 20);
- any full agreement (eq 5 against some partner) at
  262 of 295 offsets (88.8%);
- the eq-vs-partner distribution over 3,750
  partner-offset pairs is {0: 6, 1: 9, 3: 4, 4: 360,
  5: 3,371} — the only 6 eq-0 pairs in cidx 44's
  entire cross-group profile are the six @17344
  pairs of the mixed cell.

Verdict: the @17344 singleton is NOT the same kind
of instance elsewhere. Cidx 44's singleton status
is confined to the mixed cell's group: at the
cell's second offset it is the same singleton at a
smaller distance (eq 1), and in every other
analysable group it is an ordinary instance that
usually agrees fully with its partners. Distinct-
ness events do occur elsewhere (33 offsets, in the
pos 12/13/16/21/25/30 groups) but never with the
singleton-vs-unanimous-many structure, and never
with form or zero-count uniqueness (1 and 2
offsets of 295).

## (ii) The cc9b9d1c 929's referencing-action profile

cc9b9d1c holds 271 contexts and 137,800 pointer
references in total. The 929 rare-containing
segments receive 1,855 of them (1.35%).

Contexts: EVERY one of the 271 cc9 contexts
references the class — the class's pointing reach
is universal, not confined to a context subset.
The per-context counts are bimodal: 182 contexts
reference it exactly 3 times, most of the rest
4–8 times, and a heavy tail of 36 contexts
references it 21–48 times. The top 10 contexts
carry 395 references (21.3%) and the top 50 carry
1,153 (62.2%). All three words are not pointed at
alike: fd-containing segments are referenced 1,465
times from all 271 contexts, f6-containing 559
times from 60 contexts, e9-containing only 191
times from 24 contexts.

The dominant single fact is one segment: a single
size-304 segment is referenced 813 times — 43.8%
of all class references — and ALL 813 size-304
references in cc9b9d1c point at class segments
(size 304's share of class references is 43.8%
against 0.59% of all cc9 references, a 74.3x
ratio). Its references sit at head positions 5–12
in rotating (position, size, channel) triples —
(7,304,0), (8,304,1), (9,304,2) ×83, then the same
rotation at (8..10), (5..7), (9..11), (6..8),
(10..12) with counts 56/47/44/31/9 — so positions
5–12 together hold 812 of the 1,855 class
references, at 13–50x their all-reference share,
and that head concentration IS this one segment's
referencing pattern.

The other 928 class segments receive the remaining
1,042 references: 814 class segments are referenced
exactly once and 114 exactly twice; the class's
mean references-per-segment is 2.00 against the
census's 1.22, and the entire excess is the single
813 segment (the class and census maxima coincide
at 813 — the same segment). By size, after 304
(813 refs) come 32784 (612 refs, ratio 1.34x),
17936 (130, 3.35x), 14864 (106, 2.73x), 3856 (77,
0.62x — under-represented from the pointing side
despite its content-side presence) and 2576 (68,
14.6x); the remaining five sizes hold 2–18
references each. By channel the class is only
mildly distinguished: shares {0: 35.4%, 1: 29.6%,
2: 34.9%} against all cc9 references {0: 38.9%,
1: 31.4%, 2: 29.7%} — a small channel-2 tilt, no
channel law. The network-group split is even
(923/932). The class occupies 934 distinct
(pos, size, channel) triples of cc9's 44,739.

Verdict: the class IS distinguished from the
pointing side, but the distinction is concentrated,
not diffuse: universal context reach (271/271),
one universally-referenced 304-byte segment
carrying 43.8% of the class's references at fixed
head positions, and a heavy-context tail — while
channel and network group barely separate it, and
the remaining 928 segments are pointed at almost
exactly like ordinary segments (once or twice
each).

## (iii) The cidx-95 singleton's differing positions, and its cross-group profile

Both sister groups (5ab3537d and 773470cd, pos 21
size 32776) agree on every number in the per-offset
arm, line for line, as in AES-NUM-109. Positions
are indexed 0–4 for the neighbourhood words at
relative offsets −8, −4, 0, +4, +8. At every offset
the singleton's eq against each partner is the
single AES-NUM-109 value (2/0/2/1), and NO position
is ever mixed: each position is either equal to all
9 partners or different from all 9.

- @11136 (eq 2): differing positions [1, 2, 4];
  equal positions [0, 3] — both all-zero words.
  Differing bytes summed over partners: position 1
  18 (03000000 vs ff0f0000), position 2 (centre) 9
  (ff010000 vs ff050000, the value byte only),
  position 4 9 (000e0000 vs 00000000).
- @17272 (eq 0): ALL FIVE positions differ from
  all partners. The centre position 2 carries 9
  distinct partner words (each partner's own
  ff-word; singleton ff0f0000 differs from each by
  1 byte); position 1 is the heaviest (36 differing
  bytes over partners, 00000000 vs 1c01b180);
  positions 0 and 4 carry 18 each against a
  two-variant partner population (modal 01001c00
  ×8 plus one variant).
- @20300 (eq 2): differing positions [0, 1, 2];
  equal positions [3, 4] — both all-zero words.
  Position 0 is the heaviest here (27 differing
  bytes: 00b08800 vs ff0f0000).
- @32192 (eq 1): differing positions [0, 1, 2, 4];
  the only equal position is [3] (+4, all-zero in
  both). Centre position 2 again carries 9 distinct
  partner words (ff0b0000 vs each partner's own).

So the distances decompose as: the centre word
(position 2, the ff-word at the common offset
itself) and the −4 word (position 1) differ at ALL
FOUR offsets; position 4 differs at three; position
0 at two; position 3 (+4) differs only at @17272.
Every agreeing position, at every offset, is an
all-zero word on both sides — agreement is carried
entirely by shared zero words, and disagreement by
the structured words. Total disagreement (@17272)
is the one offset where even the +4 word is
non-zero in the singleton (01000000).

Cross-group profile of cidx 95: 233 groups contain
it in each sister artifact, but the analysable
universe differs sharply between the sisters.

- 5ab3537d: only ONE group admits the test — its
  own pos-21 group (165 groups have no common
  offset, 67 are single-instance). Within that one
  group it is distinct/form-unique/zero-unique at
  4/4 offsets (AES-NUM-109). The cross-group
  question is therefore VACUOUS in 5ab3537d beyond
  its own group: no other group can be tested, so
  "unique elsewhere" is NOT PROVEN there — not
  confirmed, not refuted; untestable.
- 773470cd: TWO groups admit the test (162
  no-common, 69 single-instance). In the second
  group (pos 9, size 32784, 8 instances, 10 common
  offsets) cidx 95 is distinct from all partners at
  9 of 10 offsets, form-unique and zero-unique at
  8 of 10, a two-neighbourhood singleton at 9 of
  10 — but at 1 offset it is NOT distinct, and it
  holds eq 5 against 7 partner-offset pairs there
  (that group's eq distribution against it is
  {2: 7, 3: 56, 5: 7}). Combined over both groups:
  distinct 13/14, form-unique 12/14, zero-unique
  12/14, total disagreement only in its own group
  @17272 (the only 9 eq-0 pairs).

Verdict: where a second group can be tested at
all, the singleton is ALMOST the same kind of
instance — singleton-like at 9 of 10 offsets — but
not absolutely: one offset of full agreement
exists in 773470cd's pos-9 group, and in
5ab3537d the question has no second test case.

## Grades

- Mixed cell @13664: cidx 44 singleton again
  (two neighbourhoods, identity split identical to
  @17344), distance eq 1 via the shared +4 zero
  word, form and zero pair separating here where
  they did not at @17344: MEASURED.
- Cidx 44 cross-group: singleton status confined
  to the mixed cell's group (two-neighbourhood
  singleton pattern at exactly its own 2 offsets;
  distinct 33/295, form-unique 1/295, any-eq5
  262/295; all 6 of its eq-0 partner pairs are the
  @17344 pairs): MEASURED, over the 11 analysable
  groups of 321.
- cc9 929 referencing profile: universal context
  reach (271/271), one 304-byte segment at 813
  references (43.8% of the class; 100% of cc9's
  size-304 references) at head positions 5–12 in
  rotating (pos, channel) triples, heavy-context
  tail (top 50 contexts = 62.2%), channels and
  network groups near-undistinguished, remaining
  928 segments referenced once/twice like ordinary
  segments: MEASURED.
- Cidx 95 per-offset positions: distances 2/0/2/1
  carried by fixed position sets ([1,2,4] / all /
  [0,1,2] / [0,1,2,4]); centre and −4 positions
  differ at all four offsets; every agreeing
  position is a shared zero word; no mixed
  position at any offset, in either sister:
  MEASURED.
- Cidx 95 cross-group: in 773470cd, singleton-like
  in the one other testable group (distinct 9/10,
  one full-agreement offset): MEASURED. In
  5ab3537d, uniqueness beyond its own group:
  NOT PROVEN — no second group admits the test.
- Why cidx 44 and cidx 95 are singletons in their
  home cells, and what the 813-reference 304-byte
  segment is: NOT PROVEN.

## Next (slice 4.111)

(i) The distinctness events of cidx 44 outside its
cell (33 offsets in the pos 12/13/16/21/25/30
groups): are they singleton-vs-many splits or
general variation — does any other instance stand
alone there, and how do the partner populations
split? (ii) The 813-reference segment's own anatomy
(its rare-word contents and counts) and its
rotating (position, channel) referencing law in
full; plus the heavy cc9 contexts (21–48 class
references) vs the 182 exactly-3 contexts — which
segments and sizes make a context heavy? (iii) The
one non-distinct offset of cidx 95 in 773470cd's
pos-9 group, pair by pair; and the sister asymmetry
itself — the same pos-9/size-32784 group in
5ab3537d: its instances and why it admits no common
offset there. Host/artifact analysis only — no
physical child.
