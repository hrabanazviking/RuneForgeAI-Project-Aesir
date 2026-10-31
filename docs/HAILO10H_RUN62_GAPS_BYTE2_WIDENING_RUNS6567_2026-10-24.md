# Run 62's two internal gaps are channel disagreements on an otherwise identical (offset, size) sequence — at all 23 corresponding positions of the A 438–460 / B 441–463 windows the (offset, size) pairs are identical, and the channel differs at exactly the seven gap correspondences (A ch 1 vs B ch 2 at the first gap, A ch 2 vs B ch 0 at the second), so every gap act is B-only and every skipped act is A-only with exactly one corpus occurrence each; the matched A byte2→byte3 regularity does NOT extend to the wider population (aggregated over all 56 ordered cell pairs of the (20, 32720) group it fails on both sides, and of the 81 widened rows carrying an original key only the original pair's own 27 agree while 54 contradict); and runs 65 (+0 singleton in place), 66 (−156 pair at B 346–347) and 67 (−2 pair in place) are each one contiguous B block (AES-NUM-167)

Slice 4.167, worked under `docs/TASK_CONTRACT_4.167.md`
(contract published in the 4.166 closing commit @
5006d7ff). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child, no device run of
any kind. All findings below are taken from the
sha-verified raw output; the few derived counts marked
as such were computed at closing from the run's own
printed tables, never sampled.

## Run and closing record

hef167.py (hef166.py verbatim as base plus the new
arms167) sha256
`6320ca8e31ed74cd162a686c9c939ce55d7f157bb53cada7bb768525ebf858e1`
(975,611 B); arms167 sha256
`34a62f24419c392f911146e003183e63eed49d1e4bf22aeed6f97fb002d25d31`
(14,642 B), its gzip sha256
`10989284ac7e0138eac00b6531930d15ff9c9eb1148ecfb9f6458a470fe6b732`
(4,550 B). The base hef166.py was verified on the VM ==
the on-device hef166 (sha256 3eb4a0d6…) before
assembly. Crossing record: the gzipped arms crossed
in 13 sha-gated parts of 373 B (last part 74 B); all
13 verified on-device first try. The assembled gzip,
the decompressed arms and the assembled hef167 sha256
all matched the VM exactly on-device, and the script
compiled on-device. The ONE bounded host-side child
was launched directly in a detached tmux session on
Mimir with the contract corpus argv — the six
hailo-ollama blobs in glob order, then MiniLM — and
finished with DONE167 as its last line, exit marker
0, and a complete output, err empty (0 B). Output
hef167.out: 47,067 lines / 8,982,312 B, sha256
`a53700ba1c9228a4fbb42dffd051a607c2909700514e1cc094dac9b3f4f9f68f`.
Prefix check: of its first 46,696 lines against
hef166.out, exactly ONE line differs (line 42,872,
frozenset element order only — same sorted content
and length verified, the AES-NUM-150 variance); all
other lines byte-identical. Section 167: 371 lines /
48,251 B, sha256
`bd6921651f00b0e5c31e71d02fd37aaf3b4cb400d9ba26053ec89d637cd75b49`,
fetched by a device file read, verified on the VM to
exactly the on-device section sha and read in full.
Controls EXACT, including the corrected run-62
control (length 53, shift +3, first A position 438)
and the runs 65/67 controls (65: length 1, shift +0,
first A 501; 67: length 2, shift −2, first A 504);
run 66 was printed as measured (length 2, shift
−156, first A 502). Raw output kept on the Pi at
~/aesir-build/ (hef167.out, hef167.py, arms167.py,
section167.txt); local lineage in
~/workspace/.verify-tmp/aesir167.

## (i) Run 62's two internal gaps in full

The two contexts are artifact 5ab3537d context 86
(A, 749 acts) and context 210 (B, 751 acts). In the
windows A 438–460 and B 441–463 — the same stretch
under run 62's +3 shift — the (offset, size)
sequence is IDENTICAL at all 23 corresponding
positions (derived at closing from the printed
windows): every act the two contexts carry there
has the same offset and the same size on both
sides. The contexts differ only in the CHANNEL
field, and they differ at exactly seven positions —
the two gaps:

- Gap 1: A 444–445 carry (785868800, 1552, ch 1)
  and (785870352, 14864, ch 1); B 447–448 carry the
  same (offset, size) pairs at ch 2.
- Gap 2: A 452–456 carry (786063872, 26128),
  (786090000, 32784), (786122784, 26128),
  (786148912, 32784), (786181696, 18448), all
  ch 2; B 455–459 carry the same five (offset,
  size) pairs at ch 0.

Because an act's identity includes its channel,
none of the seven (offset, size) pairs is a shared
act: each B gap act is B-only distinct (absent from
context A, its single B occurrence at the gap
position), each skipped A act is A-only distinct
(absent from context B, its single A occurrence at
the skipped position), and every one of the
fourteen acts has exactly ONE corpus occurrence, in
exactly the one context (A cidx 86 / B cidx 210 of
the same artifact). The cross-match of full act
tuples between the gap set and the skipped set is
empty — the pairs match on (offset, size) in order,
never on the full tuple. The skipped A positions
map to the gap B positions by exactly run 62's +3
shift (444→447, 445→448, 452→455, …, 456→459).

