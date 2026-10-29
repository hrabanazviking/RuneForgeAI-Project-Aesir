# TASK_CONTRACT_4.127 (AES-NUM-127)

Scope (from AES-NUM-126's NEXT + TODO 4.127):
(i) the (byte 3, byte 1 + byte 2) -> difference table
read as a per-byte-3 function of the sum in full, and
byte 0's own map — AES-NUM-126 established all 222
factoring fibres are trivial (each carries exactly
one distinct (byte 1, byte 2) pair; the two 2-pair
fibres differ only in byte 0) and the 167 difference
cells carry no constant-gap structure. Tests: for
each of the 61 A byte-3 values, print its keys
ordered by sum (byte 1 + byte 2) with their byte-3
differences in full; test monotonicity of the
difference as a function of the sum per byte-3
exactly (non-decreasing / non-increasing / neither,
with inversion counts and first inversions), and
the step structure of successive differences along
the sum order (step values in full per byte-3;
constant-step and stated step forms tested exactly,
failing forms recorded with counterexample counts);
and read byte 0's own map over the 224 pairs in
full — A byte 0 -> B byte 0 for every pair, its
determination status (is B byte 0 a function of
A byte 0 alone; of the (byte 3, byte 1, byte 2) key;
of the (byte 3, byte 1 + byte 2) key), each tested
exactly with violating keys named. Any closed form
NOT PROVEN unless the numbers prove it; never
invent one.
(ii) the near-geometric steps' wobble measured
exactly — AES-NUM-126 established all 324
consecutive delta ratios are pairwise distinct, lie
strictly in (0,1), span at most ~1.12e-6 within any
cidx-side, and every exact decay form F1-F5 fails.
Tests: per cidx and side (54 sequences), print the
6 ratios' exact deviations from the sequence's
median ratio in full (as exact fractions and in
ppm); and test stated integer-rounding geometric
forms exactly, the candidate forms stated here
before testing: for each sequence, candidate
rational r taken in turn as (R-a) the first ratio
delta(1)/delta(0), (R-b) the median of the 6
ratios, (R-c) the last ratio delta(6)/delta(5);
form ROUND: delta(k) == round(delta(0) * r^k) for
all k = 0..6; form FLOOR: delta(k) ==
floor(delta(0) * r^k) for all k = 0..6 — exact
rational arithmetic throughout, each form x
candidate recorded with its counterexample count
and first counterexample per sequence and pooled.
A rounding form that holds for a sequence is
recorded per sequence, never pooled into a law it
does not cover. Decay form NOT PROVEN unless the
numbers prove it; never invent one.
(iii) the displaced trio's eight contexts in wider
windows, the block's flanking acts profiled
corpus-wide, and the 41 non-occurrence-2 shared
acts — AES-NUM-126 established the three displaced
acts share exactly the eight cc9b9d1c contexts
{125, 128, 130, 143, 251, 261, 262, 265}, standing
as the consecutive block D2, D3, D1 in 128/251/265
immediately after (2817536, 24, 0) and immediately
before (1113626112, 24, 0), and split in the other
five; and that 127 of the 168 shared 114x251 acts
are occurrence-2, leaving 41 shared acts with
corpus-occurrence count >= 3. Tests: read wider
windows around every displaced occurrence in full
(the acts at positions -8..+8 around each of the
24 occurrences, boundaries clipped and marked);
compare the three block contexts' windows against
the five split contexts' windows in full; profile
the two flanking acts corpus-wide in full —
(2817536, 24, 0) (271 corpus occurrences per
AES-NUM-126) by occurrence class summary plus its
occurrences inside the eight trio contexts in
full, and (1113626112, 24, 0) (3 occurrences) in
full with neighbours; and read the 41 shared
114x251 acts that are NOT occurrence-2 in full,
grouped by corpus-occurrence-count class, with
both positions and position differences. Any
mechanism NOT PROVEN unless the numbers prove it;
never invent one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.

One bounded host-side child per contract.
