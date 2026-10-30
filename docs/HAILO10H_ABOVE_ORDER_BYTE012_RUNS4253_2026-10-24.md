# The above population's B-position order is three rank blocks with exactly two internal swaps (adjacent rank deltas +1 in 21 of 29 steps; the full pairwise discordance is 119 of 435, generated entirely by the 873M triple's third act at B 27 and the four low acts at B 747–750 plus the two swaps); the byte3 difference confined to {14, 15, 16} is a function of no byte0 field at any granularity and of no byte1/byte2 field except trivial near-pair-identity keys and one single-sided 19-key sample regularity; and runs 42 (+241 triple), 53 (+7 pair), 60 (−1 pair) and 61 (+1 pair) are each one contiguous B block while run 62 is a 53-act +3 backbone at A 438–497 / B 441–500, interrupted only by the seven non-single-positioned acts at B 447–448 and B 455–459 (AES-NUM-166)

Slice 4.166, worked under `docs/TASK_CONTRACT_4.166.md`
(contract published in the 4.165 closing commit @
4754ed27). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child, no device run of
any kind. All findings below are taken from the
sha-verified raw output; the few derived counts marked
as such were computed at closing from the run's own
printed tables, never sampled.

## Run and closing record

hef166.py (hef165.py verbatim as base plus the new
arms166) sha256
`3eb4a0d6d06b3fa3104b256407358b27778c5ae306896c11cd797c2c1bce9091`
(960,969 B); arms166 sha256
`2726466a78b83fb533b94ee1414c87149a204912dcccfc463985b3e8a7700181`
(15,133 B), its gzip sha256
`49cacf5ffb59c2fcbeb2e28deed785609482a27a71ef9700fe0f75e6a6517aa1`
(4,346 B). The base hef165.py was verified on the VM ==
the on-device hef165 (sha256 4118f3b6…) before
assembly. Crossing record: the gzipped arms crossed
in 12 sha-gated parts of 373 B (last part 243 B); all
12 verified on-device first try (two early parts were
re-sent after a parallel-write directory race in the
worker's own calls — sequential re-sends landed
sha-clean; no part was ever committed corrupt). The
assembled gzip, the decompressed arms and the
assembled hef166 sha256 all matched the VM exactly
on-device, and the script compiled on-device. The
ONE bounded host-side child was launched directly in
a detached tmux session on Mimir with the contract
corpus argv — the six hailo-ollama blobs in glob
order, then MiniLM — and finished with DONE166 as
its last line, exit marker 0, and a complete output,
err empty (0 B). Output hef166.out: 46,696 lines /
8,934,061 B, sha256
`9903595005a01ce4c9534e374821507cb54e43dfcffacf5e74a9362ee3591340`.
Prefix check: of its first 46,282 lines against
hef165.out, exactly ONE line differs (line 41,611,
frozenset element order only, same content and
length, the AES-NUM-150 variance); all other lines
byte-identical. Section 166: 414 lines / 59,264 B,
sha256
`fcea1d8d748740e3f642ce366cd0b4bb54567da1d0d14d865b28907d6606f74c`,
fetched by a device file read, verified on the VM to
exactly the on-device section sha and read in full.
Controls EXACT except one of the worker's own run
expectations (see (iii)): the runs control printed
lengths [3, 2, 2, 2, 53] against the worker's
expected [3, 2, 2, 2, 3] for run 62 — the expectation
was taken from AES-NUM-165's ±3 B neighbourhood of
run 48, which shows only run 62's first three acts;
the run itself is 53 acts. Raw output kept on the Pi
at ~/aesir-build/ (hef166.out, hef166.py, arms166.py,
section166.txt); local lineage in
~/workspace/.verify-tmp/aesir166.

## (i) The order relation in full

The 30 above acts in B-position order carry offset
ranks [725, 724, 728, 729, 730, 731, 732, 733, 734,
735, 736, 737, 738, 739, 740, 741, 742, 743, 726,
744, 745, 746, 747, 748, 749, 750, 722, 721, 723,
727]. Adjacent rank deltas (29 steps): +1 in 21,
−1 in 2, and one each of −28, −17, +2, +18 and +4 in
2 (distribution {−28: 1, −17: 1, −1: 2, 1: 21, 2: 1,
4: 2, 18: 1}); signs 25 positive / 4 negative / 0
zero. The four negative adjacent steps are exactly
B 0→1 (−1, the triple swap), B 26→27 (−17, the
triple's third act), B 738→747 (−28, the drop to the
low tail acts) and B 747→748 (−1, the ceiling swap).
Rank delta is NOT A FUNCTION of position gap (gap 1
alone takes the five deltas {−17, −1, 1, 2, 4}) and
position gap is NOT A FUNCTION of rank delta; delta
equals gap in only 13 of 29 steps.

Full pairwise discordance (derived at closing from
the printed list): 119 of 435 pairs are discordant,
and every discordant pair is accounted for by three
blocks in B-position order — block 1, the triple
head at B 0/1 with ranks 725/724 (one internal swap,
1 discordant pair); block 2, the 23 acts at B 5–738
(main block, outliers and gap-8 tail) with ranks
728–750 strictly increasing in B position (no
internal discordance); block 3a, the triple's third
act alone at B 27 with rank 726, discordant against
the 16 main-block acts before it and the 3 low acts
after it whose ranks it exceeds; block 3b, the four
low acts at B 747–750 with ranks 722/721/723/727,
discordant against all 26 preceding above acts for
ranks 722/721/723 and against the 23 block-2 acts
for rank 727, plus their one internal swap
(747/748). Cross-block counts 16 + 3 + (26×3 + 23)
= 117, plus the 2 internal swaps = 119 exactly.

