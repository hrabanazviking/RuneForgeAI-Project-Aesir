# The 22 zero offsets are almost form-exclusive too (one DENSE zero at 28768), the family labels carry no non-degenerate stated function of segment metadata, and the positional law holds on every ungrown region and in reverse (2026-10-24)

Roadmap Campaign 4 iteration, slice 4.100 (AES-NUM-100).
Populations: all seven corpus artifacts (MiniLM plus the
six hailo-ollama blobs), walked on Mimir with hef100.py
(sha256 1aa16f310c2410980cf69a0a46e8c5edd6e7fdd7fe0140db6c81265914bef2d8 —
the sha-verified hef99.py lineage with the 4.100 arms
appended; arms file hef100_arms.py sha256
facec580a7d5e04750301d1f612aefd7b6050c41120b9589eb50b923de415509;
gz sha256 195bacf76cbbd65dcc3a7aeaff69ba6cf85f598a6e49287545135bbf7938c42c
verified on-device before the run). Contract
docs/TASK_CONTRACT_4.100.md published @ 29876a77 before
implementation. Output: /tmp/hef100_out.txt sha256
fd2c6e999512332df7075600f9129b19fd2513b46f9da89eefed40ba31528c73
(360,939 B, 2,543 lines, DONE100 reached, EXIT 0);
retrieved byte-complete (gz sha256
3b55263d343780672d5faea5be0e495ee9305a912871b6a17d6a9f606f35760a
matches on both sides).
Controls reproduce AES-NUM-029/032...099 EXACTLY
(128,787 pooled small actions; 79,001 pooled 24 B
bursts; 745,849 pointer actions; 1,504 contexts;
trailing distinct (channel, operand) pairs 2,049;
champion-headed bursts 75,215), the scanner re-derives
AES-NUM-090/091 exactly (in-band 374 groups, OTHER 4
all STEP; band X 60 / 3,335, OTHER 0; band Y 27 / 354,
OTHER 0; S1 OTHER 16, S2b OTHER 10, all non-step),
the 26 non-step OTHER offsets re-derive with per-ng
CONST 14 and combined per-ng coverage 19, residue
exactly 7, trains reproduce exactly (52 trains;
unique-first 28, unanimous 13, elsewhere 11;
D(cidx 113) = 249; firsts' D-positions 3,089;
control-arm D-positions 176), camps reproduce
(A 21392 x13, B 21648 x12), the rank-2 middles
reproduce (21 aligned mismatches at k = 111, 4 shared
distinct units at indices 1–4), and the
AES-NUM-095/096/097/098/099 headline counts reproduce
exactly (whole-arm candidates 7,690; SPARSE zero
144/2,280, DENSE zero 64/2,898, MID zero 21/2,306;
F = 144 with masks {10011: 108, 11011: 30, 01011: 6};
mask table 01011 1,088/6, 10011 549/108, 11011 348/30,
11001 61/0, 11010 234/0; region 0 = 2,056 aligned
words / 02-count 150 / distinct 104 per camp; six-pair
totals s = 0: 28 and s = +64: 44; 20>3e at exactly 21
shifts, x8 at +31; a9>3e at exactly shifts -16, +64;
per-offset determinism with 22 zero (mask, offset)
pairs; block 26 units x 7 words, 3 unit patterns per
camp; re-collection exact at 2,280 with counterpart
total 2; all 75 (segment, family) head cells constant;
family 0 = ffffff7f in all 25 segments; positional law
exact for all byte pairs, 602 pairs, 131,360 tallies,
0 differing triples, out-of-range 24,544 over 269
pairs — the last also serving as this slice's
grown-direction control, reproduced in the same run).

## (i) The 22 zero offsets across all forms

The whole non-common re-collection WITH form matches
the contract population exactly (7,484 candidates;
SPARSE 2,280/144 zero, MID 2,306/21, DENSE 2,898/64),
so this arm is credited. At the 22 zero offsets there
are 146 SPARSE candidates, of which exactly 144 are
zero — the same 144, the only 2 non-zero SPARSE
candidates being the AES-NUM-099 counterparts at 7632
and 28768. Against that, the DENSE and MID forms are
nearly absent at these offsets: 4 DENSE+MID candidates
in total at all 22 offsets (DENSE at 3 offsets, MID at
1), against 616 DENSE+MID candidates at the 626 other
SPARSE-carrying offsets (9 zeros there). The four:
6180 MID 1/0 zero (value 127, mask 00011, 0a0d378c
pos 20); 28768 DENSE 1/1 zero (mask 00000, 0a0d378c
pos 16); 29336 DENSE 1/0 (value 67, mask 00010,
0a0d378c pos 20); 30136 DENSE 1/0 (value 45, mask
00010, 0a0d378c pos 20).

Form-exclusivity therefore FAILS, by exactly one
candidate: offset 28768 carries a DENSE zero as well
as its SPARSE zeros, so the zero offsets are not
exclusive to the SPARSE form. What holds is a measured
distribution, stated exactly: 21 of 22 zero offsets
carry no DENSE/MID zero at all, 18 of 22 carry no
DENSE/MID candidate of any kind, and DENSE+MID
candidates are ~5x rarer per offset at the zero
offsets (4/22) than at other SPARSE-carrying offsets
(616/626). No mechanism is credited: NOT PROVEN.

