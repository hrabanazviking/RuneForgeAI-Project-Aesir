# TASK_CONTRACT_4.149 (AES-NUM-149)

Scope (from AES-NUM-148's NEXT + TODO 4.149):
(i) the 7 agreeing repeats of the refining joints
read record by record over the 216 violating-cell
pairs — AES-NUM-148 found 7 keys of exactly 2 pairs
each (14 pairs), the two joints keying every pair
identically, and every agreeing repeat's two pairs
living in different cells. Tests: for each agreeing
repeat, its two pairs printed in full and compared
field by field (A word bytes, B word bytes, status,
diff, group, record count, and every record field —
cell, cidx, idx, n, centre, poscat, in37): the
differing-field count and the equal-field count
printed exactly per repeat, with the differing
fields named; the same comparison run over the 35
violating repeats as the control population (per
repeat, the same counts), so the agreeing repeats'
similarity is measured against the violating
repeats' similarity and not asserted in isolation.
Any law NOT PROVEN unless the numbers prove it;
never invent one.
(ii) the near-miss census for the two injective
three-byte sub-keys — AES-NUM-148 found
(byte0, byte1, byte2) and (byte0, byte2, byte3)
each injective alone over the full 224 pairs (224
distinct values, no pair-pair sharing either).
Tests: for each of those two sub-keys, every
unordered pair-pair whose sub-key values differ in
exactly one byte position (a Hamming-1 near-miss),
printed with its sub-key values, the position and
size of the differing byte, its A and B byte-0
differences, its B-minus-A byte-0 differences, and
its cell-third difference where both pairs carry a
single cell; the distributions of A byte-0
differences over the near-misses printed exactly
per sub-key, split by which byte position differs.
Any relation NOT PROVEN unless the numbers prove
it; never invent one. (Byte-0 differences under a
near-miss differing at byte 0 are not forced to 0
and not forced to +4; both are measured, neither
assumed.)
(iii) gaps 5 and 6 read in full against each other
over all 8 gaps' records — AES-NUM-144…148 found
gaps 5/6 are the sole agreeing repeat of every
mapping determinant tested (channels, sizes-wed,
count-wed, joint tuples), with gaps 3/7 receiving
the full feature-table treatment in AES-NUM-145.
Tests: gaps 5 and 6 printed in full side by side
(run, step, bounding acts and channels, shifts,
distances, extents, skipped acts on both sides,
mapping set and full sequence); a feature table in
the AES-NUM-145 form (every bounding-side and
skipped-act feature of the two gaps, equal /
differing marked exactly, with the equal and
differing counts); and the mapping as a function
of the features the two gaps SHARE, stated exactly
(the shared-feature keys and their verdicts over
all 8 gaps). Any determination NOT PROVEN unless
the numbers prove it; never invent one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

hef148.py lineage in ~/workspace/.verify-tmp/aesir148 is the base for hef149 (hef148 = the hef147 base plus arms148, sha256 db9f86de…); section148.txt + hef148.out are there and on the Pi (~/aesir-build/).

One bounded host-side child per contract.
