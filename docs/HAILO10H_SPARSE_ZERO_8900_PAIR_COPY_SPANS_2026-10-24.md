# Sparse zeros concentrate at a few shared offsets and always sit before a pair of zero words, the second 8900 pair lives unanimous in region 0's 02-field in both camps, and the copy spans are rank-invariant with the k=112 chunk exactly B units 7–10 (2026-10-24)

Roadmap Campaign 4 iteration, slice 4.96 (AES-NUM-096).
Populations: all seven corpus artifacts (MiniLM plus the
six hailo-ollama blobs), walked on Mimir with hef96.py
(sha256 3f2475aafd89436bb5db32ed5f0aa97234c240802c00067b2cf8810d2e850ee1,
landed via sha-gated chunked file.write transfer,
gz sha256 b9bd9566c6d27502e45c777398e4e172a1b39e6a1d78169f422451ea841dad19
verified on-device; script sha verified on-device).
Output: /tmp/hef96_out.txt sha256
dd9e175b8ed6e822bd95cc7057deaf7ef63eff1608fd87cdbe64abc1001c245a.
Controls reproduce AES-NUM-029/032...095 EXACTLY
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
reproduce AES-NUM-094/095 (21 aligned mismatches at
k = 111, 4 shared distinct units at indices 1–4),
and the AES-NUM-095 headline counts reproduce
exactly (whole-arm candidates 7,690, boundary 0;
non-common SPARSE zero 144/2,280, DENSE 64/2,898,
MID 21/2,306; rank-8 window6 hits exactly [1510,
own position] in both camps; B06/B11 copy mismatches
2 and 4 at both k).
Definitions (ff scan, trains, camps, middles,
neighbourhood form: five aligned words at
p-8..p+8, SPARSE = >= 3 all-zero words, MID = 2,
DENSE = <= 1) are as in the contract.
Contract: docs/TASK_CONTRACT_4.96.md (published
@ dd61cd52, before implementation).

## (i) Sparse zero-enrichment anatomy: the 144 sparse non-common zero candidates cluster at 37 shared offsets, grow modestly with z, and every one sits immediately before a pair of zero words

The focus population F (SPARSE, non-common, value
== 0) reproduces at exactly 144 over 2,280 sparse
non-common candidates.

z-split: z = 3 carries 114 of the 144 (zero rate
114/1,932 = 5.90%); z = 4 carries 30 (30/348 =
8.62%); z = 5 does not occur at all among sparse
non-common candidates (0 candidates) — no
neighbourhood in this population has all five
words zero. The enrichment rises with z but stays
under 9% at every level: a gradient, not a law.

Neighbourhood masks in F are exactly three, and
all three end in 11 — in every one of the 144,
BOTH following words (at p+4 and p+8) are zero,
the target word itself is never zero (consistency
check 0/144, as it must be for an ff word), and at
least one of the two preceding words is zero:
mask 10011 x108, 11011 x30, 01011 x6 (bits are the
words at p-8, p-4, p, p+4, p+8; 1 = zero word).
The sparse zeros of this habitat are therefore
always the last non-zero word before a run of at
least two zero words, with a zero somewhere in
the two words before them.

Offset sharing: the sparse non-common candidates
sit at 869 distinct (group, offset) pairs; zero
values occur at only 37 of them. The zero-instance
histogram over those pairs is {1: 13, 2: 7, 4: 3,
6: 7, 9: 7} (sums to 144) — seven offsets carry
nine zero instances each, seven carry six. Zeros
are a shared-offset phenomenon: at (group, offset)
pairs shared by >= 2 instances the zero rate is
131/1,671 = 7.84%, at singleton pairs 13/609 =
2.13%. Per group the concentration is sharper
still: two groups of one artifact (0856a10c
positions 9 and 10) carry 106 of the 144 zeros
(43 + 63, at only 8 and 7 distinct offsets), and
8 of the 18 groups carry none.

Verdict: MEASURED — no exact law (832 of 869
offsets never carry a zero sparse candidate, and
even the richest z level is 91% non-zero). What
survives: zeros cluster at few, mostly shared
offsets in few groups, and their neighbourhood
shape is rigid (trailing zero pair in 144/144).
Why those offsets, and what the trailing zero
pair means, remain NOT PROVEN.

## (ii) Second 8900 pair: a unanimous window in region 0's 02-field, byte-identical in both camps, in a different habitat from the rank-8 unit 0

