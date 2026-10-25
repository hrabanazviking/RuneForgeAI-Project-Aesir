# The sparse neighbourhood form does NOT predict values across the OTHER habitat (it enriches zero values ~3x in whole segments but is no law), middle unit 0 is a genuine per-rank form present in every camp segment and recurring nowhere else, and the B middle's repeated unit sits in two copies with different aligned mismatch profiles, neither inside the skipped chunk (2026-10-24)

Roadmap Campaign 4 iteration, slice 4.95 (AES-NUM-095).
Populations: all seven corpus artifacts (MiniLM plus the
six hailo-ollama blobs), walked on Mimir with hef95.py
(sha256 ae71d85f191ae3a3a7072726bdc8b4136c7b035c47a998e1a803cd80801e3b73...,
landed via sha-gated chunked file.write transfer,
gz sha256 842dcdf47c0d1e9e3cbbefab19ce3175e4637444dac04c0abd53513b44b7b76a...
verified on-device; script sha verified on-device).
Output: /tmp/hef95_out.txt sha256
cf6884e8b81382d45c5edda67a88b4725bbd352256fa9d1c661d04673bbc858c....
Controls reproduce AES-NUM-029/032...094 EXACTLY
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
(A 21392 x13, B 21648 x12), and the rank-2 middles
reproduce AES-NUM-094 (21 aligned mismatches at
k = 111, 4 shared distinct units at indices 1–4).
Definitions (ff scan, trains, camps, middles,
neighbourhood form: five aligned words at
p-8..p+8, SPARSE = >= 3 all-zero words, MID = 2,
DENSE = <= 1) are as in the contract.
Contract: docs/TASK_CONTRACT_4.95.md (published
@ 69d4d2fb, before implementation).

## (i) Sparse-form census: the form that marked the five residue targets does not generalise — across the OTHER habitat it neither predicts zero values nor deviation from the per-ng laws, and in whole segments it only enriches zero values

The 26 non-step OTHER offsets sit in 18 unique
(artifact, position, size) groups (the sister
pos-21 groups contribute 8 of the 26 entries).
11 of the 26 entries have exactly one common ff
offset; the other 15 have 2–8 (the 5ab3537d pos-9
group has 8). The common-offset arm therefore
speaks beyond the target offsets for most entries,
weighted by entry: 480 (entry, common offset,
instance) observations in total, 160 of them from
the two sister pos-21 groups alone.

Common-offset arm (480 observations): forms
DENSE 220, SPARSE 141, MID 119.

- value == 0: SPARSE 8/141, DENSE 3/220, MID 0/119.
  The sparse instances of the habitat are NOT the
  zero-value instances — the AES-NUM-094 residue
  pattern (sparse = value 0 in T3/T4/T5, sparse =
  the deviating non-zero value in T1/T2) is a
  property of those five small groups, reproduced
  exactly here inside this arm (T5: its four
  value-0 instances are SPARSE with the
  byte-identical tuple (00000000, ff0f0000,
  ff000000, 00000000, 00000000), its one
  value-carrying instance DENSE), not a habitat law.
- value == ngidx: SPARSE 2/141, DENSE 180/220,
  MID 10/119.
- Where a per-ng law exists (449 observations):
  value == per-ng prediction — SPARSE 79 follow /
  56 break, DENSE 93 / 103, MID 55 / 63. Form and
  obedience to the per-ng law are independent at
  these rates (follow rates 59% / 47% / 47%): a
  sparse neighbourhood neither obeys nor breaks
  the law that governs its offset.

Whole-segment arm (the every-offset test): 7,690
aligned ff-pattern candidate words over the 18
unique groups' instances, 0 boundary cases; forms
SPARSE 2,345, DENSE 2,993, MID 2,352. At the
7,484 non-common candidates, value == 0 rates are
SPARSE 144/2,280 (6.3%), DENSE 64/2,898 (2.2%),
MID 21/2,306 (0.9%): sparse form enriches zero
values roughly 3x over dense and 7x over MID, but
93.7% of sparse candidates carry a non-zero value.
At the 206 common candidates of this arm the
counts are SPARSE 8/65 zero, DENSE 2/95, MID 0/46,
consistent with the common-offset arm.

Verdict: MEASURED — no sparse-predicts-value law
exists in either arm (the contract's exactness
rule fails by hundreds of counterexamples).
What survives: a measured enrichment of zero
values in sparse neighbourhoods at non-common
offsets, and the exact residue-target pattern
of AES-NUM-094 as a small-group phenomenon.
What the sparse form is, and why zero values
cluster in it weakly, remain NOT PROVEN.

## (ii) Middle unit 0: a genuine per-rank form — camps differ only in byte 0, the rank lives in bytes 6–7, every individual camp segment carries it exactly, and it recurs nowhere else in the segment

