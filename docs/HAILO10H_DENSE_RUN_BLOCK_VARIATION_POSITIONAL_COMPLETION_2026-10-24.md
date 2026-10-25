# The DENSE-zero run of four is a raw ff-word run — and one of fifteen such runs; block variation is exactly the two family labels and nothing else; the positional law completes its segment-pair square (2026-10-24)

Roadmap Campaign 4 iteration, slice 4.102 (AES-NUM-102).
Populations: all seven corpus artifacts (MiniLM plus the
six hailo-ollama blobs), walked on Mimir with hef102.py
(sha256 2a37f0e39d4a232bf4868f527618c1ca7df5343b80b880504c3352827ae95d45 —
the sha-verified hef101.py lineage with the 4.102 arms
appended; arms file hef102_arms.py sha256
fc021eb41a6aabf0d7e4c8901984a853b0f4c7a84a3db15c4b324724e7816c5d;
gz sha256 4172e9c132e5f1d5d57627d0845c2a5095682a9900ce6fda58eedd06695f36ec
verified on-device before the run, script sha verified
on-device, py_compile OK). Contract
docs/TASK_CONTRACT_4.102.md published @ 560a3963 before
implementation. Output: /tmp/hef102_out.txt sha256
9ddb4e07754d954e63a098cfaec2d9526bb7110ddb49d5ecd210928d35f02b8e
(413,732 B, 2,892 lines, EXIT 0, DONE102 reached),
retrieved byte-complete (gz sha256
cd719abe0465795ef681c205b1a659e700a0dd2a3d16edd474ce73219a61669b
identical on device and VM). Controls reproduce
AES-NUM-029/032...101 EXACTLY (128,787 pooled small
actions; 79,001 pooled 24 B bursts; 745,849 pointer
actions; 1,504 contexts; trailing distinct (channel,
operand) pairs 2,049; champion-headed bursts 75,215),
camps reproduce (A 21392 x13, B 21648 x12), trains
reproduce (52; 28/13/11; D113 249; firsts' D 3,089;
control D 176), and the whole non-common re-collection
matches the hef100/101 population exactly (7,484
candidates; SPARSE 2,280/144 zero, MID 2,306/21,
DENSE 2,898/64).

## (i) The DENSE-zero run of four at 28760..28772

The run is exactly as AES-NUM-101 measured, and it is
one instance's raw word run. Group (0a0d378c, pos 16,
size 32776) carries exactly 4 DENSE zeros, at offsets
28760, 28764, 28768, 28772 — all four in the SAME
instance (cidx 5), all mask 00000, all value 0,
spacings exactly 4, 4, 4. A targeted re-collection of
that group at every aligned offset 28752..28780 finds
exactly those 4 candidates and no others: within the
window the group has no candidate below 28760 or above
28772 at all.

The run instance's own segment words (cidx 5, offsets
28744..28788 step 4) settle what the run IS: the words
at 28760, 28764, 28768, 28772 are four consecutive
ff000000 words, flanked below by 9000a280 (28756) and
04000600 (28752) and above by 01000600 (28776) and
b800a280 (28780); further out sit 01000101 x2 below
(28744/28748) and 02000000, then a single 00000000
word, above (28784/28788). The four neighbourhood
tuples are the sliding windows of that one ff-run:
(04000600, 9000a280, ff, ff, ff), (9000a280, ff, ff,
ff, ff), (ff, ff, ff, ff, 01000600), (ff, ff, ff,
01000600, b800a280). A value-0 candidate's centre word
is ff000000 by construction, so a run of DENSE zeros
spaced 4 apart is exactly a run of ff000000 words
whose every length-5 window carries at most one zero
word (DENSE z <= 1) — here z = 0 throughout, because
the ff-run's neighbours are not zero words either.

The corpus census then removes any temptation to call
this run special. Over the whole population's 64
DENSE zeros there are 15 maximal runs of >= 2 zeros
spaced exactly 4 apart at group level — and the
(group, cidx) census is IDENTICAL (15 runs, same
offsets): every run lives inside a single instance.
14 of the 15 runs have length exactly 4; the remaining
one has length 3 ((0a0d378c, 20, 32752), cidx 44,
offsets 17348..17356 — the same offsets where its
sister group (0a0d378c, 20, 32688), cidx 8, carries a
length-4 run starting one word earlier, at 17344).
So 59 of the 64 DENSE zeros sit in runs (14 x 4 + 3);
only 5 are singletons at this spacing. The runs recur
across sister groups (12976..12988 and 13472..13484
appear in both 0a0d378c pos-20 groups) and across
artifacts (27640..27652 in both 5ab3537d and
773470cd; MiniLM carries two, at 19512..19524 and
26840..26852, both cidx 3). The 28760..28772 run is
the typical form of a DENSE zero, not an exception:
DENSE zeros come in ff-word runs of (almost always)
exactly four. What selects the run sites is NOT
PROVEN.

