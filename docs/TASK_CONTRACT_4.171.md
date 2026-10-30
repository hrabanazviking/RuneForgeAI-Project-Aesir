# TASK_CONTRACT_4.171 (AES-NUM-171)

Scope (from AES-NUM-170's NEXT + TODO 4.171):
(i) the unbounded delta match-distance census —
AES-NUM-170 closed the ±3 window (21 pairs at
distance 0, the two +174 pairs at distance 1,
eight pairs NONE: A 212/213 delta +170, A 417/418
delta −205, A 430/431 delta −212, A 620 delta
+30, A 651 delta 0). Tests: for each of the 31
pairs, the smallest run-order distance (measured
in run indices from the nearer containing run, as
in 4.170) at which ANY secondary run in the full
run table has shift == delta; the matching run(s)
at that distance in full; the unbounded
match-distance distribution over all 31 pairs;
for the eight NONE pairs specifically, every run
in the full table whose shift equals their delta,
with its distance. Any law NOT PROVEN unless the
numbers prove it; never invent one.
(ii) the 417-family equal-diff pairing structure
+ the A-offset ordering of its positions —
AES-NUM-170 measured four adjacent position pairs
sharing an identical diff ((10, 11), (14, 15),
(19, 20), (22, 23)) among the 16 family positions
[5, 6, 8, 10, 11, 13, 14, 15, 16, 17, 19, 20, 22,
23, 25, 26]. Tests: every pair of family positions
with equal diff, in full (position gap, A/B sizes
and channels at both, A and B offset steps between
them); whether equal-diff pairing is exactly the
adjacent pairing or extends further; the family
positions ordered by A offset against their
position order (concordance, reversals in full);
the position-16 A offset (778,828,288) against
every other head A offset (rank, neighbours in
offset order). Any law NOT PROVEN unless the
numbers prove it; never invent one.
(iii) runs 72 and 73 in full — AES-NUM-170's run
table measured run 72 as a +93 singleton at
A 522 and run 73 as a −239 singleton at A 523,
after run 71 in A order. Tests: secondary runs
72 and 73 in full (acts, A/B extents, shifts, B
contiguity); their B neighbourhoods in full;
their A neighbourhoods in full. Any law NOT
PROVEN unless the numbers prove it; never invent
one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

hef170.py lineage in ~/workspace/.verify-tmp/aesir170 is the base for hef171 (hef170 = the hef169 base plus arms170, sha256 e9da4412…); section170.txt + hef170.out are there and on the Pi (~/aesir-build/).

One bounded host-side child per contract. Exactly ONE launch: check `tmux ls` + `ps` on Mimir for an existing hef171/h171 child BEFORE launching.
