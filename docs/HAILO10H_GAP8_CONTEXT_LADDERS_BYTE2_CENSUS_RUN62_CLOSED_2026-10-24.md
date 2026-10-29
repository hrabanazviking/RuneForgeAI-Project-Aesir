# Gap 8's ladders are measured against their full contexts: side A's skipped rungs sit inside context A's longest 512-chain (12 rungs, 791,775,232–791,780,864, which does not end at the right bound — it resumes after the bound's region and ends at the context's largest residue-0 offset), while side B's four rungs are an isolated 4-chain at the very top of context B's residue-0 offsets (nearest neighbour 261,632 bytes below, none above — not a wider ladder); the byte2-differing Hamming-1 census is far larger than its byte-0 mirror (85 listings, 84 distinct pair-pairs, 96 individual pairs, exactly one pair-pair under both sub-keys) and partly inverts the (1, 128) roles (the non-members earn 3 and 1 listings, two of the four members earn none); and run 62 is closed — its two gaps share exactly the same 9 run-frame features of 32 that run 74's five gaps shared, and split on the other 23 (AES-NUM-153)

Slice 4.153, worked under `docs/TASK_CONTRACT_4.153.md`
(contract published in the 4.152 closing commit @
3d0fa38f). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child, no device run of
any kind. All findings below are taken from the
sha-verified raw output; the few derived counts marked
as such were computed at closing from the run's own
printed tables, never sampled.

## Run and closing record

hef153.py (hef152.py verbatim as base plus the new
arms153) sha256
`247c36deaf1006070759dc9f576ef0e83f3d35e96a3063c2b87219e9c9588262`
(771,579 B); arms153 sha256
`b914eedeb71e82c6645dea30a6ac88d5bc16981f7ab75c7b1a83417616ae4c3e`
(18,631 B), its gzip sha256
`33f877270b9b9602e5da470576cbc8a0369f88fa8018c83cbeb4f9c63f455358`.
The base hef152.py was verified on-device ==
VM (sha256 55d22a85…) before assembly. Crossing
record: the gzipped arms crossed in 15 sha-gated
parts of 373 B (last part 334 B); every part's
sha256 verified on-device first try, no part
rejected. The assembled gzip, arms and hef153
sha256 all matched the VM exactly on-device, and
the script compiled on-device (py_compile OK).

The ONE bounded host-side child was launched in a
detached tmux session on Mimir with the contract
corpus argv — the six hailo-ollama blobs in glob
order, then MiniLM — via the sha-gated runner
run153.sh (sha256
`cbba4ac093afe598ee13ceb7c5cc4046d506434c463b596d696634f4abe23a8e`),
and finished with DONE153 as its last line, exit
marker 0, error channel empty. Output hef153.out:
43,113 lines / 8,337,522 B, sha256
`e810de216a6d9dca4d57840a735ea025d0a4781d01f6d3df65fef566dbd30555`.
Prefix check, stated honestly: of its first
42,409 lines against hef152.out, exactly ONE line
differs (line 41,611, in the AES-NUM-150 overlap
print) and only in the internal order of one
frozenset's elements — same content, same length
(448 B); the same frozenset-order variance was
recorded in AES-NUM-150's own rerun. Every other
prefix line is byte-identical. Section: 704 lines
/ 166,723 B, sha256
`5a114a6d6eeb19962f22ce2f72978c620a735c65995a9c7098e75b658282b909`
(gzip sha256
`e26c48384f0bfbff68cb08d416e72942ac541f39eb30f1ce7bb59124942d6a56`
kept on the Pi); the section returned as the
on-device gzip through a time-boxed on-device HTTP
server and the tunnel proxy, the gzip sha256
matching on-device exactly and the decompressed
section matching the on-device section sha256
exactly. Controls EXACT: every controls-echo
expectation from slices 4.119–4.152 reproduced,
including the 6 distinct near-miss pair-pairs from
the 4.151 arms. Raw output kept on the Pi at
~/aesir-build/ (hef153.out, hef153.py, arms153.py,
section153.txt); local lineage in
~/workspace/.verify-tmp/aesir153.

