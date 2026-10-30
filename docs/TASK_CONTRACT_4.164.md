# TASK_CONTRACT_4.164 (AES-NUM-164)

Scope (from AES-NUM-163's NEXT + TODO 4.164):
(i) the offset-range boundary between the
contexts in full — AES-NUM-163 measured context
A's largest offset as 791,780,864 (749 acts, 749
distinct offsets) and all thirteen of B's top
acts above it. Tests: every context-B act whose
offset is above A's largest offset in full
(count, offset ranks in B's order, B positions,
sizes, channels, shared status); every context-A
act at or above B's smallest such offset band
boundary in full; the B offset rank at which B
passes A's largest offset, and the acts on both
sides of that boundary in both contexts. Any law
NOT PROVEN unless the numbers prove it; never
invent one.
(ii) the 6864/6932 split as a matched-pair
comparison — AES-NUM-163 measured the cidx
sequence taking 27 values ((2,), (5,), …, (80,)),
each exactly once in EACH cell, and the idx
sequence 27 values (0,)–(26,), each once in each
cell; every pair in the 54 carries exactly one
record with n 27, centre 127, in37 False. Tests:
for each of the 27 shared cidx values, the 6864
pair and the 6932 pair recorded at it side by
side (A/B values, byte fields, difference, XOR,
group, status, idx, poscat, cells); whether any
relation between the matched two (difference,
XOR, byte relation) is constant or structured
across the 27 matches. Any law NOT PROVEN unless
the numbers prove it; never invent one.
(iii) runs 21/22/23 and 46 in full —
AES-NUM-163 measured run 21 (+7, A 296–297,
B 303–304), run 22 (+111, A 298–299, B 409–410),
run 23 (+135, A 300, B 435) as run 20's A
successors, and run 46 (−102, A 403–404) at
B 301–302 as its B successor. Tests: secondary
runs 21, 22, 23 and 46 in full (acts, A/B
extents, shifts, B contiguity); run 46's A
neighbourhood (A 400–407) and B neighbourhood
(B 298–304) in full. Any law NOT PROVEN unless
the numbers prove it; never invent one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

hef163.py lineage in ~/workspace/.verify-tmp/aesir163 is the base for hef164 (hef163 = the hef162 base plus arms163, sha256 b98ce9a3…); section163.txt + hef163.out are there and on the Pi (~/aesir-build/).

One bounded host-side child per contract.
