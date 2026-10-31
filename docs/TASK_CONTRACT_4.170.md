# TASK_CONTRACT_4.170 (AES-NUM-170)

Scope (from AES-NUM-169's NEXT + TODO 4.170):
(i) the 31 correspondence pairs' delta match-distance
census — AES-NUM-169 recomputed the neighbour census
directly (preceding 19/31, following 17/31, at least
one 21/31, 10 exceptions) and found the two +174
exceptions equal the shift of run 7, the run
immediately after the run containing both their
neighbouring shared acts, while the other eight
exceptions equal no neighbouring run shift within
three runs either side. Tests: for each of the 31
pairs, every secondary run within three runs either
side of BOTH the preceding containing run and the
following containing run, with its shift; the
smallest run-order distance at which a run with
shift == delta occurs (distance measured in run
indices from the nearer containing run, 0 = the
containing run itself); the match-distance
distribution over all 31 pairs; whether match
distance is a function of the channel pair, of the
delta value, or of the A position band. Any law
NOT PROVEN unless the numbers prove it; never
invent one.
(ii) the heads' offset-difference family structure —
AES-NUM-169 measured, over positions 0–27 aligned
by position, offset differences (B − A) at the 25
size-agreeing positions in three groups: 0 at the
nine shared positions; {94,363,136, 94,362,112} at
positions 0–1 (873-based B head acts, differing by
exactly 1,024); and a 417,34x,xxx family at the
sixteen 1,196-based positions, declining overall
with upward steps at position 6 and a +100,768
jump at position 16 (417,443,784). Tests: the
417-family differences in full against position
(differences of successive differences; the
difference as a function of position, of size, of
channel); the position-16 outlier in full (its A
and B acts against their position neighbours
15/17 in full); the 873-family relation across
positions 0, 1 and 27 (the B-only 873-based acts
against A's acts at those positions and against
each other). Any law NOT PROVEN unless the numbers
prove it; never invent one.
(iii) runs 70 and 71 in full — AES-NUM-169's run
table measured run 70 as a +4 triple at A 516–518
and run 71 as a −238 triple at A 519–521, after run
69 in A order. Tests: secondary runs 70 and 71 in
full (acts, A/B extents, shifts, B contiguity);
their B neighbourhoods in full; their A
neighbourhoods in full. Any law NOT PROVEN unless
the numbers prove it; never invent one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

hef169.py lineage in ~/workspace/.verify-tmp/aesir169 is the base for hef170 (hef169 = the hef168 base plus arms169, sha256 fb4f3bb7…); section169.txt + hef169.out are there and on the Pi (~/aesir-build/).

One bounded host-side child per contract. Exactly ONE launch: check `tmux ls` + `ps` on Mimir for an existing hef170/h170 child BEFORE launching.
