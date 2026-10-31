# TASK_CONTRACT_4.143 (AES-NUM-143)

Scope (from AES-NUM-142's NEXT + TODO 4.143):
(i) the missing-slot occupants as a population —
AES-NUM-142 found 28 missing lattice slots across
four repeating doubly-wed families, every one
occupied (22 by another repeating family's row, 6
by a singleton family's row, 0 by nothing). Tests:
for each of the 28 occupants, its own gap-2 tuple
read against its slot family's tuple (how many of
the three tuple acts are shared, in which
positions; its length and left position against
the family's; its loose distances and order
against the family's); counted exactly per slot
family and in total, with every occupant printed
in full. The six singleton occupants' keys read
against their slot families' keys in full. The
shared slot cidx 182 — the one slot missing from
two families ([146…] and its sister) and filled by
a single singleton row — read in full (its row,
both slot families, what else that singleton's
key's components share with each). Any relation
NOT PROVEN unless the numbers prove it; never
invent one.
(ii) the gap-by-gap insertion comparison —
AES-NUM-142 found the 19 A-side skipped acts and
the 19 B-side skipped acts are all one-context,
one-occurrence insertions, with the B-side
distance equal to the A-side distance in all 8
non-unit secondary gaps. Tests: for each of the
8 gaps, the A-side skipped acts and the B-side
skipped acts side by side (each act's offset,
size and channel, in gap order), counted and
compared exactly per gap (same sizes? same
channels? offset differences act by act?) and in
total. Any relation NOT PROVEN unless the numbers
prove it; never invent one.
(iii) B byte 0 against the four three-byte
sub-keys wed to the pair's status, group AND
record count jointly, over the full 224 pairs —
AES-NUM-142 tested the (status, group) joint wed
(the three byte-0 keys injective; (byte 1, byte 2,
byte 3) the same two violating repeats). Tests:
for each of the four three-byte sub-keys, B byte 0
tested against the value wed to (status, group,
record count) jointly — every wed value carried by
more than one pair counted exactly, with each
repeated value's pairs printed in full (A and B
words, B byte 0, status, group, record count,
records) and its agreeing / violating verdict;
the four joint-wed tests re-run inside the
SAME-only subset (44 pairs) separately, with the
same full printing of every repeat; and the two
(byte 1, byte 2, byte 3) joint-wed violating
repeats (if any survive the record-count wed)
re-read against their records' cells and centres
(each pair's cell, cidx span, centre span and
poscat pattern printed), or, if none survive, the
record counts of the four pairs of AES-NUM-142's
two violating repeats printed and compared. Any
determination NOT PROVEN unless the numbers prove
it; never invent one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

hef142.py lineage in ~/workspace/.verify-tmp/aesir142 is the base for hef143; section142.txt + hef142.out are there and on the Pi (~/aesir-build/).

One bounded host-side child per contract.
