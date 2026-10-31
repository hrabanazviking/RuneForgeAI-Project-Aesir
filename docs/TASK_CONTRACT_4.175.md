# TASK_CONTRACT_4.175 (AES-NUM-175)

Scope (from AES-NUM-174's NEXT + TODO 4.175):
(i) the head's twelve non-417-family positions
in full — AES-NUM-170/174 measured the head as
16 of 28 positions in the 417-family (B offset
in [1196000000, 1197000000)), leaving twelve
outside it, among them the diff-0 identity
positions 9 and 18 that sit above the two
family-exiting larger gaps (33,280 above
position 8; 32,768 above position 17).
Tests: each of the twelve in full (position,
A/B acts, A/B offsets, diff, sizes, channels);
each against the position below it in A-offset
sorted order (that position's family status and
diff); the twelve as a population (diff census,
size census, channel census, which of them are
diff-0, which sit above a larger gap). Any law
NOT PROVEN unless the numbers prove it; never
invent one.
(ii) runs 84, 87 and 88 in full — AES-NUM-174
measured the A 640–660 region touching runs
84 (its last two acts at A 640–641), 87 (A
658–659, shift −418) and 88 (its first act at
A 660, shift +1) without giving those runs in
full. Tests: secondary runs 84, 87 and 88 in
full (acts, A/B extents, shifts, B
contiguity); their B neighbourhoods in full;
their A neighbourhoods in full. Any law NOT
PROVEN unless the numbers prove it; never
invent one.
(iii) runs 80 and 81 in full — AES-NUM-174's
run table measured run 80 as a −393 block of
4 at A 625–628 (B 232–235) and run 81 as a
+25 block of 6 at A 629–634 (B 654–659).
Tests: secondary runs 80 and 81 in full (acts,
A/B extents, shifts, B contiguity); their B
neighbourhoods in full; their A neighbourhoods
in full. Any law NOT PROVEN unless the numbers
prove it; never invent one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

hef174.py lineage in ~/workspace/.verify-tmp/aesir174 is the base for hef175 (hef174 = the hef173 base plus arms174, sha256 f717c9f0…); section174.txt + hef174.out are there and on the Pi (~/aesir-build/).

One bounded host-side child per contract. Exactly ONE launch: check `tmux ls` + `ps` on Mimir for an existing hef175/h175 child BEFORE launching.
