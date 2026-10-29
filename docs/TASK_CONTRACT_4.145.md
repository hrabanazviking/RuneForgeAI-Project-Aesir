# TASK_CONTRACT_4.145 (AES-NUM-145)

Scope (from AES-NUM-144's NEXT + TODO 4.145):
(i) gaps 3 and 7 read in full against each other
— AES-NUM-144 found the per-gap channel mapping
is not a function of the bounding channels, the
sole repeating bounding-channel key being
(left 1, right 0) at gaps 3 and 7 with mappings
((2→0),) and ((1→2),). Tests: for each of the two
gaps, its secondary run and step, the run's shift
and extent, the bounding acts' full identities
(offset, size, channel) in both contexts, the
skipped acts on both sides in full, and the acts
immediately surrounding the gap in both contexts
(two acts out on each side), printed side by side
and counted; and every candidate distinguishing
feature the printed rows support (bounding-act
offsets/sizes, skipped-act sizes/offsets, run
position, A/B positions) tabulated for the two
gaps. Any relation NOT PROVEN unless the numbers
prove it; never invent one.
(ii) the 8 violating cell repeats against
record-level companions — AES-NUM-144 found B
byte 0 is not a function of the cell: 8 cells in
group (20, 32720), 27 pairs each (216 pairs),
third components 6796, 6864, 6932, 7000, 7068,
7136, 7204, 7272, all violating with B byte 0 sets
of 2–19 values. Tests: over those 216 pairs, B
byte 0 tested as a function of each record-level
companion — the pair's centre set, its cidx set,
its poscat pattern, its per-record (cidx, centre)
sequence — each printed with distinct / repeating
/ agreeing / violating counts exactly; and each
of the 8 cells' 27 pairs printed in full once
under its strongest companion. Any determination
NOT PROVEN unless the numbers prove it; never
invent one.
(iii) the quad-wed injectivity dissected —
AES-NUM-144 found (status, group, record count,
cell) jointly injective under all four three-byte
sub-keys (224 distinct, 0 repeating). Tests: for
each of the four sub-keys, B byte 0 tested
against the value wed to (status, group, record
count, A byte 0) — the triple wed with A byte 0
added instead of the cell — counted exactly the
same way; the pairs that the cell component
separates but A byte 0 does not (and vice versa)
listed in full; and the statement, per sub-key,
of whether either added companion leaves any
repeating wed value at all. Any determination
NOT PROVEN unless the numbers prove it; never
invent one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

hef144.py lineage in ~/workspace/.verify-tmp/aesir144 is the base for hef145; section144.txt + hef144.out are there and on the Pi (~/aesir-build/).

One bounded host-side child per contract.
