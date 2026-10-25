# The five singleton DENSE zeros are raw singletons too — and the length-3 run is raw length 4; the two labels of a segment share no tested relation; the positional law is exact on the consensus camps (2026-10-24)

Roadmap Campaign 4 iteration, slice 4.103 (AES-NUM-103).
Populations: all seven corpus artifacts (MiniLM plus the
six hailo-ollama blobs), walked on Mimir with hef103.py
(sha256 d79d98092ec064f30914f376941509ca17f0812d5a1be220b5ccf26d8d1db9dd —
the sha-verified hef102.py lineage with the 4.103 arms
appended; arms file hef103_arms.py sha256
c056630544a6923fe34a20785ffdcf78d492faf5c2053b61e0e877e164f35a51;
gz sha256 d9472ba06bf99288d0e438ce51b1f53014d10fd20a47e80a498eefb267dfbe18
verified on-device before the run, script sha verified
on-device, py_compile OK). Contract
docs/TASK_CONTRACT_4.103.md published @ 432ebf6c before
implementation. Output: /tmp/hef103_out.txt sha256
33525c8635b902099b399b64e3567f901d25b39629b3934fca1b240404ead170
(445,631 B, 3,180 lines, DONE103 reached; the process
was launched detached on Mimir and its completion was
observed by poll), retrieved byte-complete (gz sha256
571b79ee046b42eeab9267b11b32d76575175d3e355982f19b34041882e8e442
identical on device and VM). Controls reproduce
AES-NUM-029/032...102 EXACTLY (128,787 pooled small
actions; 79,001 pooled 24 B bursts; 745,849 pointer
actions; 1,504 contexts; trailing distinct (channel,
operand) pairs 2,049; champion-headed bursts 75,215),
camps reproduce (A 21392 x13, B 21648 x12), trains
reproduce (52; 28/13/11; D113 249; firsts' D 3,089;
control D 176), the whole non-common re-collection
matches the hef100/101/102 population exactly (7,484
candidates; SPARSE 2,280/144 zero, MID 2,306/21,
DENSE 2,898/64), and DONE102 lands at line 2,892 —
the 4.102 output reproduced line for line.

## (i) Singleton and length-3 anatomy: raw runs

The offset-set census of AES-NUM-102 leaves exactly 5
singleton DENSE zeros (in no run of length >= 2 at
spacing 4), and the raw-word anatomy agrees with it
perfectly. The five, with their neighbourhood tuples
(words at q-8, q-4, q, q+4, q+8):

- (0a0d378c, 21, 32560) q 6156, cidx 74, mask 00000 —
  (08000000, 02000000, ff000000, 02000000, 08000000);
  the segment around it is a small-word ladder
  (08/02 alternating), and the ff word stands alone
  between 02000000 on both sides.
- (5ab3537d, 9, 32584) q 5040, cidx 28, mask 00000 —
  (f6000000, fd000000, ff000000, 02010000, 04010000);
  the ff word is the top of a rising byte-0 sequence
  ee/f4/f6/fd/ff below and small words above, with
  two zero words further above (5052/5056).
- (MiniLM, 23, 32768) q 6700, cidx 5, mask 00000 —
  (ff7f0000, ffffff7f, ff000000, e9ff0000, ff7f0000);
  inside the block-like ff7f/ffffff7f texture.
- (MiniLM, 23, 32768) q 11408, cidx 5, mask 00010 —
  (01000800, 4c01a380, ff000000, 00000000, 01000800).
- (MiniLM, 23, 32768) q 32248, cidx 5, mask 00010 —
  (01000800, 1c01b280, ff000000, 00000000, 01000800).

Three of the five live in a single MiniLM instance
(cidx 5); the two mask-00010 singletons share their
whole frame shape (01000800 ... ff000000, 00000000,
01000800) and differ only in the q-4 word. Every
singleton's maximal raw ff-run has length exactly 1
and the candidate sits at position 0 of it — the
singletons are not truncated runs; in their own
segments there is no second ff word next to them at
all.

The length-3 run is the one place the two
classifications part — in the informative direction.
Its members are (0a0d378c, 20, 32752) cidx 44 at
17348/17352/17356, exactly as AES-NUM-102 recorded.
But the instance's raw words at 17332..17372 read
01000101, 04000a00, a000a280, ff000000 (17344),
ff000000, ff000000, ff000000 (17356), 09000a00,
bc00a280, 02000000, 00000000: the maximal raw run is
17344..17356, length 4, flanked by a000a280 below and
09000a00 above. The word at 17344 is ff000000 in this
instance yet carries no DENSE-zero candidate here —
in the sister group (0a0d378c, 20, 32688) cidx 8 the
same raw run 17344..17356 carries all four candidates.
So the raw segment holds a full run of four; the
candidate population of this instance simply does not
include its first word. Why 17344 carries no candidate
in this instance is NOT PROVEN by this arm (the
population is defined over non-common offsets of the
group; the exclusion itself was not isolated here).

For all 64 DENSE zeros the raw word at q is ff000000
(64/64). The raw-run length distribution over the 64
zeros is {1: 5, 4: 59} — identical counts to the
offset-set distribution, but the distinct maximal raw
runs number 20, not 20-minus-one: 15 of length 4 and
5 of length 1 (the length-3 offset run and its sister
length-4 run are two distinct raw runs in two distinct
instances that happen to share the same raw interval).
Position of the candidate inside its raw run:
{0: 19, 1: 15, 2: 15, 3: 15} — position 0 is short by
exactly one against a naive 20, because the
17344..17356 raw run's first word is not a candidate
in its instance, so its three candidates sit at
positions 1, 2, 3. Classification agreement between
raw-singleton and offset-singleton is 64/64 with zero
disagreements. Run-site / singleton selection remains
NOT PROVEN.

