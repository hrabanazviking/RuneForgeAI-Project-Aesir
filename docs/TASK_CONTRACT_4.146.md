# TASK_CONTRACT_4.146 (AES-NUM-146)

Scope (from AES-NUM-145's NEXT + TODO 4.146):
(i) the per-gap channel mapping as a function of
the A-side skipped acts themselves — AES-NUM-144/
145 found the mapping is not a function of the
bounding acts, shifts or distances, and gaps 3
and 7 differ only in location, identity, and
skipped-act properties. Tests: over all 8 gaps,
the mapping (the set of paired A→B channels and
the full paired sequence) tested as a function of
each skipped-act feature the printed rows support
— the A-side skipped acts' sizes, their A
channels, their offsets, their offset residues
(offset mod 512 and mod 32784), the paired
(size, channel) tuples, and the gap's step within
its run — each printed with distinct / repeating /
violating counts exactly; and gaps 3 and 7's
skipped acts read against the corpus (each act's
occurrence count across all contexts and
artifacts, and the contexts it occurs in). Any
relation NOT PROVEN unless the numbers prove it;
never invent one.
(ii) B byte 0 over the 216 violating-cell pairs
against the remaining record-level companions —
AES-NUM-145 found centre set, cidx set, poscat
pattern and the (cidx, centre) sequence all fail.
Tests: B byte 0 as a function of each remaining
companion — the per-record idx sequence, the
per-record in37 pattern, A byte 0 as a companion
over this population, and the per-record
(cidx, idx) sequence — each printed with
distinct / repeating / agreeing / violating
counts exactly, and the population's pairs
printed in full once under the strongest of the
four (fewest violating, then most distinct).
Any determination NOT PROVEN unless the numbers
prove it; never invent one.
(iii) the two (byte1, byte2, byte3) base-group
pair-pairs read in full against each other —
AES-NUM-145 found the base wed (status, group,
record count, (byte1, byte2, byte3)) has exactly
2 multi-pair groups, both separated by both the
cell and A byte 0. Tests: for each of the 2
groups, its pairs printed in full side by side
(A and B words, all four bytes, status, group,
record count, cell, A byte 0, B byte 0), their
records printed record by record side by side,
and every field in which the two pairs of a
group differ tabulated. Any relation NOT PROVEN
unless the numbers prove it; never invent one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

hef145.py lineage in ~/workspace/.verify-tmp/aesir145 is the base for hef146; section145.txt + section145b.txt + hef145.out are there and on the Pi (~/aesir-build/).

One bounded host-side child per contract.
