# TASK_CONTRACT_4.152 (AES-NUM-152)

Scope (from AES-NUM-151's NEXT + TODO 4.152):
(i) gap 8's non-contiguous skipped block read in
full against the contiguous blocks of gaps 1 and
2 — AES-NUM-151 found gap 8 is the only
non-contiguous gap (side A advances
[488, 512, 512], side B [512, 512, 512], against
sizes [24, 24, 24, 24] on both sides), while gaps
1, 2 and 4 are preceding-size chains on both
sides. Tests: gap 8 in full (run, step, bounding
acts, positions, distances, its skipped acts on
both sides with offsets/sizes/channels, the
surrounding windows, its mapping); the first
advance 488 on side A read against side B's
uniform 512 and against the bounding acts'
offsets; gaps 1 and 2's blocks re-read in the
same form for the contrast. Any law NOT PROVEN
unless the numbers prove it; never invent one.
(ii) the two (byte1, byte3) = (1, 128)-population
pairs that are members of no distinct near-miss
pair-pair (byte2 177 at A byte0 20, group
(19, 7712), 1 record, cell (19, 7712, 2384);
byte2 160 at A byte0 68, group (19, 7712),
1 record, cell (19, 7712, 2880)) read against
the four member pairs. Tests: each pair in full;
its Hamming-1 neighbourhood under both injective
sub-keys ((byte0, byte1, byte2) and
(byte0, byte2, byte3)) over the full 224 printed
— which neighbours exist, at which byte each
differs, and why each of the two earns no byte-0
near-miss listing; the four member pairs'
neighbourhoods in the same form for contrast.
Any explanation NOT PROVEN unless the numbers
prove it; never invent one.
(iii) run 74's remaining two gaps read in full
against gaps 4, 5 and 6 — gap 3 (step 24,
mapping ((2, 0),), one skipped act of size
32784, channels A 2 / B 0, offset 788357120) and
gap 7 (step 48, mapping ((1, 2),), one skipped
act of size 26128, channels A 1 / B 2, offset
789100544); AES-NUM-151 corrected the record:
run 74 holds five internal gaps (3, 4, 5, 6, 7
at steps 24, 31, 33, 37, 48), not three. Tests:
gaps 3 and 7 in full (the AES-NUM-150 gap-4
form); feature tables gap 3 vs each of 4/5/6
and gap 7 vs each of 4/5/6 (the 32-feature
form); the five-gap run-74 sequence closed —
which features the five share, which split
them. Any determination NOT PROVEN unless the
numbers prove it; never invent one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

hef151.py lineage in ~/workspace/.verify-tmp/aesir151 is the base for hef152 (hef151 = the hef150 base plus arms151, sha256 13dfea5f…); section151.txt + hef151.out are there and on the Pi (~/aesir-build/).

One bounded host-side child per contract.
