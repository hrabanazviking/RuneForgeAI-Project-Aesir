# TASK_CONTRACT_4.165 (AES-NUM-165)

Scope (from AES-NUM-164's NEXT + TODO 4.165):
(i) the above-boundary population's B-position
structure in full — AES-NUM-164 measured 30
context-B acts above context A's largest offset
(B offset ranks 721–750), all unshared, in four
offset clusters. Tests: the 30 acts in B-POSITION
order in full (position, offset rank, act, offset
cluster); the B windows they occupy (B 0–27 head
window, B 747–750 tail window, the main block's
scattered positions 229/272/674 and 735–738) with
every act in those windows in full (shared acts
included, with A positions, shifts, runs); gaps
between consecutive above acts in B position.
Any law NOT PROVEN unless the numbers prove it;
never invent one.
(ii) the matched-pair byte3-difference
confinement — AES-NUM-164 measured the matched
(6932 minus 6864) byte3 differences confined to
{14, 15, 16} on both the A side (15 x13, 16 x10,
14 x4) and the B side (15 x20, 16 x5, 14 x2),
while every whole-value relation was distinct
27 of 27. Tests: for each of the 27 matches, the
byte3 difference against the pairs' own A byte3
and B byte3 values (each side, each cell), the
cidx/idx order position, the within-pair diffs'
byte3 contribution, and status; whether the
14/15/16 value is a function of any of those.
Any law NOT PROVEN unless the numbers prove it;
never invent one.
(iii) runs 43/44/45 and 47/48 in full —
AES-NUM-164 measured run 46's A neighbourhood as
run 43 (+32, A 400), run 44 (+239, A 401), run 45
(+275, A 402), run 47 (+2, A 405–406) and run 48
(+32, A 407). Tests: secondary runs 43, 44, 45,
47 and 48 in full (acts, A/B extents, shifts, B
contiguity); their B neighbourhoods in full.
Any law NOT PROVEN unless the numbers prove it;
never invent one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

hef164.py lineage in ~/workspace/.verify-tmp/aesir164 is the base for hef165 (hef164 = the hef163 base plus arms164, sha256 62cb1305…); section164.txt + hef164.out are there and on the Pi (~/aesir-build/).

One bounded host-side child per contract.