The recurring 6 B window (000089000000, the rank-8
unit 0's bytes 4–9) sits at segment offset 1510 in
BOTH consensus camps, inside region 0 (offsets
0–8224, the segment's first ff-delimited region,
not one of the grown regions), 1,510 bytes from
its start and 6,714 before its end.

Its habitat is a field of 02000000 words: the
aligned words at 1504, 1508, 1512, 1516, 1520 are
02000000, 02000000, 89000000, 82000000, 02000000
in both camps; the camps are byte-identical over
the whole span 1496–1543; and every individual
camp segment carries the window unanimously
(A 13/13, B 12/12; pair bytes 8900 in all 25).
The window here spans the end of the 02000000
word at 1508, the full 89000000 word at 1512, and
the start of the 82000000 word at 1516.

Against the rank-8 unit 0's own surroundings the
contrast is measured: the 32 B surrounding spans
share 19/32 equal bytes in each camp — the shared
part is the zero field; the unit 0 sits in its
grown region behind header bytes
(0000c801a1800100... in both camps) while the
1510 pair sits in region 0's 02-field followed by
an 82 word. The 6 B window form therefore occurs
in (at least) two habitats; the full 16 B unit 0
occurs in only one (AES-NUM-095).

Verdict: MEASURED — the second 8900 pair is a
fixed, camp-independent, segment-unanimous
feature of region 0's 02-field, not a stray copy
of the unit 0. What the pair, its 89 word, or the
following 82 word encodes is NOT PROVEN.

## (iii) Copy-span byte anatomy: both spans and every mismatch byte pair are rank-invariant, and the skipped chunk is exactly B units 7–10 at k = 112 (the same block one byte early at k = 111)

Copy spans, re-derived per grown rank: copy 1
(A 96–111 vs B 96–111) and copy 2 (A 112–127 vs
B 176–191) are byte-identical across all four
ranks in both camps. The mismatch byte pairs are
therefore rank-invariant too:

- copy 1: A pos 103: A 20 vs B 3e; A pos 111:
  A 80 vs B 00 (unit bytes 7 and 15).
- copy 2: A pos 116: 00 vs 10; 119: a9 vs 3e;
  125: 02 vs 00; 126: 00 vs 20.

Byte census (rank-2 middles / consensus segments):
the B-side 3e occurs 0x in the A middle and 2x in
the B middle — exactly the two copies' byte 7 —
and 2x / 10x in the consensus A / B segments; the
A-side a9 of copy 2 occurs exactly once in the A
middle (this position) and 0x in B; the remaining
mismatch bytes are common values (00, 02, 10, 20,
80 occur 1–241x in the middles and segments).

Chunk / unit alignment: both chunks are identical
across all four ranks. At k = 112 the chunk IS
B units 7–10 verbatim: 64/64 bytes at shift 0
against units 7–10 concatenated, the four units
at chunk offsets 0, 16, 32, 48, and no other shift
in -16..+16 above 31/48. At k = 111 the chunk is
the same block read one byte early: its last byte
of unit 6, then units 7, 8, 9 verbatim at chunk
offsets 1, 17, 33, then the first 15 bytes of
unit 10 (shift -1 identity 63/63; unit 10 does
not occur complete inside it). The chunk's first
16 B recur in the B middle only at the chunk's
own start (111 / 112) and its last 16 B only at
159 / 160 — the chunk occurs nowhere else.

Verdict: MEASURED — the insertion ambiguity
between k = 111 and k = 112 is exactly a one-byte
shift of one aligned four-unit B block
(units 7–10); the two copies of the repeated unit
face A spans that differ from it in a small,
fixed, rank-invariant set of byte substitutions
(2 in copy 1, 4 in copy 2). No exact period is
claimed (the lag-5 unit match remains 1 of 10,
AES-NUM-094). What the substitutions encode is
NOT PROVEN.

## Next (slice 4.97)

- Mask law test over ALL sparse non-common
  candidates: per-mask zero rates (does the
  trailing-zero-pair shape ??011 separate the
  144 from the 2,136 non-zero sparse candidates,
  or do non-zero candidates share the shape?).
- Region-0 02-field anatomy: the extent of the
  02-run containing offset 1512, every non-02
  aligned word in region 0, and the 82 word's
  recurrence across both camps' segments.
- Substitution-pair census: the six copy-span
  mismatch pairs (20->3e, 80->00, 00->10, a9->3e,
  02->00, 00->20) searched as aligned byte pairs
  across the A/B middle alignments at other lags.
Host/artifact analysis only — no physical child.

## Evidence boundary

Host/artifact analysis only; no physical child ran.
Counts are complete-population over the seven
artifacts within the stated bands and floors; blob
identities are sha prefixes only. Every count,
offset, and byte string above is re-derived by
hef96.py in this slice, not carried forward on
trust.