Reversal 1 (the 873M ladder triple): in offset order
the triple is rank 724 at B 1 (873198592, 24, 0),
rank 725 at B 0 (873199104, 24, 1), rank 726 at
B 27 (873199616, 24, 2); of its three pairs only
(0, 1) is discordant. The nine shared acts between
them in the B 0–27 window are all run 0 in place
(shift +0) with offset ranks 38–46 — all BELOW the
whole triple; in offset order the head window reads
the nine shared acts first, then the triple, then
the main block's window members (ranks 728–743).

Reversal 2 (the just-past-ceiling pair): its full
neighbourhood B 744–750 in position order is run
102 shared at B 744 (rank 32), B 745 (rank 33) and
B 746 (rank 720, the below-boundary top act), then
the four above acts B 747 (rank 722), B 748 (rank
721), B 749 (rank 723), B 750 (rank 727). In offset
order B 748 precedes B 747; the pair is discordant
(747 rank 722 vs 748 rank 721), and it is the only
discordance inside B 744–750.

## (ii) The byte3 confinement against byte0–byte2

The confinement reproduces exactly: A-side byte3
differences {14: 4, 15: 13, 16: 10}, B-side
{14: 2, 15: 20, 16: 5}. The matched byte0
differences (6932 minus 6864) are themselves
confined on both sides to the eleven multiples of
32 in {−192, …, +192}; the matched byte1
differences spread over 25 distinct values and the
matched byte2 differences over 19 (A) / 24 (B)
distinct values — no byte3-like three-value
confinement in any of byte0–byte2 (the A byte2
difference does repeat −145 four times and +110
three times; recorded, not a confinement).

Function verdicts, both byte3 differences as
targets: every byte0-based test is NOT A FUNCTION —
the four cells' byte0 values singly (4–7 keys,
3–4 violating each), the matched byte0 differences
(11 keys), the within-pair byte0 differences
(7/11 keys) and the pairs of byte0 values (15/19
keys). For byte1 and byte2, every FUNCTION verdict
carries 24–27 keys over the 27 matches — the
near-pair-identity trivial class that earns nothing
toward a determinant (6864 B byte1, 27 keys, both
sides; the pairs of byte1 and of byte2 values,
26–27 keys; the within-pair byte2 differences,
27 keys) — with three 24–25-key exceptions of the
same class (matched B byte1 difference, 25 keys,
both sides FUNCTION; matched A byte1 difference,
25 keys, A side only, its B side failing on one
key). The single FUNCTION verdict below that class
is the matched A byte2 difference → the A byte3
difference: 19 keys, 0 violating — a genuine
sample-level regularity on these 27 matches, but
single-sided (its B counterpart fails, 2 violating
keys of 19) and recorded as such; it does not
establish a determinant. All remaining byte1/byte2
single-value and difference tests are NOT A
FUNCTION (violating keys 1–2 at 24–27 keys).
Determinant NOT PROVEN.

## (iii) Runs 42/53/60 and 61/62 in full

Run 42 is a +241 triple at A 396–398, one contiguous
B block at B 637–639; its B neighbourhood is run
84's −5 triple at B 634–636 before it, run 44's
+239 singleton at B 640 immediately after, then run
85 (−1) from B 641.

Run 53 is a +7 pair at A 422–423, one contiguous B
block at B 429–430; its neighbourhood holds run
52's +5 tail at B 426, an intruding +203 pair of
run 8 at B 427–428, run 43's +32 pair at B 431–432
immediately after, and run 60's head at B 433.

Run 60 is a −1 pair at A 434–435, one contiguous B
block at B 433–434 — directly after run 43 and
directly before run 23's +135 pair at B 435–436,
with run 61 following at B 437.

Run 61 is a +1 pair at A 436–437, one contiguous B
block at B 437–438; run 48's +32 pair follows at
B 439–440 and run 62 begins at B 441.

Run 62 is a +3 run of FIFTY-THREE acts — the long
backbone after run 48, not a three-act flank. Its
A extent is 438–497 (skipping A 444–445 and
A 452–456, whose acts are not its members) and its
B extent is 441–500. It is NOT one contiguous B
block: its gaps are exactly B 447–448 (two acts,
(785868800, 1552, 2) and (785870352, 14864, 2), not
shared single-positioned) and B 455–459 (five acts,
all channel 0, not shared single-positioned); from
B 460 to B 500 it is a clean 41-act contiguous
stretch. It is followed at B 501 by run 65's +0
singleton (A 501) and run 67's −2 pair from B 502.
The worker's control expectation of length 3 —
inherited from AES-NUM-165's ±3 window around run
48 — is corrected here, the same failure class as
AES-NUM-164's run-23 and AES-NUM-165's runs-43/48
prose corrections. Mechanisms NOT PROVEN.

## Next

Slice 4.167 — run 62's two internal gaps in full
(the B 447–448 and B 455–459 non-single-positioned
acts against contexts A and B in full; the skipped
A acts at A 444–445 and A 452–456 in full); the
matched A byte2-difference → byte3-difference
regularity against the wider pair population (all
224 pairs of the (20, 32720) group, and the other
groups); runs 65 and 67 in full. Host/artifact
analysis only — no physical child.
