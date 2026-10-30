# TASK_CONTRACT_4.173 (AES-NUM-173)

Scope (from AES-NUM-172's NEXT + TODO 4.173):
(i) run 74's eight internal gaps in full —
AES-NUM-172 measured run 74 as an 83-act +0
in-place block at A/B 524–614 whose eight
unoccupied positions inside its extent (549,
557, 558, 559, 560, 563, 568, 580) are the
delta-0 correspondence pairs inside the extent.
Tests: each gap position in full (its A act,
its B act, offset, size, channel pair, delta);
the eight as a population (channel-pair census,
size census, spacing between consecutive gaps);
the ninth delta-0 pair at A 651 against the
eight (same fields; what run/extent it lies
in). Any law NOT PROVEN unless the numbers
prove it; never invent one.
(ii) the head's three lowest A offsets against
the remaining 25 — AES-NUM-172 measured the
three lowest head (positions 0–27) A offsets
as exactly positions 6, 16, 5 in that order.
Tests: the three in full (A offsets, gaps
between consecutive values in the full sorted
order, the gap from the third-lowest to the
fourth-lowest against every other consecutive
gap in the sorted 28); whether the three form
a separated low cluster by that measure; their
417-family/diff status in full. Any law NOT
PROVEN unless the numbers prove it; never
invent one.
(iii) runs 76 and 77 in full — AES-NUM-172's
run table measured run 76 as a +4 pair at
A 616–617 and run 77 as a +8 pair at A 618–619,
after run 75 in A order. Tests: secondary runs
76 and 77 in full (acts, A/B extents, shifts,
B contiguity); their B neighbourhoods in full;
their A neighbourhoods in full. Any law NOT
PROVEN unless the numbers prove it; never
invent one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

hef172.py lineage in ~/workspace/.verify-tmp/aesir172 is the base for hef173 (hef172 = the hef171 base plus arms172, sha256 4663f9ba…); section172.txt + hef172.out are there and on the Pi (~/aesir-build/).

One bounded host-side child per contract. Exactly ONE launch: check `tmux ls` + `ps` on Mimir for an existing hef173/h173 child BEFORE launching.
