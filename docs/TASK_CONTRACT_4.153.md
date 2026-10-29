# TASK_CONTRACT_4.153 (AES-NUM-153)

Scope (from AES-NUM-152's NEXT + TODO 4.153):
(i) gap 8's two skipped regions read against
their contexts in full — AES-NUM-152 found side
B's skipped block is a uniform 512 ladder at
offsets 1,196,444,160..1,196,445,696 in a region
404,667,392 bytes from side A's block, while
side A's first skipped act is offset-contiguous
with the shared left bounding act
(791,776,768, 24, 0) and its remaining three sit
on the 512 ladder extending that bound. Tests:
every 24-byte act at a 512 stride in the
neighbourhood of gap 8 in contexts A and B
(the ladder approaching the bound, the skipped
acts, and what follows the right bounding act
(768,609,280, 24, 0) on each side); whether side
B's ladder belongs to a wider 512 ladder in
context B (acts before/after its four skipped
acts at the same stride, in the run and in the
full context); where side A's ladder ends.
Any law NOT PROVEN unless the numbers prove it;
never invent one.
(ii) the byte2-differing Hamming-1 pair-pairs
over the full 224 as a census — the mirror of
the AES-NUM-150 byte-0 census. AES-NUM-152
measured that the two non-member (1, 128) pairs
earn no byte-0 listing because all their
Hamming-1 neighbours under both injective
sub-keys differ at byte2. Tests: every
Hamming-1 pair-pair under (byte0, byte1, byte2)
and under (byte0, byte2, byte3) whose single
differing position is byte2, printed in the
AES-NUM-150 form (sub-key values, byte2 steps,
B-side steps, groups, record counts, cells,
statuses); the step distribution; where the
two non-members and the four members sit in
this census (listings earned, partners).
Any law NOT PROVEN unless the numbers prove it;
never invent one.
(iii) run 62's gaps 1 and 2 read against each
other in the 32-feature form (the AES-NUM-149
feat_row form) — AES-NUM-152 re-read both in
full: same run 62, shift +3, run length 53,
extents A 438..497 / B 441..500, skipped
offsets identical between contexts in both
gaps, mappings ((1, 2),) x2 and ((2, 0),) x5.
Tests: the side-by-side 32-feature table gap 1
vs gap 2; which features the two share, which
split them; the two-gap run-62 closure in the
form of AES-NUM-152's run-74 closure. Any
determination NOT PROVEN unless the numbers
prove it; never invent one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

hef152.py lineage in ~/workspace/.verify-tmp/aesir152 is the base for hef153 (hef152 = the hef151 base plus arms152, sha256 55d22a85…); section152.txt + hef152.out are there and on the Pi (~/aesir-build/).

One bounded host-side child per contract.
