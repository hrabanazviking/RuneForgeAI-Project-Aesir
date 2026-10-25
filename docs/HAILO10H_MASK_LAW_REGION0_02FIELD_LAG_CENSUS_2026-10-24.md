# The trailing zero pair is necessary but not sufficient for a sparse zero, region 0 is zero-dominated with a small local 02-field, and the copy substitution pairs occur at every lag (2026-10-24)

Roadmap Campaign 4 iteration, slice 4.97 (AES-NUM-097).
Populations: all seven corpus artifacts (MiniLM plus the
six hailo-ollama blobs), walked on Mimir with hef97.py
(sha256 12adaa124c9361335544f1350a48787dd7f37978f1c980ea284d61eb2fff44d0 —
the sha-verified hef96.py, sha256 3f2475aa…, with the
4.97 arms appended; arms file hef97_arms.py sha256
72600fee…, landed via sha-gated chunked file.write
transfer, gz sha256 35ebdd55… verified on-device;
combined script sha verified on-device and compiled).
Output: /tmp/hef97_out.txt sha256
817d3b5074c066b64b91d4f56b732ba7024b55c3621acd82697df7464602bb32.
Controls reproduce AES-NUM-029/032...096 EXACTLY
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
reproduce AES-NUM-094/095/096 (21 aligned mismatches
at k = 111, 4 shared distinct units at indices 1–4),
the AES-NUM-095 headline counts reproduce exactly
(whole-arm candidates 7,690, boundary 0; non-common
SPARSE zero 144/2,280, DENSE zero 64/2,898, MID zero
21/2,306), and the AES-NUM-096 headline counts
reproduce exactly (F = 144, z3 114/1,932, z4 30/348,
z5 0 candidates; F masks {10011: 108, 11011: 30,
01011: 6}; zeros at 37/869 distinct (group, offset)
pairs; shared-offset zero rate 131/1,671 = 7.84%,
singleton 13/609 = 2.13%; rank-8 window6 hits exactly
[own position, 1510] in both camps; B06/B11 copy
mismatches 2 and 4 at both k).
Definitions (ff scan, trains, camps, middles,
neighbourhood form: five aligned words at
p-8..p+8, SPARSE = >= 3 all-zero words, MID = 2,
DENSE = <= 1) are as in the contract.
Contract: docs/TASK_CONTRACT_4.97.md (published
@ 0e5a60f6, before implementation).

## (i) Mask law test: the trailing zero pair is necessary for a sparse zero (no counterexample in 2,280) but separates almost nothing — 1,841 of the 1,985 candidates that carry it are not zero

The sparse non-common population reproduces at
exactly 2,280 candidates, 144 zero and 2,136
non-zero. Only five neighbourhood masks occur at
all in this population (bits are the words at
p-8, p-4, p, p+4, p+8; 1 = zero word; the target
bit is always 0, as the target is an ff word):

- 01011: 1,088 candidates, 6 zero (0.55%)
- 10011: 549 candidates, 108 zero (19.67%)
- 11011: 348 candidates, 30 zero (8.62%)
- 11001: 61 candidates, 0 zero
- 11010: 234 candidates, 0 zero

The three aggregate tests of the contract coincide
exactly, because the masks ending in 11 that occur
in this population are precisely F's three masks
{10011, 11011, 01011}: positive class 1,985
candidates with 144 zero and 1,841 non-zero (zero
rate 7.25%); negative class (11001 + 11010) 295
candidates with ZERO zero values. As a candidate
law "value == 0 iff the mask ends in 11" the counts
are TP 144, FP 1,841, FN 0, TN 295 — not exact, so
no law is credited. What survives is one-directional
and exact in this population: every sparse zero
candidate sits immediately before a trailing pair
of zero words (FN = 0 over 2,280), and no candidate
whose following words are not both zero is ever
zero-valued here. The shape is necessary, nowhere
near sufficient.

Inside the ending-in-11 class the zero rate depends
strongly on WHICH preceding word is zero: mask
10011 (zero only at p-8, the far preceding word)
carries 108 of the 144 zeros at a 19.67% rate,
mask 11011 (both preceding words zero) 30 at
8.62%, and mask 01011 (zero only at p-4, the near
preceding word) only 6 at 0.55% — a 36-fold spread
between the far-only and near-only shapes. The
z-split inside the class reproduces AES-NUM-096
(z = 3: 114/1,637 = 6.96%; z = 4: 30/348 = 8.62%).

Verdict: MEASURED — necessity of the trailing zero
pair is exact in this population; sufficiency is
refuted (1,841 counterexamples); the per-mask rate
ordering (far-preceding zero richest) is measured,
and why it holds is NOT PROVEN.

## (ii) Region-0 02-field anatomy: region 0 as a whole is zero-dominated — the 02-field is a local feature around offsets 1492–1544, and the 89/82 words are unanimous singletons

