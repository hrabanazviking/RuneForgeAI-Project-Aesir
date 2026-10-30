# TASK_CONTRACT_4.162 (AES-NUM-162)

Scope (from AES-NUM-161's NEXT + TODO 4.162):
(i) gap 8's B-block offset region in full —
AES-NUM-161 measured gap 8's four B-side skipped
acts at offset ranks 747–750 of 751 in context B,
the first of them 496 past the end of a
32,784-byte act at B position 674. Tests: every
context-B act at offset ranks 738–751 in full
(acts, B positions, A positions, shifts, runs);
the offset predecessor act at B 674 in full (its
run, its run's B/A extents); what follows the
block in offset order (ranks 750–751 and the
region's end). Any law NOT PROVEN unless the
numbers prove it; never invent one.
(ii) the 6864/6932 split against the untested
fields — AES-NUM-161 measured two disjoint
27-pair populations and membership a function of
NO tested field (group, status, byte0s, class,
census, records). Tests: the same function test
against the fields not yet tried — full B value,
A/B byte1, byte2, byte3, byte3 difference, full
difference, XOR, (byte1, byte2) and the
(byte3, byte1+byte2) key; per-field membership
tables over the 54. Any law NOT PROVEN unless
the numbers prove it; never invent one.
(iii) the seam's remaining displaced blocks in
full — AES-NUM-161 measured a run-93 singleton
(A 671, shift −391) at B 280, run 19's +240 pair
at B 518–519 and run 20 (+5) from B 285. Tests:
secondary runs 93, 19 and 20 in full (acts, A/B
extents, shifts, B contiguity); the B 280
singleton's A neighbourhood (A 668–674) in full.
Any law NOT PROVEN unless the numbers prove it;
never invent one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

hef161.py lineage in ~/workspace/.verify-tmp/aesir161 is the base for hef162 (hef161 = the hef160 base plus arms161, sha256 e5d77226…); section161.txt + hef161.out are there and on the Pi (~/aesir-build/).

One bounded host-side child per contract.
