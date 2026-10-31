# TASK_CONTRACT_4.160 (AES-NUM-160)

Scope (from AES-NUM-159's NEXT + TODO 4.160):
(i) the B 615 intruder in full —
AES-NUM-159 measured a single act (787733504,
32784, 2) at A position 522, shift +93,
secondary run 72, sitting in B between run 74's
tail (B 614) and the +432 block (B 616). Tests:
secondary run 72 in full (its acts, A/B extents,
shift, length); the intruder act's A neighbourhood
(A positions 518-526 printed in full: acts,
B positions, shifts, runs); where run 72's other
acts sit in B; run 72's relation to runs 73/74
(its secondary-run neighbours in A order). Any
law NOT PROVEN unless the numbers prove it;
never invent one.
(ii) the partner-cell correspondence tested
census-wide — AES-NUM-159 measured, for the root
triangle, partner A 4092dbce in the neither
40f079cf's cell (20, 32720, 6864) and partner B
40fcb4ce in the root 40f019ce's cell (20, 32720,
6932). Tests: for EVERY neither partner of every
three (the AES-NUM-156 population), print the
partner's cell, its own listings, and the cells
of every vertex it touches; count how many
partners sit in a touched vertex's cell, how
many in a cell of a vertex they do not touch,
and how many in a cell no touched vertex carries;
the same test for the threes themselves against
their partners. Any law NOT PROVEN unless the
numbers prove it; never invent one.
(iii) the first-skipped past-left-end values of
all 8 gaps as one table — gap 4's value is 464
(AES-NUM-159); gaps 3 (448), 5 (480) and 6 (448)
are recorded; gaps 1, 2, 7 and 8 are not yet
tabulated on this measure. Tests: for every gap
1-8, from its own record: first skipped offset
minus (left offset + left size) on side A and
side B separately, the two sides compared; the
8 values as one population against run, step,
distance, skipped count and mapping. Any
determination NOT PROVEN unless the numbers
prove it; never invent one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

hef159.py lineage in ~/workspace/.verify-tmp/aesir159 is the base for hef160 (hef159 = the hef158 base plus arms159, sha256 1e25470f…); section159.txt + hef159.out are there and on the Pi (~/aesir-build/).

One bounded host-side child per contract.
