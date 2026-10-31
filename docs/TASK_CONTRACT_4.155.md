# TASK_CONTRACT_4.155 (AES-NUM-155)

Scope (from AES-NUM-154's NEXT + TODO 4.155):
(i) the shared offsets' chain correspondence in
full — AES-NUM-154 measured 25 residue-0 offsets
shared by contexts A and B, sitting in A chains
of lengths {1: 12, 4: 4, 6: 4, 12: 5} and B chains
of lengths {1: 13, 4: 12}. Tests: for each A
512-chain, its offsets' B chain membership (and
conversely), printed as a chain-to-chain
correspondence table; which A chains survive
whole in B, which split, which merge; the
A-only and B-only offsets read against this
correspondence (where the non-shared rungs sit
inside otherwise-corresponding chains). Any law
NOT PROVEN unless the numbers prove it; never
invent one.
(ii) the hub closure's boundary — AES-NUM-154
measured 11 hub pairs (>= 4 byte2 listings)
forming a closed component (26 listings, all
hub-to-hub). Tests: the 7 individual pairs
carrying exactly 3 listings, printed in full
with their listings (partners, sub-keys, steps,
groups, record counts, cells, statuses); whether
each 3-listing pair's partners are hubs, other
3-listing pairs, or neither; the hub component's
internal structure (per-hub partner lists and
degrees within the 11, sub-key split over the 26
listings). Any law NOT PROVEN unless the numbers
prove it; never invent one.
(iii) gap 8 against run 74's gap 4 in full —
AES-NUM-154 measured gap 8 matching a run-74 gap
value on exactly 4 of the 23 split-kind features
(A/B gap distances 5/5, skipped counts 4/4), all
four against gap 4 alone. Tests: the 32-feature
side-by-side table gap 8 vs gap 4; gap 4 printed
in full (print_gap_full152); how the 4 matched
features sit inside the two gaps' full records
(bounding acts, skipped acts, mappings, steps).
Any determination NOT PROVEN unless the numbers
prove it; never invent one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

hef154.py lineage in ~/workspace/.verify-tmp/aesir154 is the base for hef155 (hef154 = the hef153 base plus arms154, sha256 fc5b2abb…); section154.txt + hef154.out are there and on the Pi (~/aesir-build/).

One bounded host-side child per contract.