## (i) Gap 8's two skipped regions against their contexts in full

Every anchor in gap 8 sits at offset residue 0 mod
512: the shared LEFT bound (791,776,768), the shared
RIGHT bound (768,609,280), and all four of side B's
skipped offsets. Side A's skipped offsets are
residue 24 for the first (791,776,792, the
bound-contiguous act of AES-NUM-152) and residue 0
for the remaining three.

**Context A** (art 5ab3537d, cidx 86) carries 37
residue-0 24-byte acts, 37 distinct offsets, range
262,656..791,780,864. Their consecutive distinct-
offset differences are 512 in 21 of 36 steps; the
512-chains number 16, with lengths {1: 12, 3: 1,
4: 1, 6: 1, 12: 1}. The longest chain is exactly
gap 8's neighbourhood:

791,775,232 → 791,775,744 → 791,776,256 →
791,776,768 (LEFT bound) → 791,777,280 →
791,777,792 → 791,778,304 (the three ladder
skipped acts) → 791,778,816 → 791,779,328 →
791,779,840 → 791,780,352 → 791,780,864 —
12 rungs, every step exactly 512.

So side A's ladder does **not** end at the right
bounding act. Positionally, the chain's first
seven rungs are the approach acts (positions
729–731), the bound (732) and the skipped rungs
(734–736); the context then detours through the
right bound's own region, and the ladder resumes
at positions 744–748 with its last five rungs
(791,778,816..791,780,864, the run's final acts).
The chain ends at 791,780,864 because that is the
largest residue-0 offset in the context — no
further rung exists above it. The right bound
carries its own short chain in both contexts:
768,609,280 → 768,609,792 → 768,610,304 →
768,610,816 (4 rungs), preceded by a 12,920,320
byte gap from the previous distinct residue-0
offset (755,688,960).

**Context B** (same art, cidx 210) carries 38
residue-0 24-byte acts, 38 distinct offsets, range
262,656..1,196,445,696; its 512-chains number 22
with lengths {1: 15, 2: 2, 3: 1, 4: 4}. Side B's
skipped block is one of the 4-chains —
1,196,444,160 → 1,196,444,672 → 1,196,445,184 →
1,196,445,696 — and it is **isolated**, not a
window on a wider ladder: the previous distinct
residue-0 offset in context B is 261,632 bytes
below its first rung (1,196,182,528), no rung
exists at 1,196,443,648 (one step below), and
there is no next distinct offset at all — its
last rung is the largest residue-0 offset in the
context. In context B the shared approach chain
stops at the bound (791,775,232..791,776,768,
4 rungs); the next distinct residue-0 offset is
791,778,816 at +2,048 (position 746), because
side A's ladder rungs are exactly what context B
does not carry there.

Cross-context, the two regions are disjoint:
context A carries none of side B's four skipped
offsets (nearest distinct offset 404,663,296
bytes below them), and context B carries none of
side A's three ladder rungs. In the run itself
(run 102), 15 of its 58 acts are 24-byte
residue-0 acts, at the same offsets under all
three anchors (the anchors share residue 0, so
the three run scans coincide). Mechanism NOT
PROVEN; the arithmetic above is exact.

## (ii) The byte2-differing Hamming-1 census over the full 224

The mirror of the AES-NUM-150 byte-0 census is an
order of magnitude larger: **85 listings** — 12
under (byte0, byte1, byte2) and 73 under
(byte0, byte2, byte3) — against the byte-0
census's 8 (5 + 3). The 85 listings carry **84
distinct pair-pairs**: exactly ONE pair-pair
appears under both sub-keys — the byte2
177 ↔ 178 pair at byte0 20 (listings 5 and 20),
which is the non-member/member pair of the
(1, 128) population. 96 distinct individual pairs
of the 224 appear in any byte2 listing (170
slots; the most-listed individual pair appears
6 times).

The step structure does not mirror byte-0's
small ladder: the 85 A byte2 steps are almost
all distinct (only +1 ×3, +2 ×3, −92 ×2, −59 ×2,
+22 ×2, +38 ×2, +53 ×2, +107 ×2 repeat), ranging
−194..+213. Under (byte0, byte1, byte2) all 12
steps are positive and small for the (1, 128)
cluster (+1, +2, +1, +2 at byte0 20/68) but large
elsewhere (+24..+197); under (byte0, byte2,
byte3) the steps scatter over the full range.
B byte0 steps: 0 in 28 of 85, −128 in 15, +128
in 7, the rest scattered. Status pairs:
(DIFF, DIFF) 41, (SAME, DIFF) 16, (SAME, SAME)
19, (DIFF, SAME) 9 — byte2 neighbours usually
disagree on B byte0, where byte-0 neighbours
never did in the (14, 9992) ladder. Group pairs:
79 of 85 are (20, 32720) × (20, 32720); the
(19, 7712)/(14, 9992) population contributes 5
listings, all among its own six pairs.

Where the (1, 128) population sits in this
census **partly inverts** its byte-0 position.
In the byte-0 census every member earned a
listing under both sub-keys and the non-members
earned none (AES-NUM-152). Here the listing
counts are: non-member byte2 177 at byte0 20 —
**3** (partners: the byte2-176 byte3-0 pair at
byte0 20, and the byte2-178 member at byte0 20
under both sub-keys); non-member byte2 160 at
byte0 68 — **1** (partner byte2 162 at byte0
68); member byte2 178 at byte0 20 — **3**;
member byte2 178 at byte0 24 — **0**; member
byte2 176 at byte0 28 — **0**; member byte2 176
at byte0 32 — **1** (partner the byte2-211 pair,
step +35, listing 6). Population totals are
equal — members 4 listings, non-members 4 — but
the distribution is the reverse of byte-0's:
membership in a byte-0 pair-pair neither earns
nor blocks a byte2 listing. Any law NOT PROVEN;
the census above is complete over the 224.

## (iii) Run 62's gaps 1 and 2 against each other — run 62 closed

Gaps 1 and 2 are all of run 62's gaps in the
records (secondary run 62, shift +3, length 53,
extents A 438..497 / B 441..500). Read in full:

| | gap 1 | gap 2 |
|---|---|---|
| step | 5 | 11 |
| distances A/B | 3/3 | 6/6 |
| skipped A/B | 2/2 | 5/5 |
| skipped offsets A vs B | identical | identical |
| skipped sizes | (1552, 14864) | (26128, 32784, 26128, 32784, 18448) |
| advances vs preceding sizes | equal (1552) | equal (all four) |
| channels A / B | (1, 1) / (2, 2) | (2×5) / (0×5) |
| mapping | ((1, 2),) ×2 | ((2, 0),) ×5 |
| first skipped beyond bound+size | 448 | 464 |
| LEFT bound | (785842224, 26128, 1) | (786030624, 32784, 2) |
| RIGHT bound | (785885696, 26128, 2) | (786200576, 1552, 0) |

The side-by-side 32-feature table (the
AES-NUM-149 feat_row form) totals **9 equal /
23 differing** — and the 9 shared features are
exactly the run-frame list that closed run 74
in AES-NUM-152: run, run shift, run length, run
A first pos, run A last pos, run B first pos,
run B last pos, left shift, right shift. The
two gaps split on the other 23 (step, both
bounding acts in all forms, both distances,
both position pairs, both skipped counts,
sizes, offsets and channels, both mappings,
both surrounding windows). Step difference 6;
total skipped 7/7. Run 62 is CLOSED in the same
form as run 74: a two-gap run whose gaps share
nothing but the frame they sit in. Mechanisms
NOT PROVEN.

## Next

Slice 4.154 — the two contexts' residue-0 offset
sets in full against each other (37 vs 38
distinct offsets: shared, A-only, B-only, and
their positional order in each context); the
byte2 census's hub pairs (the individual pairs
carrying ≥4 listings) read as one population;
run 102's single gap (gap 8) read against the
run-62/run-74 frame (the 9 shared features) as a
one-gap closure. Host/artifact analysis only.
