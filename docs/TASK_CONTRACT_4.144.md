# TASK_CONTRACT_4.144 (AES-NUM-144)

Scope (from AES-NUM-143's NEXT + TODO 4.144):
(i) the missing-slot occupants read against their
OWN families — AES-NUM-143 read each of the 28
occupants against its SLOT family (positions 0/1
of the modal tuple shared 28/28, position 2
differing in 25, loose d0 differing in 25, the two
25-sets overlapping in 23). Tests: for each
occupant, the symmetric comparison against its
own doubly-wed family (the family its own key
names; for the 22 repeating-row occupants that
family's modal gap-2 tuple per position and its
key components; for the 5 distinct singleton
rows, the statement that their own family is
themselves alone), counted exactly per occupant
class and in total, with every occupant printed
in full; and the slot-family comparison and the
own-family comparison cross-tabbed for position 2
and for loose d0 (both match / slot only / own
only / neither), counted exactly. Any relation
NOT PROVEN unless the numbers prove it; never
invent one.
(ii) the per-gap channel mapping read against
the gaps' bounding acts, and gap 8's B-side
neighbourhood — AES-NUM-143 found gaps 1–7
channel-uniform per side with A→B mappings 1→2,
2→0, 2→0, 0→1, 0→1, 0→1, 1→2 and zero paired
offset differences, while gap 8 paired equal
channels at offset differences +404,667,368 /
+404,667,392 (×3). Tests: for each of the 8 gaps,
the left and right bounding acts' channels (in A
and in B), the run shift at the gap, and the
gap's A→B channel mapping printed side by side
and counted (mapping as a function of the
bounding channels / shift, tested exactly); and
gap 8's B-side insertion read in context B in
full (the acts immediately before and after the
insertion point in B, with offsets, sizes and
channels, and the B-side skipped acts' offsets
against their B neighbours). Any relation NOT
PROVEN unless the numbers prove it; never invent
one.
(iii) B byte 0 against the four three-byte
sub-keys wed to status, group, record count AND
cell jointly, over the full 224 pairs —
AES-NUM-143 found the triple wed leaves the same
two (byte 1, byte 2, byte 3) violating repeats,
whose pairs differ on the printed record evidence
only in the cell (each pair carries exactly one
cell; the cells differ in their third component:
1744/6944 and 4336/9832). Tests: for each of the
four three-byte sub-keys, B byte 0 tested against
the value wed to (status, group, record count,
cell) jointly — every wed value carried by more
than one pair counted exactly, with each repeated
value's pairs printed in full (A and B words, B
byte 0, status, group, record count, cell,
records) and its agreeing / violating verdict;
the cell's third component also tested on its own
as a companion across the full population (B byte
0 as a function of the cell, and of the cell's
third component, over the pairs whose records
carry exactly one cell — the population of that
test printed and counted); and the two violating
repeats re-read with their cells' third
components against their A byte 0 values in full.
Any determination NOT PROVEN unless the numbers
prove it; never invent one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

hef143.py lineage in ~/workspace/.verify-tmp/aesir143 is the base for hef144; section143.txt + hef143.out are there and on the Pi (~/aesir-build/).

One bounded host-side child per contract.