Unit 0 (first 16 B of each grown rank's middle),
re-derived: A = 50 00 00 00 00 00 <rank> 00...,
B = 60 00 00 00 00 00 <rank> 00... — the camps'
unit 0s are NOT equal, but they differ ONLY in
byte 0 (0x50 vs 0x60); bytes 6–7 carry the rank
exactly as recorded in AES-NUM-094 (rank 2 8780,
rank 8 8900, rank 22 8500, rank 26 8b80, same in
both camps).

Individual segments: at the exact unit-0 position,
every one of the 13 A segments and 12 B segments
carries the consensus unit 0 byte-for-byte, at
every rank (distinct full unit 0s per camp/rank:
1; consensus count 13/13 and 12/12). Unit 0 is a
per-rank segment form, not a consensus artefact.

Recurrence: each rank's full 16 B unit 0 occurs
exactly once in its consensus segment — at its
own position. The 6 B window (bytes 4–9) likewise
occurs only at its own position, except rank 8,
whose window recurs once at segment offset 1510
in BOTH camps (placing a second 8900 pair at
1512, far outside rank 8's grown region, which
begins at 10804). The 2-byte rank values occur
in the whole consensus segment exactly once each
(8780 / 8500 / 8b80) or twice (8900: its unit 0
plus the 1512 pair), and zero times in their own
grown region's prefix, in the middle outside
unit 0, and in the region suffix.

Verdict: MEASURED — unit 0 does not recur as a
pattern anywhere else in the camp segments; the
"wider family" of the contract does not exist
beyond the form itself: one fixed 16 B word per
(rank, camp), present in every segment of the
camp, differing between camps in a single byte
and between ranks in two. What byte 0's camp
step (0x50 -> 0x60), the four rank values, and
the lone second 8900 pair at 1512 encode is
NOT PROVEN.

## (iii) B06/B11 recurrence: one unit in exactly two copies, copy 1 nearly aligned-clean (2 mismatches), copy 2 dirtier (4), and neither copy inside the skipped chunk

The repeated unit is 010000801080003e2000000000002000,
identical at B indices 6 and 11 at every grown
rank (rank-invariant, like its neighbours 5, 7,
10, 12). Its only occurrences in the B middle
are at byte offsets 96 and 176; it occurs
nowhere in the A middle.

Aligned spans (same at every rank and at both
insertion offsets): copy 1 (B bytes 96–111
against A bytes 96–111) mismatches A at exactly
2 positions, A bytes 103 and 111; copy 2
(B bytes 176–191 against A bytes 112–127)
mismatches at exactly 4, A bytes 116, 119, 125,
126. The two copies of one B unit therefore sit
against different A content — the recurrence is
a B-side repetition, not an aligned duplication
of an A span.

Skipped chunks: at k = 111 the chunk B[111:175]
overlaps copy 1 by exactly its last byte (byte
111) and copy 2 not at all; at k = 112 it
overlaps neither. The repeated unit occurs at
no offset inside either chunk. The recurrence
straddles the insertion point from outside:
copy 1 ends where the chunk begins.

Verdict: MEASURED — the B middle's one repeated
unit is a two-copy recurrence at lag 5 units
(byte lag 80), with copy-specific aligned
mismatch profiles (2 vs 4) that are identical
across all four grown ranks; it is not the
inserted chunk, not part of it, and not an A
repetition. An exact period remains NOT PROVEN
(the lag-5 match is 1 of 10 compared units,
AES-NUM-094); what the unit encodes is
NOT PROVEN.

## Next (slice 4.96)

- Sparse zero-enrichment anatomy: the 144 sparse
  non-common candidates with value 0 — split by
  zero count z = 3 / 4 / 5, and by offset sharing
  across instances of a group (fixed offset set
  vs scattered).
- The second 8900 pair: the structure containing
  segment offset 1510–1515 in both camps (which
  region, which position inside it, its
  neighbourhood words) vs the rank-8 unit 0.
- Copy-span byte anatomy: the mismatch bytes of
  copy 1 (unit bytes 7, 15) and copy 2 (A unit 7
  bytes 4, 7, 13, 14) across the four ranks and
  the chunk's alignment against B units 7–10.
Host/artifact analysis only — no physical child.

## Evidence boundary

Host/artifact analysis only; no physical child ran.
Counts are complete-population over the seven
artifacts within the stated bands and floors; blob
identities are sha prefixes only. Every count,
occurrence, alignment and distribution above is
MEASURED as stated; every meaning — what the
sparse form is, what unit 0's bytes encode, what
the repeated B unit encodes — is NOT PROVEN and
nothing here invents one.