## (ii) Whole-block per-segment variation census

The block (aligned span 6184..6912, 182 aligned words)
was read in every individual camp segment — 13 of camp
A, 12 of camp B — and each of the 182 word indices was
tested for variation across a camp's segments. The
result is total and identical in both camps and in the
pooled 25 segments: exactly 110 indices are constant
(1 distinct word) and exactly 72 vary. The per-camp
figure MATCHES the AES-NUM-098 reading of 110/182
unanimous block offsets exactly, at the finer
individual-segment population — no reconciliation gap.

The breakdown has no remainder. Family 0: all 56
indices constant (32 head + 24 tail). Tails of all
three families: all 78 indices constant (24 + 27 + 27),
restating AES-NUM-101's tail constancy index by index.
Family 1 heads: all 36 indices vary. Family 2 heads:
all 36 indices vary. The varying set is the same 72
indices in camp A, camp B and pooled: word indices
56..59, 63..66, ..., 175..178 — positions 0..3 of
units 8..25, i.e. every head slot of families 1 and 2
and nothing else.

And the variation is exhausted by the labels: at every
one of the 72 varying indices, in both camps, the
distinct words across the camp's segments are EXACTLY
that family's per-segment label set (label-exhausted
72/72 in camp A, 72/72 in camp B, zero exceptions) —
one label per segment (13 distinct in A, 12 in B),
each appearing exactly once per index. So the whole
728-byte block, across all 25 segments of both camps,
varies in exactly one way: each segment stamps its
family-1 label into all 36 family-1 head slots and its
family-2 label into all 36 family-2 head slots; every
other word of the block is a corpus-wide constant for
the camp population. There is no other per-segment
information in the block. What the labels encode
remains NOT PROVEN.

## (iii) Positional-law completion pairs

The last two directions of the segment-pair square
were run with the identical method (shift window
-128..+128, direct census vs position-set prediction).
Reverse cross-camp B0 x A0 (camp B segidx 0, cidx 121,
length 21648; camp A segidx 0, cidx 130, length
21392): 7,021 ordered pairs with >= 1 tally, 5,489,488
tallies, differing triples 0, out-of-range position
pairs 457,604,528 over 22,548 ordered pairs — the
EXACT mirror of AES-NUM-101's A0 x B0 forward numbers
(7,021 / 5,489,488 / 457,604,528 / 22,548), as the
reversal of both strings and shift must give.
Within-camp B B0 x B1 (cidx 121 x cidx 166, both
length 21648): 7,044 ordered pairs, 5,547,024 tallies,
differing triples 0, out-of-range 463,088,880 over
22,212 ordered pairs. With A0 x B0 and A0 x A1 from
AES-NUM-101, all four pairings of the first two
segments of the two camps are now measured, and the
positional law is EXACT on every one: 0 differing
triples on 22,007,232 tallies in total across the
square.

## Verdict

(i) The DENSE-zero run of four at 28760..28772 is one
instance (cidx 5) carrying four consecutive ff000000
words, mask 00000 throughout, with no other candidate
of its group within 28752..28780; corpus-wide it is
one of 15 single-instance DENSE-zero runs, 14 of
length exactly 4 and 1 of length 3, covering 59 of
the 64 DENSE zeros. Run-site selection NOT PROVEN.
(ii) Block variation is exactly the two family labels:
110/182 indices constant per camp and pooled (matching
AES-NUM-098 exactly), the 72 varying indices are
precisely the family-1/2 head slots, and every one is
label-exhausted in both camps. The block holds no
other per-segment information.
(iii) The positional law completes its segment-pair
square: B0 x A0 mirrors A0 x B0 number for number, and
B0 x B1 is exact (0 differing on 5,547,024 tallies).

NEXT: slice 4.103 — the 5 singleton DENSE zeros and
the length-3 run (maximal raw ff000000 run length and
the candidate's place in it, for all 64 DENSE zeros);
the family-1 vs family-2 label pair within a segment
(25 paired labels: as-function / affine hunts between
the two labels' bytes, under the AES-NUM-100
degeneracy ruling); positional law on the consensus-
camp pair consA x consB. Host/artifact analysis only —
no physical child.
