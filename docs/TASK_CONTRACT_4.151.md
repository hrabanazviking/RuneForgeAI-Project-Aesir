# TASK_CONTRACT_4.151 (AES-NUM-151)

Scope (from AES-NUM-150's NEXT + TODO 4.151):
(i) the 6 distinct byte-0-differing near-miss
pair-pairs as one population — AES-NUM-150 found
the 8 listings are 6 distinct pair-pairs (2 counted
under both injective sub-keys), and the +4 listings
are 2 distinct pair-pairs forming ladder steps in
group (14, 9992) at A byte 0 (20, 178) -> (24, 178)
and (28, 176) -> (32, 176), B = A throughout.
Tests: every pair in the full 224 sharing
(byte1, byte3) = (1, 128) printed (A bytes, B bytes,
status, group, records, cell); their A byte-0 set
and B byte-0 set; whether the ladder chain at byte2
176/178 extends beyond A byte 0 20-32 or breaks;
and the 6 distinct pair-pairs tabulated together
(A and B steps, groups, record counts, cell
thirds) as one population. Any law NOT PROVEN
unless the numbers prove it; never invent one.
(ii) the 50 control comparisons decomposed by
verdict-field pattern — AES-NUM-149 found B byte 0
differing in 47 of 50 and status in 18, and
AES-NUM-150 found exactly 3 comparisons (in repeats
3, 18, 35) where neither verdict field differs.
Tests: the 50 classified exactly into B-byte-0-only
/ status-only / both / neither (status-only tested
from the numbers, never assumed to be 0); the
counts cross-checked against 47 / 18 / 3; and the
host repeats of the both-class read for whether
their violating pairs differ from the B-only class's
hosts on any printed field. Any relation NOT PROVEN
unless the numbers prove it; never invent one.
(iii) run 74's internal gaps as one sequence, and
skipped-block contiguity over all 8 gaps —
AES-NUM-150 found gap 4 (run 74, step 31) encloses
four consecutive skipped acts whose offsets advance
by exactly the preceding size, gaps 5 (step 33) and
6 (step 37) one act each. Tests: the gaps inside
run 74 printed in step order (gap number, step,
bounding positions, distances, skipped counts,
mapping set and full sequence); for every one of
the 8 gaps, its skipped block's internal offset
advances against the preceding sizes (contiguous
chain or not, per gap, with the advances printed);
and gap 4's chain read against the chains of the
other gaps. Any determination NOT PROVEN unless
the numbers prove it; never invent one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

hef150.py lineage in ~/workspace/.verify-tmp/aesir150 is the base for hef151 (hef150 = the hef149 base plus arms150 in its final patched form, sha256 51a5246c…); section150.txt + hef150.out are there and on the Pi (~/aesir-build/).

One bounded host-side child per contract.
