# TASK_CONTRACT_4.131 (AES-NUM-131)

Scope (from AES-NUM-130's NEXT + TODO 4.131):
(i) the gap-fillers as a population — AES-NUM-130
established the three wide gaps are shape-constant
(gap 0 sizes (248, 176), gap 1 (256, 176), gap 2
(328, 328, 328)) but act-variable (34 / 30 / 87
distinct between-tuples; second-minus-first offset
+248 in 187 of 271 gap-0 contexts and +512 in 46;
+256 in 257 gap-1 contexts; consecutive +328 steps
in 189 / 221 gap-2 contexts). Tests: for each gap,
the second (and in gap 2 the third) act as a
function of the first act, tested exactly over the
271 contexts (violating first acts named in full);
the shared second acts in full (which distinct
first acts each second act serves, in how many
contexts — e.g. gap 0's second act (1198581760,
176, 0) in 54 contexts); and every distinct gap act
read against the contexts' own bodies: for each
gap act, in how many of its contexts does it also
stand somewhere outside its gap, and does it stand
in any context where it is not a gap act (gap-only
or body acts too, counted exactly). Any relation
NOT PROVEN unless the numbers prove it; never
invent one.
(ii) the outlier's 32-act run read corpus-wide —
AES-NUM-130 established cidx 143 holds L0
(2727936, 24, 2) at position 518, from-end 87,
with 32 large acts (sizes 28168–32784, offsets
ascending from 1224648704) between it and the
block, L1 (2774016, 24, 1) inside that span at
position 549, distance 2. Tests: the 32-act
sequence (in full, in order) searched as a
consecutive run in every context of every
artifact (exact occurrences counted, contexts
named); its acts read individually corpus-wide
(corpus occurrence count of each of the 32, and
whether they stand in that relative order anywhere
else, inversions counted); and L0's neighbourhood
in the modal contexts by contrast (the modal joint
(d0, d1) populations (1, 3) x46 and (3, 1) x43:
the acts standing immediately before and after
each loose act in those contexts, in full census).
Any recurrence NOT PROVEN unless the numbers prove
it; never invent one.
(iii) the near-miss sub-key collisions in full,
with B byte 0 tested against the two-byte keys —
AES-NUM-130 established (byte 3, byte 1) fails the
status test on exactly (249, 44) and the B-value
test on exactly (252, 84) -> {8, 120}; (byte 3,
byte 2) fails status on exactly (249, 181) with
the B test clean; (byte 1, byte 2) is status-clean
with B failing on exactly (128, 146) -> {128, 160}.
Tests: each named collision read in full (every
pair carrying the value: A and B words, byte-0
status and values, its group, its records and its
cell(s)); and B byte 0 itself (not only the
identity status) tested as a function of each
two-byte sub-key of the A word — (byte 3, byte 1),
(byte 3, byte 2), (byte 1, byte 2), (byte 0,
byte 1), (byte 0, byte 3) — computed exactly over
the great group's 216 pairs (distinct values,
violating values named in full with their B byte 0
sets). Any determination NOT PROVEN unless the
numbers prove it; never invent one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

One bounded host-side child per contract.