## (ii) Family-1/2 label values vs segment metadata

The label table (25 segments; metadata per segment:
camp, camp-internal rank, cidx, ng = 1 for all, ngidx,
nact = 89 for all, position-18 action (offset, 21392 /
21648, channel 0)) reproduces AES-NUM-099's constants:
family 1 = byte0 fully varying (13 distinct in A, 12
in B, 25 pooled) over a byte1 of 2 values per camp
(A: a2 x11, a3 x2; B: a2 x9, b3 x3) with bytes 2–3
identically 0000; family 2 = bytes 0–1 fully varying
(11–13 distinct per byte per camp, 20/21 pooled),
byte2 of 2 values per camp ({01, 02}), byte3
identically 00.

The stated-function hunt returns 501 exact hits, and
every one of them is degenerate: 408 are as-function
hits on a constant byte (the zero bytes — any mapping
of anything to a constant is exact); 27 are affine
hits, all (a, b) = (0, 0) on those same constant
bytes; 55 are as-function hits where the tested X is
injective on the population (cidx mod 16 in camp A has
13 distinct values for 13 segments — a function of an
injective key is a tautology, not a law, the same
ruling as AES-NUM-048/049); and the remaining 11 are
as-function hits on a byte taking at most 3 distinct
values in its scope (family-1 byte1, family-2 byte2 in
single camps), where a mod partition merely separates
the few minority-value segments. NO hit touches a
non-degenerate affine form (a ≠ 0) on any varying byte,
and no hit of any kind determines family-1 byte0 or
family-2 byte0/byte1 from cidx, rank, ngidx, camp,
segment size or channel except through an injective
key. Monotonicity agrees: every varying byte and both
word readings carry inversions in every scope (fam1
byte0 36/78 A, 40/66 B, 160/300 pooled; fam2 wordBE
56/78 A, 28/66 B, 179/300 pooled); only the constant
bytes show 0 inversions, vacuously. Cross-family:
fam1 XOR fam2, the byte-wise difference and the
full-word difference are each fully distinct per
segment (13 in A, 12 in B, 25 pooled — never constant),
and the only fam2-byte affine-of-fam1-byte hits are
fam2 byte3 (the constant 00) with b = 0 and arbitrary
a — again the constant byte. What the labels encode
remains NOT PROVEN; the AES-NUM-099 bijection stands
as a labelling, not a stated function.

## (iii) Positional law: ungrown ranks and reverse

Both camps carry 44 ff-delimited regions; the grown
indices are CPFX {2, 8, 22, 26}. Of the remaining 40,
four regions (15, 17, 19, 37) are empty in both camps
and were skipped, recorded. The full census-vs-
prediction test was run on the other 36 ungrown
regions, untrimmed: predicted == census at EVERY
(x, y, s) in every region — aggregate 4,392,812
tallies over 10,591 summed ordered pairs, differing
triples 0, out-of-range position pairs 68,733,956
counted, not hidden (region 0 alone: 2,097,056
tallies, 1,497 pairs, 0 differing, 65,537,120
out-of-range over 5,105 pairs). The positional law is
therefore not a property of the grown middles: it
holds for every region pair the two camps present.

In reverse (A' = B middle, B' = A middle) the law
holds per grown rank (each rank: 32,840 tallies,
differing 0) and pooled it reproduces the forward
numbers exactly with roles swapped: 602 ordered
pairs, 131,360 tallies, 0 differing triples,
out-of-range 24,544 over 269 pairs. The six
AES-NUM-096 copy-span pairs stated in reverse are
all predicted-equal: 20>3e and a9>3e have EMPTY
reverse censuses (the B middles contain no 0x20 byte
at all — in reverse the pair's first byte never
occurs; forward, 0x20 lived only in the A middles),
80>00 out-of-range 2,384, 00>10 out-of-range 210,
02>00 out-of-range 98, 00>20 out-of-range 400.

## Verdict

(i) The 22 zero offsets are DENSE/MID-poor (4
candidates, vs 616 at the 626 control offsets) but
NOT form-exclusive: exactly one DENSE zero, at 28768,
breaks exclusivity; mechanism NOT PROVEN.
(ii) No non-degenerate stated function of the tested
segment metadata determines any family-1/2 label
byte; all 501 exact hits are constant-byte,
injective-key or low-cardinality artefacts. What the
labels encode: NOT PROVEN.
(iii) The positional law is now established for
every region pair of the two camps (36 ungrown
regions, 0 differing triples) and in the reverse
direction on the grown middles (pooled numbers
identical to forward). It is a general property of
the lag census's position arithmetic, not of the
middles.

NEXT: slice 4.101 — the single DENSE zero at 28768
(its segment, neighbourhood and group vs the SPARSE
zeros at the same offset); family label byte0 values
vs the segments' own block words beyond the head
positions (in-segment function hunt); positional-law
scope test on a non-camp segment pair. Host/artifact
analysis only — no physical child.
