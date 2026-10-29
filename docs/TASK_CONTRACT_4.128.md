# TASK_CONTRACT_4.128 (AES-NUM-128)

Scope (from AES-NUM-127's NEXT + TODO 4.128):
(i) the ratio sequences' internal order and the
NEITHER tables' step census — AES-NUM-127 established
none of the 324 ratios equals its sequence median
(deviations nonzero everywhere, max ≈0.839 ppm) and
that 25 byte-3 values' difference tables are NEITHER
monotone in the sum. Tests: for each of the 54
cidx-side sequences, print its six ratios in k order
with their signs of deviation from the sequence
median in full; test monotonicity of the ratios in k
exactly (non-decreasing / non-increasing / neither,
inversion counts, first inversions) and the
deviation sign-pattern census across the 54
sequences (pattern multiset in full); and the pooled
step census of the multi-key byte-3 tables: every
successive step of every multi-key table pooled by
table class (NEITHER / non-decreasing /
non-increasing / constant), step-value multiset in
full, and step as a function of the sum tested
exactly (same sum → same step, violating sums
named; pooled and per byte-3). Any form NOT PROVEN
unless the numbers prove it; never invent one.
(ii) byte 0 within groups and the narrow pairs in
context — AES-NUM-127 established B byte 0 is a
function of no tested key, failing globally only on
the two narrow keys. Tests: B byte 0's determination
by the (byte 3, byte 1, byte 2) key computed
separately inside each of the map's three groups —
(group, cell) populations as established in the
lineage — with violating keys named per group; and
the narrow population's eight pairs read in their
full context (each pair's group, cell, cidxs,
offsets, and the records around them as printed by
the lineage). Any determination NOT PROVEN unless
the numbers prove it; never invent one.
(iii) the before-flank across all 271 contexts, the
30 class-271 acts, and the after-flank's following
pairs — AES-NUM-127 established (2817536, 24, 0)
occurs once in each of 271 cc9b9d1c contexts and is
followed by the displaced block in only three of
them, (1113626112, 24, 0) occurs exactly three times
block-exclusive, and 30 of the 41 non-occurrence-2
shared acts carry corpus-occurrence count 271.
Tests: the before-flank's position in every one of
its 271 contexts in full (position distribution;
position-from-end distribution) and the census of
the act following it in every context in full
(following-act multiset, grouped: the displaced
block's first act / other size-24 acts / all else);
the 30 class-271 acts read in full (each act's
positions in cidx 114 and cidx 251, its occurrence
positions summary, and whether the 30 stand in the
same relative order in both contexts — order test
exact); and the after-flank's following (24, 0) /
(24, 1) act pairs in the three block contexts
profiled corpus-wide in full (each act's corpus
occurrences and contexts). Any mechanism NOT PROVEN
unless the numbers prove it; never invent one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

One bounded host-side child per contract.
