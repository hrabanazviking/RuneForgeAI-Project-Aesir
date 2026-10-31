# TASK_CONTRACT_4.168 (AES-NUM-168)

Scope (from AES-NUM-167's NEXT + TODO 4.168):
(i) the channel-disagreement correspondence across
both full contexts — AES-NUM-167 measured that in
the A 438–460 / B 441–463 windows the (offset, size)
sequence is identical at all 23 corresponding
positions and the channel differs at exactly the
seven run-62 gap correspondences, making each such
act context-only. Tests: every A-only distinct act
and every B-only distinct act in contexts A (86)
and B (210) in full (60 A-only / 62 B-only distinct
per AES-NUM-139): do they pair up by (offset, size)
— for each A-only act, is there a B-only act with
the same (offset, size), and vice versa; the
channel pairs of every such (offset, size) match;
the position correspondence of matched pairs
(B position minus A position, against the local
run shift); the unmatched residue on both sides in
full. Any law NOT PROVEN unless the numbers prove
it; never invent one.
(ii) the per-ordered-cell-pair FUNCTION pattern in
the great group — AES-NUM-167 measured, over the
56 ordered cell pairs of group (20, 32720), aval
FUNCTION in 28, bval FUNCTION in 32, both in 16,
both NOT in 12, aggregated NOT A FUNCTION on both
sides. Tests: each side's verdict as a function of
the ordered cell pair's features (from-offset,
to-offset, offset difference, direction, distance
in the sorted cell list, same features mod small
integers where the numbers suggest them — stated
before testing where a candidate is tried); the
two never-contradicted original keys (−191, −145)
in the widened rows in full (where they recur, at
what multiplicity, with what byte3 values). Any
law NOT PROVEN unless the numbers prove it; never
invent one.
(iii) runs 63 and 64 in full — AES-NUM-167 measured
run 63's −154 pair at A 498–499 / B 344–345 and
run 64's +23 singleton at A 500 / B 523, between
run 62 and run 65 in A order. Tests: secondary
runs 63 and 64 in full (acts, A/B extents, shifts,
B contiguity); their B neighbourhoods in full;
their A neighbourhoods in full. Any law NOT PROVEN
unless the numbers prove it; never invent one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

hef167.py lineage in ~/workspace/.verify-tmp/aesir167 is the base for hef168 (hef167 = the hef166 base plus arms167, sha256 6320ca8e…); section167.txt + hef167.out are there and on the Pi (~/aesir-build/).

One bounded host-side child per contract.
