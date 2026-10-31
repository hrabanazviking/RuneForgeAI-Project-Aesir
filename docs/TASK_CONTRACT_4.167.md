# TASK_CONTRACT_4.167 (AES-NUM-167)

Scope (from AES-NUM-166's NEXT + TODO 4.167):
(i) run 62's two internal gaps in full —
AES-NUM-166 measured run 62 as a 53-act +3 run
at A 438–497 / B 441–500 whose B gaps are
exactly B 447–448 (two acts, not shared
single-positioned) and B 455–459 (five acts,
all channel 0, not shared single-positioned),
and whose A extent skips A 444–445 and
A 452–456. Tests: the seven gap acts against
both contexts in full (each act's presence,
positions and multiplicity in A and in B;
whether each occurs anywhere else in either
context); the skipped A acts at A 444–445
and A 452–456 in full (their acts, their B
presence/positions/multiplicity, why they are
not run-62 members under the shared-act
definitions); the two gap windows' full
neighbourhoods in both contexts. Any law NOT
PROVEN unless the numbers prove it; never
invent one.
(ii) the matched A byte2-difference →
byte3-difference regularity against the wider
pair population — AES-NUM-166 found the
A byte3 difference (6932 minus 6864) to be a
FUNCTION of the matched A byte2 difference
over the 27 matched pairs (19 keys, 0
violations), single-sided (the B counterpart
failed). Tests: the same function question
over the full (20, 32720) group population
(all 224 pairs: for every ordered pair of
cells present in the group, or — where the
cell pairing is not defined beyond 6864/6932 —
over the population the pairing definition
supports, stated exactly); whether the
27-match mapping extends consistently to
every wider sample the definitions support;
the B-side counterpart on the same widened
population. Any law NOT PROVEN unless the
numbers prove it; never invent one.
(iii) runs 65 and 67 in full — AES-NUM-166
measured run 65's +0 singleton at B 501
(A 501) and run 67's −2 pair from B 502,
immediately after run 62's B block. Tests:
secondary runs 65 and 67 in full (acts, A/B
extents, shifts, B contiguity); their B
neighbourhoods in full; the runs between
them in the run table (run 66) in full.
Any law NOT PROVEN unless the numbers prove
it; never invent one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

hef166.py lineage in ~/workspace/.verify-tmp/aesir166 is the base for hef167 (hef166 = the hef165 base plus arms166, sha256 3eb4a0d6…); section166.txt + hef166.out are there and on the Pi (~/aesir-build/).

One bounded host-side child per contract.
