# TASK_CONTRACT_4.159 (AES-NUM-159)

Scope (from AES-NUM-158's NEXT + TODO 4.159):
(i) the excursion's B fragments in full —
AES-NUM-158 measured the +432/+434 excursion's
B positions as [616, 617, 618, 619, 188, 189,
624, 625]: three fragments, B-order not
preserved. Tests: every shared act at B
positions 610-630 printed in full (act, A
position, B position, shift) with the excursion
acts marked; the B acts immediately around the
in-place pair (B 182-195) printed in full; what
sits in B between the +432 block's end (619)
and the +434 pair (624), and between the +434
pair and the next in-order B act; the three
fragments' B neighbours classified by shift
(same run / other run / non-shared). Any law
NOT PROVEN unless the numbers prove it; never
invent one.
(ii) the root triangle's two neither partners
in full as a pair — AES-NUM-158 measured
listings 23/24/26 forming a triangle among
three 40f019ce, neither-partner 4092dbce and
neither-partner 40fcb4ce. Tests: both partners
printed in full side by side (census listing
count, group, cell, status, records, A/B
bytes, diff); every listing of each partner
(sub-key, other side, other side's class);
the two partners against each other on the
fields the census carries (same/different,
printed per field). Any law NOT PROVEN unless
the numbers prove it; never invent one.
(iii) gap 4 in full — AES-NUM-158 confirmed
run 74's gaps in step order [3, 4, 5, 6, 7] at
steps [24, 31, 33, 37, 48]; gaps 3, 5 and 6 are
now read in full, gap 7 was read in full under
AES-NUM-152, gap 4 is the one run-74 gap not
yet read in full. Tests: gap 4 printed in full
(the print_gap_full form: run, step, bounding
acts in both contexts, distances, skipped acts
with channels and mapping, surrounding windows,
advance analysis); its channel classification
against gaps 3 (2->0), 5 and 6 (0->1) and 7
(1->2), printed from its own record. Any
determination NOT PROVEN unless the numbers
prove it; never invent one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

hef158.py lineage in ~/workspace/.verify-tmp/aesir158 is the base for hef159 (hef158 = the hef157 base plus arms158, sha256 b74c55d6…); section158.txt + hef158.out are there and on the Pi (~/aesir-build/).

One bounded host-side child per contract.
