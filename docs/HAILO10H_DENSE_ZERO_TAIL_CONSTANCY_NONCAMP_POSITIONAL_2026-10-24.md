# The lone DENSE zero at 28768 shares nothing with the SPARSE zeros but its centre word, the block tails are one constant per family in every segment, and the positional law holds on non-camp segment pairs (2026-10-24)

Roadmap Campaign 4 iteration, slice 4.101 (AES-NUM-101).
Populations: all seven corpus artifacts (MiniLM plus the
six hailo-ollama blobs), walked on Mimir with hef101.py
(sha256 0f0c62a87e05eb8136f3d72a5e0be6211d1c5019b5cf654fef4d6960b9827b22 —
the sha-verified hef100.py lineage with the 4.101 arms
appended; arms file hef101_arms.py sha256
34c5a175c0c355101b3d17d44df255ab6291f07daa2891c996a18cc6b4011115;
gz sha256 32800ab500a674da6e105719f24108622457ec97b80c6167b207a5005f9ae6d0
verified on-device before the run). Contract
docs/TASK_CONTRACT_4.101.md published @ f6ef8950 before
implementation. Output: /tmp/hef101_out.txt sha256
b75e649c41f5f5ed22c4976b4eb3cf2c8810cc7bd7d2c5c8b61e38111a51aa33
(372,251 B, 2,658 lines, DONE101 reached); the 4.101
arms section (116 lines) was read back in full from the
device. Controls reproduce AES-NUM-029/032...100
EXACTLY (128,787 pooled small actions; 79,001 pooled
24 B bursts; 745,849 pointer actions; 1,504 contexts;
trailing distinct (channel, operand) pairs 2,049;
champion-headed bursts 75,215), camps reproduce
(A 21392 x13, B 21648 x12), the whole non-common
re-collection matches the hef100 population exactly
(7,484 candidates; SPARSE 2,280/144 zero, MID 2,306/21,
DENSE 2,898/64), the ungrown positional aggregate
reproduces (36 regions, 4,392,812 tallies, 0 differing,
out-of-range 68,733,956), the reverse pooled result
reproduces (602 pairs, 131,360 tallies, 0 differing,
out-of-range 24,544 over 269 pairs), and the
AES-NUM-099 grown-middles positional test reproduces
with 0 differing triples.

## (i) The single DENSE zero at 28768

At offset 28768 the whole population holds exactly 3
candidates, and exactly one DENSE zero exists there
corpus-wide: group (0a0d378c, pos 16, size 32776),
cidx 5, mask 00000, value 0, neighbourhood tuple
(ff000000, ff000000, ff000000, ff000000, 01000600) —
four ff words in a row and a fifth word 01000600.
The two SPARSE candidates at the same offset are the
AES-NUM-100 pair restated with their instances: the
zero one is group (5ab3537d, 8, 32784), cidx 89, mask
10011, tuple (00000000, ff0f0000, ff000000, 00000000,
00000000); the non-zero counterpart is group
(0a0d378c, 20, 32688), cidx 140, mask 11011, value 15,
tuple (00000000, 00000000, ff0f0000, 00000000,
00000000).

The comparison is almost entirely negative. The DENSE
zero's word equals a SPARSE word at the offset at
exactly one of the five neighbourhood positions: the
centre (rel +0), where its ff000000 is the SPARSE
zero's centre word — the ff word at q itself, which
every candidate at q carries by construction up to its
value byte. At the other four positions its word is in
neither the SPARSE-zero value set nor the pooled
SPARSE value set at 28768. Its full tuple equals no
SPARSE tuple at the offset, zero or not. Its
(group, cidx) instance coincides with no SPARSE
candidate's instance at the offset, and its group is
among neither the SPARSE groups at 28768 nor the 11
SPARSE-zero groups at the 22 zero offsets — the
artifact 0a0d378c is shared with the non-zero SPARSE
counterpart's group, but the group (position 16, size
32776) is distinct from both SPARSE groups.

