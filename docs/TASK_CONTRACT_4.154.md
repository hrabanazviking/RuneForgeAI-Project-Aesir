# TASK_CONTRACT_4.154 (AES-NUM-154)

Scope (from AES-NUM-153's NEXT + TODO 4.154):
(i) the two contexts' residue-0 offset sets in
full against each other — AES-NUM-153 measured
37 distinct residue-0 (mod 512) 24-byte offsets
in context A (art 5ab3537d cidx 86) and 38 in
context B (cidx 210), at the shared residue 0 of
gap 8's anchors. Tests: the two distinct-offset
sets side by side (shared offsets, A-only,
B-only, with counts); each shared offset's
position in A and in B (positional order
preserved or not); the A-only and B-only offsets
in full (offset, position, size, channel, and
their 512-chain membership from AES-NUM-153);
where the sets' ranges and chain structures
diverge. Any law NOT PROVEN unless the numbers
prove it; never invent one.
(ii) the byte2 census's hub pairs read as one
population — AES-NUM-153's census (85 listings,
84 distinct pair-pairs) has individual pairs
appearing in up to 6 listings. Tests: every
individual pair carrying >= 4 byte2 listings,
printed in full (the pair, its listings with
sub-keys, partners, byte2 steps, B byte0 steps,
groups, record counts, cells, statuses); the
hub population's size against the 96 listed
pairs; whether the hubs share byte values,
groups or cells. Any law NOT PROVEN unless the
numbers prove it; never invent one.
(iii) run 102's single gap (gap 8) read against
the run-62 / run-74 frame as a one-gap closure —
AES-NUM-152 closed run 74 and AES-NUM-153
closed run 62 on the same 9 shared run-frame
features of 32. Tests: gap 8's 32-feature row
against that 9-feature frame (does the one-gap
run carry the frame values its own row states,
and how its remaining 23 features compare in
kind to the splitting features of runs 62 and
74); the three runs' closures read side by
side. Any determination NOT PROVEN unless the
numbers prove it; never invent one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

hef153.py lineage in ~/workspace/.verify-tmp/aesir153 is the base for hef154 (hef153 = the hef152 base plus arms153, sha256 247c36de…); section153.txt + hef153.out are there and on the Pi (~/aesir-build/).

One bounded host-side child per contract.
