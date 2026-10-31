# TASK_CONTRACT_4.150 (AES-NUM-150)

Scope (from AES-NUM-149's NEXT + TODO 4.150):
(i) the 3 control comparisons with the agreeing
(12, 7) profile read in full — AES-NUM-149 found
the 35 violating repeats' 50 control comparisons
carry differing-count distribution {7: 3, 9: 29,
10: 18}, with B byte 0 differing in 47 of 50, so
exactly 3 control comparisons have B byte 0 equal
and the agreeing profile (12 equal / 7 differing
over the 19 fields). Tests: those 3 comparisons
identified exactly (which violating repeat, which
pair-pair inside it) and printed in full with
their complete field comparisons (equal and
differing field names and values); for each, the
sibling comparisons inside the same repeat printed
with their profiles, so what makes the repeat
violating while this comparison is not is stated
from the numbers; and the 3 comparisons' differing
seven fields compared name by name against the
agreeing seven (A byte1, A byte2, A byte3, B byte1,
B byte2, B byte3, record cell) — identical set or
not, stated exactly. Any law NOT PROVEN unless
the numbers prove it; never invent one.
(ii) the 8 byte-0-differing near-miss pair-pairs
read against each other — AES-NUM-149 found 5
under (byte0, byte1, byte2) with A byte-0 steps
{4, 4, 8, 12, 64} and 3 under (byte0, byte2,
byte3) with steps {4, 4, 8}: the only informative
near-misses, since a near-miss differing anywhere
but byte 0 steps by 0 by construction. Tests: the
8 pair-pairs printed in full side by side (pairs,
sub-key values, groups, record counts, cells,
cell-third differences where both pairs carry a
single cell, A and B byte-0 differences,
B-minus-A byte-0 differences); the +4 cases
(2 + 2) against the non-+4 cases (8, 12, 64, 8)
on every printed field — any field on which the
+4 cases agree with each other and differ from
the others stated exactly, or none, stated
exactly; and the overlap between the two
sub-keys' byte-0-differing populations (the same
pair-pair counted under both sub-keys or not).
Any relation NOT PROVEN unless the numbers prove
it; never invent one.
(iii) gap 4 read in full against gaps 5 and 6 —
AES-NUM-149 found gap 4 carries the mapping set
((0, 1),) like gaps 5/6 but with the four-long
full sequence ((0, 1), (0, 1), (0, 1), (0, 1)).
Tests: gap 4 printed in full in the AES-NUM-145
form (run, step, bounding acts and channels,
shifts, distances, extents, skipped acts on both
sides, mapping set and full sequence); the
32-feature side-by-side tables gap 4 vs gap 5
and gap 4 vs gap 6 (equal / differing marked
exactly, with counts); and gap 4's skipped block
read act by act against gaps 5/6's single skipped
acts (sizes, offsets, channels, spacing) — what
makes its block four long while 5/6 are one long,
stated from the numbers. Any determination NOT
PROVEN unless the numbers prove it; never invent
one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

hef149.py lineage in ~/workspace/.verify-tmp/aesir149 is the base for hef150 (hef149 = the hef148 base plus arms149, sha256 cae5659d…); section149.txt + hef149.out are there and on the Pi (~/aesir-build/).

One bounded host-side child per contract.
