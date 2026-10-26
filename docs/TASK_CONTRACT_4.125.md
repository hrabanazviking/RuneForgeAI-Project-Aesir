# TASK_CONTRACT_4.125 (AES-NUM-125)

Scope (from AES-NUM-124's NEXT + TODO 4.125):
(i) the (byte 3, byte 1, byte 2) determination read as a
map — AES-NUM-124 established lane 1's byte-3 signed
difference IS determined by (A byte 3, A byte 1, A byte 2):
222 keys, zero counterexamples over all 224 pairs, NOT
injective (the only two multi-pair keys are the narrow
sign-flip keys (128, 1, 176) and (128, 1, 178), each
carrying two group (14, 9992) pairs differing only in
byte 0, both byte-3 diff -128; within group (20, 32720)
the key is injective 216/216; group adds nothing, 222
keys with group too). Tests: read the determination as
a map — per-byte-3 tables over the full 224 pairs
(every key, its pairs, and its byte-3 difference,
counted exactly, never sampled); test factoring through
any arithmetic on (byte 1, byte 2) exactly (candidate
forms stated before testing; a form that fails on any
pair is recorded as failing, with its counterexample
count); and read the two narrow shared keys' byte-0
freedom against ALL eight narrow pairs (the (14, 9992)
and (19, 7712) sign-flip populations from AES-NUM-123:
five (14, 9992) pairs, XOR 0x80000000, diffs -2^31 x4 /
+2^31 x1, and three (19, 7712) pairs of the same shape).
Closed form NOT PROVEN unless the numbers prove it;
never invent one.
(ii) group (20, 32720)'s 189 trajectory steps as a
population — AES-NUM-124 established that group's
per-cidx trajectories across its eight disjoint offset
blocks (offs 6796-7272 step 68, 27 pairs per block, the
same 27 cidxs, all centre 127) change every value at
every step (8 distinct A / B / pairs / diffs / XORs per
cidx; constant anything 0/27) yet A and B both STRICTLY
INCREASE with offset for all 27 cidxs, and all 189
consecutive-block delta-A and delta-B values are
positive and pairwise distinct (delta-diff likewise
189 distinct). Tests: read the 189 delta triples
(delta-A, delta-B, delta-diff) per (cidx, block-step)
in full — every step, counted exactly; and test A at
block k+1 as a function of A at block k over the 189
steps (per-step and pooled function tests; a function
claim needs zero counterexamples over the population
it claims, and an injective key is recorded as vacuous,
not as a law). Step source NOT PROVEN unless the
numbers prove it.
(iii) the four break contexts' common core in full,
114x251's shared population in full, and 130x251's
110 inversions localized — AES-NUM-124 established the
four break contexts {114, 130, 251, 267} in cc9b9d1c
are all 842 acts, all distinct, on the identical high
band (30 @271 / 1 @1,058 / 2 @1,060), forming two
near-pairs: {114, 251} sharing 168 acts in 21 runs
(longest 54 at identical positions 130-183) and
{130, 267} sharing 111 acts in 19 runs, while every
cross-pair shares only 37-40 acts (the head 3-run and
the shared tail run holding both 267-side break pairs,
which stand at positions 792/801 in all four contexts;
the 144-side pairs' acts are absent from all four);
130x251 alone inverts (110 inversions of 780 shared
pairs); the non-shared spans between 130<->267's 19
runs total 739 acts on EACH side (103 in runs + 739 in
spans = 842 both sides). Tests: read the four contexts'
common core in full (acts shared by ALL four contexts,
in order, with positions in each); read 114x251's
shared population in full (all 168 shared acts, all 21
runs, the 54-act run at 130-183 in detail); and
localize 130x251's 110 inversions to the specific
shared acts that invert (which shared acts, their
positions in both contexts, and whether the inversions
concentrate in runs/spans). Any mechanism NOT PROVEN
unless the numbers prove it; never invent one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.

One bounded host-side child per contract.
