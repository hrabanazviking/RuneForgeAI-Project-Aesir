# TASK_CONTRACT_4.161 (AES-NUM-161)

Scope (from AES-NUM-160's NEXT + TODO 4.161):
(i) gap 8's B-side skipped population in full —
AES-NUM-160 measured gap 8 (run 102, step 49) as
the one gap whose first-skipped past-left-end
values split: side A 0 (contiguous), side B
404,667,368 (its first B-side skipped act sits at
offset 1,196,444,160). Tests: gap 8's four B-side
skipped acts in full (offsets, sizes, channels,
their order in B, what bounds them in context B —
the B acts immediately before and after the
skipped block in offset and in position), the
four A-side skipped acts in full against them
(paired by the gap record's mapping), and each
B-side skipped act's past-left-end against its
own B neighbours. Any law NOT PROVEN unless the
numbers prove it; never invent one.
(ii) the (20, 32720) 6864/6932 cell pair's full
population — AES-NUM-160 measured only 16
distinct cells over the 224 pairs, with the root
triangle's corner living in cells (20, 32720,
6864) and (20, 32720, 6932). Tests: every pair
carrying either cell (census count, group, status,
records, its listings and other sides, classes of
the vertices it touches); the listing graph
induced by those pairs alone (edges among them,
edges to outside); whether cell membership is a
function of any printed field (group, status,
byte0, class). Any law NOT PROVEN unless the
numbers prove it; never invent one.
(iii) the seam runs 70, 71 and 73's B
neighbourhoods in full — AES-NUM-160 measured the
A 518-526 seam: run 70's act at B 522, run 71's
three acts at B 281-283, run 73's singleton at
B 284. Tests: every context-B act at B positions
276-290 and 516-528 in full (acts, A positions,
shifts, secondary runs), the shared acts at those
positions in contract form, and each seam run's
neighbour classification there. Any law NOT
PROVEN unless the numbers prove it; never invent
one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

hef160.py lineage in ~/workspace/.verify-tmp/aesir160 is the base for hef161 (hef160 = the hef159 base plus arms160, sha256 ed8c45c5…); section160.txt + hef160.out are there and on the Pi (~/aesir-build/).

One bounded host-side child per contract.