That is the whole mechanism of the gaps at the
record level: run 62 is a run of shared
single-positioned acts, so wherever the two
contexts assign different channels to the same
(offset, size) slot, the slot drops out of the
shared population on both sides — an A skip and a
B gap at +3-corresponding positions. The channel
disagreement is not a constant remapping: gap 1 is
A ch 1 vs B ch 2, gap 2 is A ch 2 vs B ch 0. Why
the channels disagree at exactly these seven slots
is NOT PROVEN.

## (ii) The byte2 regularity against the wider population

Populations stated exactly: pairs1_126 holds 224
distinct lane-1 pairs in three groups — (20, 32720)
with 216 pairs, (14, 9992) with 5, (19, 7712) with
3 (the contract's "all 224 pairs of the (20, 32720)
group" reads as the full 224-pair population, of
which the great group holds 216; both populations
were tested and are reported separately).

Within-pair test (a pair's own bval−aval byte3
difference as a function of its byte2 difference):
NOT A FUNCTION in every population — great group
216 rows / 169 keys / 40 violating keys; full 224
rows / 169 keys / 41 violating; the two small groups
fail on their single key each; the reverse direction
(byte2 of byte3, full 224) also fails (24 keys, 18
violating).

Matched-by-cidx test across ordered cell pairs
(the AES-NUM-166 test generalised): the great group
has 8 cells (offsets 6796, 6864, 6932, 7000, 7068,
7136, 7204, 7272), each carrying exactly 27
single-cidx pairs, no ambiguity — 56 ordered cell
pairs × 27 matched rows = 1,512 rows per side.
Aggregated over all 56 ordered pairs, the aval
side is NOT A FUNCTION (415 keys, 331 violating)
and the bval side is NOT A FUNCTION (435 keys, 335
violating). Per ordered pair the verdicts are mixed
(derived at closing from the printed table): aval
FUNCTION in 28 of 56, bval FUNCTION in 32 of 56,
both FUNCTION in 16, both NOT in 12. The original
ordered pair (6864→6932) is FUNCTION on both own
sides in this test, as AES-NUM-166 measured for the
aval side.

Extension test: the original 6864→6932 aval mapping
has 19 keys (byte2 differences −191…112, byte3
values confined to {14, 15, 16}). Over the widened
aval rows, 81 rows carry one of those 19 byte2-diff
keys: 27 agree — exactly the original ordered
pair's own rows — and 54 contradict. 17 of the 19
keys take at least one contradictory byte3 value
somewhere in the widened rows; the two never
contradicted are −191 and −145. The widened rows
also use 396 byte2-diff keys beyond the original
19. The AES-NUM-166 regularity is therefore a
property of the single ordered cell pair
6864→6932 (and, per-pair, of about half the ordered
pairs), NOT a law of the group population; the
determinant of the 6864/6932 split stays NOT PROVEN.

The other groups: (19, 7712) supports only 6 matched
rows (3 cells × 1 pair), FUNCTION on both sides but
with 6 distinct keys for 6 rows — the trivial class,
no information. (14, 9992) supports NO matched rows
at all under the pairing definition (per-cell
single-cidx counts all 0; 5 ambiguous/multi entries
skipped): the pairing definition does not extend to
that group, recorded as NO SUPPORT rather than a
verdict.

## (iii) Runs 65 and 67 in full (with run 66)

Run 65 is a +0 singleton at A 501 / B 501 — in
place, one contiguous B block of one. Its B
neighbourhood is run 62's last three acts at
B 498–500 before it, run 67's pair at B 502–503
immediately after, and run 75's −111 act at B 504.

Run 66, the run between them in the run table, is
a −156 PAIR at A 502–503, one contiguous B block
at B 346–347 — far from the B 501 neighbourhood.
Its own B neighbourhood is run 63's −154 pair at
B 344–345 (the A 498–499 acts) before it and run
27's +6 acts from B 348 after it. In A order the
acts between run 62 and run 68 are runs 63 (−154
pair, B 344–345), 64 (+23 singleton, B 523), 65,
66 and 67.

Run 67 is a −2 pair at A 504–505, one contiguous
B block at B 502–503, immediately after run 65 at
B 501. Its B neighbourhood holds run 62's tail and
run 65 before it, run 75's −111 singleton act at
B 504 (A 615), run 28's +157 act at B 505 (A 348),
and run 68's +0 pair from B 506.

Mechanisms NOT PROVEN.

## Next

Slice 4.168 — the channel-disagreement
correspondence across both full contexts (every
A-only and B-only distinct act in contexts 86/210:
do they pair by (offset, size) at +shift
corresponding positions, and what are the channel
pairs?); the per-ordered-cell-pair FUNCTION pattern
in the great group (verdict as a function of the
ordered cell pair — offsets, distance, direction);
runs 63 and 64 in full. Host/artifact analysis
only — no physical child.
