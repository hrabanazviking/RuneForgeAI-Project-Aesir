# TASK_CONTRACT_4.126 (AES-NUM-126)

Scope (from AES-NUM-125's NEXT + TODO 4.126):
(i) the (byte 3, byte 1 + byte 2) factoring's fibres in
full and the map's difference fibres — AES-NUM-125
established lane 1's byte-3 signed difference IS
determined by (A byte 3, A byte 1 + A byte 2) at 222
keys over the 224 pairs, with NO compression (same key
count and same two multi-pair keys as the (byte 3,
byte 1, byte 2) map), and that the map carries 167
distinct (byte 3, difference) combinations against its
222 keys. Tests: read the factoring's fibres in full —
for every (byte 3, byte 1 + byte 2) key, its pairs and
their (byte 1, byte 2) sets, counted exactly, never
sampled; read the map's difference fibres in full —
for every one of the 167 (byte 3, difference) cells,
the keys that land in it (which keys share a cell, and
how many pairs each carries); and test whether a
fibre's (byte 1, byte 2) sets carry arithmetic
structure, with the candidate forms stated before
testing (within a factoring fibre: the byte-1 values'
sorted gaps — constant-gap / arithmetic-progression
test, gap gcd, range against fibre size; within a
difference cell: the keys' (byte 1 + byte 2) sums —
sorted gaps, constant-gap test, gap gcd; a form that
fails on any element is recorded as failing, with its
counterexample count). Arithmetic structure NOT
PROVEN unless the numbers prove it; never invent one.
(ii) group (20, 32720)'s shrinking steps read as
sequences — AES-NUM-125 established all 189 delta
triples are pairwise distinct, delta-A and delta-B
are each STRICTLY DECREASING per cidx (27/27 cidxs,
7 steps each), and per-step-index delta ranges
descend, pairwise disjoint for steps 0-2. Tests: read
the per-cidx delta-A / delta-B ratios and second
differences in full over the 189 steps (for each of
the 27 cidxs: the 7 delta-A and 7 delta-B values, the
6 consecutive ratios of each as exact reduced
fractions, and the 6 second differences of each —
delta-A(k+1) - delta-A(k), likewise B — every value
printed, counted exactly); and test stated decay
forms exactly, the forms stated here before testing:
F1 per-cidx geometric (one rational ratio per cidx
carries all 6 of its steps, A and B separately);
F2 pooled geometric (one rational ratio carries all
189 steps); F3 per-cidx constant second difference
(delta sequence arithmetic per cidx); F4 per-cidx
delta-B / delta-A ratio constant over its 7 steps;
F5 per-cidx delta proportional to level (delta-A(k)
 / A(k) constant over its 7 steps, likewise B). A
form that fails on any step is recorded as failing,
with its counterexample count and first
counterexample. Decay form NOT PROVEN unless the
numbers prove it; never invent one.
(iii) the three displaced acts' corpus-wide profiles
in full, 251's closing segment against 130's head in
full, and the occurrence-2 exclusivity population
around the 54-act run — AES-NUM-125 established
130x251's 110 inversions are generated entirely by
three displaced acts: (1052257280, 24, 2) at 130
pos 6 / 251 pos 824, (1062814208, 24, 0) at 130
pos 7 / 251 pos 822, (1062813184, 24, 1) at 130
pos 197 / 251 pos 823, each of size 24 with corpus
occurrences 8; and that the 54-act run shared by
contexts 114 and 251 at identical positions 130-183
consists entirely of acts with corpus-occurrence
count exactly 2. Tests: profile each displaced act
corpus-wide in full — all 8 occurrences each, with
artifact, context (cidx), position, context length,
and the neighbouring acts at position-1 and
position+1 (or the context boundary); read 251's
closing segment (positions 818-841, 24 acts) against
130's head (positions 0-10, 11 acts) in full — every
act with its position and corpus-occurrence count,
the cross-membership between the two segments, and
the displaced acts' places in both; and read the
occurrence-2 exclusivity population around the
54-act run in full — every act occurring exactly
twice in the corpus with one occurrence in context
114 and one in context 251 (all in cc9b9d1c), in
114-position order, with both positions, the runs
this population forms in the shared order, and the
54-act run's place inside it (how many of the 168
shared acts are occurrence-2; where the
non-54-run occurrence-2 acts stand). Any mechanism
NOT PROVEN unless the numbers prove it; never
invent one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.

One bounded host-side child per contract.