Wider placement: of the 64 DENSE zeros in the whole
population, exactly 1 sits at one of the 22 SPARSE-zero
offsets — this one. Inside its own group, however, it
is not isolated: the group carries 4 DENSE zeros, at
the consecutive aligned offsets 28760, 28764, 28768,
28772 — a run of four spaced 4 B apart, of which only
28768 is also a SPARSE-zero offset. No mechanism is
credited: NOT PROVEN. The DENSE zero's only measured
kinship with the SPARSE zeros at its offset is the
centre ff word every candidate there shares.

## (ii) Label byte0 vs the block words beyond the heads

The tail words (positions 4..6 of every unit; family 0
24 slots, families 1/2 27 slots each) turn out to carry
no per-segment information at all. In every one of the
25 camp segments, in both camps, each family's tail
population is a single constant word: family 0 tails
are 00000000 at all 24 slots, family 1 tails are
00020000 at all 27 slots, family 2 tails are 00000000
at all 27 slots — per (camp, family) exactly 1 distinct
tail word, shared by every segment. The block's tails
are as rigid as its family-0 heads.

Every hunt against them therefore comes back empty,
and stronger than empty: a label word occurs verbatim
in its own family's tails, in the other family's
tails, and in all 78 non-head block words in 0 of 25
segments for both families and every scope. Slot-exact
tests (324 (scope, slot, byte) tests per family,
including the full-word form) give 0 hits. As-function
and affine tests of label byte0 against every
same-family tail byte (27 slots x 4 bytes, per camp and
pooled) give 0 hits of any kind — not even degenerate
ones: every candidate X is a constant in scope, and a
function of a constant can only be constant, while
label byte0 varies (25 distinct pooled), so no mapping
exists at all. The tails cannot encode the labels,
because the tails do not vary. What the labels encode
remains NOT PROVEN; the in-block source list is now
exhausted except the head slots themselves (the two
labels and the constant family-0 head ffffff7f).

## (iii) Positional law on non-camp segment pairs

The full census-vs-prediction test (shift window
-128..+128, AES-NUM-100 ungrown method) was run on two
pairs of individual segments, not consensus camps.
Cross-camp A0 x B0 (camp A segidx 0, cidx 130, length
21392; camp B segidx 0, cidx 121, length 21648):
7,021 ordered pairs with >= 1 tally, 5,489,488
tallies, differing triples 0, out-of-range position
pairs 457,604,528 over 22,548 ordered pairs.
Within-camp A0 x A1 (cidx 130 x cidx 139, both length
21392): 6,996 ordered pairs, 5,481,232 tallies,
differing triples 0, out-of-range 452,136,432 over
22,354 ordered pairs. The positional law is EXACT on
both pairs: it is not a property of the camps, their
consensus strings, or the grown middles, but of the
lag census's position arithmetic on arbitrary segment
pairs of this corpus.

## Verdict

(i) The single DENSE zero at 28768 (group 0a0d378c
pos 16, cidx 5) shares with the SPARSE zeros at its
offset only the centre ff word common to all
candidates there; tuple, instance, group and the
other four neighbourhood words are all disjoint.
Form-exclusivity's single break is a coincidence of
offset, not of structure — measured, mechanism NOT
PROVEN. Its own group holds a run of four DENSE zeros
at 28760..28772.
(ii) The block tails are one constant word per family
in all 25 segments (fam0 00000000, fam1 00020000,
fam2 00000000); no verbatim, slot-exact, as-function
or affine reading of the family labels from any tail
byte exists — the tails do not vary. Label identity
NOT PROVEN; the block beyond the heads is closed as a
label source.
(iii) The positional law holds exactly on non-camp
segment pairs, cross-camp and within-camp (0 differing
triples on 5,489,488 and 5,481,232 tallies).

NEXT: slice 4.102 — the DENSE-zero run of four at
28760..28772 in group (0a0d378c, 16, 32776) (the other
three zeros' masks, values and neighbourhoods; whether
the run is an ff-word run in its segment); the
whole-block per-segment variation census (which of the
182 block offsets vary across a camp's segments at
all); positional-law completion pairs (B0 x A0
reverse, B0 x B1 within-camp B). Host/artifact analysis
only — no physical child.