## (ii) The fam1/fam2 label pair within a segment

All 25 camp segments carry exactly one distinct
family-1 head word and one distinct family-2 head word
(no bad segments). The 25 pairs (label1, label2):
camp A — 3fa20000/a0ce0100, 7da20000/c82a0200,
56a20000/88040200, e0a20000/f8020200, 16a30000/500d0200,
65a20000/500c0200, 7ba20000/58f10100, 48a20000/d8060200,
83a20000/28fe0100, a0a20000/30010200, 82a20000/a8fc0100,
6ea30000/300a0200, 31a20000/00e80100; camp B —
dab30000/f0fa0100, 78a20000/00020200, f3a20000/a0050200,
cca20000/20e20100, 43a20000/70fb0100, e1a20000/40020200,
cdb30000/802b0200, 50a20000/68ec0100, 94a20000/48f60100,
75b30000/b80a0200, efa20000/d0ff0100, 4aa20000/68fc0100
(in hef99 camp order, cidx as printed in the output).

Pooled, label1 takes 25 distinct values, label2 takes
25 distinct values, and the 25 pairs are all distinct.
NO label1 value repeats across camps and NO label2
value repeats across camps. Byte anatomy: label1 is
(byte0 all 25 distinct; byte1 in {a2 x20, a3 x2,
b3 x3}; bytes 2-3 zero) — low3 groups a20000 x20,
a30000 x2, b30000 x3. Label2 is (byte0 20 distinct,
with five values taken twice — 00, 30, 50, 68, a0;
byte1 21 distinct; byte2 in {01 x12, 02 x13}; byte3
zero).

The pair hunts find nothing honest. As-function:
every 'function True' line in the forward direction
is degenerate under the AES-NUM-100 ruling — either
the determiner is injective in scope (label1 byte0
and the full words are distinct per segment by
construction of the population) or the target is the
constant byte3. Every non-degenerate forward test
fails with mixed keys (label1 byte1 -> each label2
byte: mixed 2/2 in A, 2/2 in B, 3/3 or 2/3 pooled;
the constant bytes 2/3 determine nothing). The
reverse direction is the same: label2 byte0/byte2/
byte3 -> label1 byte0 all mixed; label2 byte1 ->
label1 byte0 is a function only inside camp A, where
label2 byte1 is itself injective (13 distinct in 13
segments — degenerate), and it is mixed in camp B
(1/11) and pooled (3/21). Affine hunts: ZERO
non-degenerate hits in any scope, for any (k, j),
in either the a*x + c (mod 256) form with a != 0 or
the XOR-constant form. Whole-word relations:
label1 XOR label2 takes 25 distinct values pooled
(13 in A, 12 in B — every segment its own), and the
u32 little-endian difference label2 - label1 likewise
25 distinct; neither is constant in any scope. The
two labels of a segment are, to every stated test,
independent: knowing one gives no purchase on the
other beyond naming the segment itself. What the
labels encode remains NOT PROVEN.

## (iii) Positional law on the consensus-camp pair

consA (length 21392, 151 distinct bytes) x consB
(length 21648, 150 distinct bytes), full untrimmed
consensus segments, same method and shift window
-128..+128: 7,011 ordered pairs with >= 1 in-range
tally, 5,489,488 tallies, differing triples 0,
out-of-range 457,604,528 over 22,552 ordered pairs.
The law is EXACT on the consensus pair. Its tally
total equals the A0 x B0 total of AES-NUM-101 exactly
(5,489,488), while its pair counts differ slightly
(7,011 vs 7,021 ordered pairs; 22,552 vs 22,548
out-of-range pairs) — the consensus segments are not
the segidx-0 segments, and the law holds on them all
the same.

## Verdict

(i) The 5 singleton DENSE zeros are raw singletons
(maximal raw ff-run length 1, all five; classification
agreement 64/64, zero disagreements; raw word at q is
ff000000 for 64/64; raw-run lengths over the zeros
{1: 5, 4: 59} across 20 distinct raw runs). The one
length-3 offset run is a raw run of length 4 whose
first word carries no candidate in its instance.
(ii) The fam1/fam2 label pair shares no tested
relation: 25 distinct pairs, no cross-camp repeats,
all non-degenerate as-function tests mixed, affine
and XOR hits zero, XOR and difference both 25-distinct
and never constant. Label identity NOT PROVEN.
(iii) The positional law is EXACT on consA x consB
(0 differing on 5,489,488 tallies).

NEXT: slice 4.104 — the candidate-less raw word at
17344 in (0a0d378c, 20, 32752) cidx 44 (is its offset
a common offset of its group, and does the same
exclusion pattern recur at the other raw runs'
edges?); singleton neighbourhoods vs run-member
neighbourhoods (what, if anything, distinguishes the
5 singletons' frames from the 59 run members');
label values vs segment cidx arithmetic (stated-
function / affine hunts of label bytes on cidx and
camp-internal rank, under the degeneracy ruling).
Host/artifact analysis only — no physical child.