Region 0 re-derives identically in both consensus
camps (offsets 0–8224, 2,056 aligned words). The
aligned-word census per camp: 150 words are
02000000 (7.3%), 104 distinct values occur in all,
and the dominant word by far is 00000000 (1,389
occurrences). AES-NUM-096's "field of 02000000
words" therefore describes only the local habitat
around the second 8900 pair, not region 0 as a
whole; region 0 is a zero-dominated structured
region in which 02-words are a minority.

The two camps' region-0 censuses are almost
identical: 103 distinct non-02 values per camp,
100 of them shared with identical counts, and
exactly three differing values — the offset-0
header word (0228f0a6 in camp A, 0328f0a8 in camp
B, one occurrence each) and two 36-occurrence data
words (A: 3fa20000 and 50ce0200; B: daa20000 and
68020100).

02-runs: 16 runs of consecutive aligned 02000000
words per camp, with an identical run-length
histogram in both camps ({1: 7, 3: 1, 5: 1, 6: 2,
14: 1, 22: 1, 23: 1, 32: 2} words; the lengths sum
to the 150 02-words). The run immediately before
the 89 word ends at 1512 and spans 1492–1512
(5 words); the run immediately after the 82 word
starts at 1520 and spans 1520–1544 (6 words); the
longest runs are 32 words (two of them; the first
at 4280–4408).

The 89 word (89000000) and the 82 word (82000000)
are singletons in region 0: exactly one aligned
occurrence per camp, at 1512 and 1516 respectively;
each is unanimous in every individual camp segment
(A 13/13, B 12/12), and pooled over each camp's
segments each word occurs aligned exactly once per
segment in the whole segment (13 A, 12 B) — their
aligned home is this one position. (Both words do
occur at further unaligned offsets outside region
0 in the consensus segments; those are not aligned
word occurrences.) 

Verdict: MEASURED — the 02-field is a local,
camp-identical structure bracketing a unanimous
89/82 pair that occurs exactly once per segment;
what the pair, the field, or the region's data
words encode is NOT PROVEN.

## (iii) Substitution-pair census at other lags: the six copy pairs are not lag-specific — they occur at all 257 shifts — but a9->3e occurs at exactly the two shifts that align A's unique a9 with B's two 3e bytes

Controls inside the arm pass exactly: at s = 0 the
copy-1 span carries exactly (20,3e) once and
(80,00) once per rank, and at s = +64 the copy-2
span carries exactly (00,10), (a9,3e), (02,00),
(00,20), once each per rank, in all four ranks.

Pooled over the four ranks' middles, the six pairs
occur at EVERY shift in -128..+128 (257 shifts;
per-shift totals from 16 to 98; 14,426 occurrences
in all). At the copy alignments themselves: s = 0
totals 28 ((20,3e) 4, (80,00) 20, (02,00) 4;
128 mismatches over 672 compared positions) and
s = +64 totals 44 ((a9,3e) 4, (00,10) 8, (00,20)
16, (02,00) 4, (80,00) 12; 232 mismatches over
672). The bulk pairs ((80,00), (00,20), (00,10),
(02,00)) are built from the middles' commonest
bytes and occur everywhere; neither copy alignment
is a maximum or otherwise distinguished in the
per-shift totals (the maxima are 98, at shifts
+23, +39, +47, +55).

The one distinctive sub-result concerns the rare
3e pairs. (20,3e) occurs at 21 shifts, four times
(one per rank) at 20 of them and eight times at
shift +31. (a9,3e) occurs at exactly two shifts,
-16 and +64, four times each: precisely the two
shifts that align A's single a9 byte (A middle
position 119, its only occurrence per AES-NUM-096)
with one of B's two 3e bytes (B positions 103 and
183, the byte 7 of the two repeated-unit copies) —
at +64 with the copy-2 3e (the original copy-span
alignment), at -16 with the copy-1 3e.

Verdict: MEASURED — as bare byte pairs the six
substitutions are a generic middle phenomenon, not
a signature of the copy alignments; the a9/3e
two-shift confinement is exact in this census but
is a consequence of the two sides' singleton/double
positions, and what the substitutions encode
remains NOT PROVEN.

## Next (slice 4.98)

- Per-mask x group/offset anatomy of the sparse
  zeros: is mask 10011's richness (108/549)
  concentrated in the same groups/offsets as F
  overall (0856a10c positions 9/10), or is it a
  different sub-population from 01011's?
- Region-0 data-block anatomy: the 36-occurrence
  word blocks (offsets ~6184–6896, incl. the A/B
  differing words 3fa20000/50ce0200 vs
  daa20000/68020100) — block structure, positions,
  and per-segment unanimity.
- The 20>3e shift set: why those 21 shifts (which
  A 20-positions align with B's 3e bytes at each),
  and the +31 doubling.
Host/artifact analysis only — no physical child.

## Evidence boundary

Host/artifact analysis only; no physical child ran.
Counts are complete-population over the seven
artifacts within the stated bands and floors; blob
identities are sha prefixes only. Every count,
offset, and byte string above is re-derived by
hef97.py in this slice, not carried forward on
trust.
