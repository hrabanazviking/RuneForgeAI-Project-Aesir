# TASK_CONTRACT_4.166 (AES-NUM-166)

Scope (from AES-NUM-165's NEXT + TODO 4.166):
(i) the above-boundary population's B-position /
offset-rank order relation in full — AES-NUM-165
measured the main block's 23 acts strictly
increasing in offset rank with B position and
exactly two reversals (the 873M ladder triple at
B 1/0/27, ranks 724/725/726, and the
just-past-ceiling pair at B 748/747, ranks
721/722). Tests: every adjacent pair of above
acts in B-position order with its offset-rank
delta (position gap, rank delta, signs); the
rank-delta distribution over the whole
population; the two reversals against their
full B neighbourhoods (the triple: B 0-27
already read in 4.165 — here its three acts
against each other and the shared acts between
them in offset order; the ceiling pair: B
744-750 in offset order as well as position
order). Any law NOT PROVEN unless the numbers
prove it; never invent one.
(ii) the byte3-difference confinement against
the matched pairs' remaining byte fields —
AES-NUM-165 closed the byte3 companions; the
byte0/byte1/byte2 fields remain at the matched
level. Tests: for each of the 27 matches, both
byte3 differences (A side, B side) as a
function of: each cell's byte0/byte1/byte2
values (A and B values of the 6864 pair and of
the 6932 pair, singly), the matched
byte0/byte1/byte2 differences (6932 minus
6864, each side), and the within-pair
byte0/byte1/byte2 differences (each cell).
Any law NOT PROVEN unless the numbers prove
it; never invent one.
(iii) runs 42/53/60 and 61/62 in full —
AES-NUM-165 measured run 42's +241 triple
flanking run 44 at B 637-639, run 53's +7 pair
and run 60's -1 pair flanking run 43 at B
429-430 and 433-434, and runs 61 (+1 pair) and
62 (+3) flanking run 48 at B 437-438 and
441-443. Tests: secondary runs 42, 53, 60, 61
and 62 in full (acts, A/B extents, shifts, B
contiguity); their B neighbourhoods in full.
Any law NOT PROVEN unless the numbers prove
it; never invent one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

hef165.py lineage in ~/workspace/.verify-tmp/aesir165 is the base for hef166 (hef165 = the hef164 base plus arms165, sha256 4118f3b6…); section165.txt + hef165.out are there and on the Pi (~/aesir-build/).

One bounded host-side child per contract.
