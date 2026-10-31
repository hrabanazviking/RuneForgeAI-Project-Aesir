# TASK_CONTRACT_4.246 (AES-NUM-246)

Scope (from AES-NUM-245's NEXT + TODO 4.246).
AES-NUM-245 stated the two closing runs' seven
sequence families together, family by family; the
same combined material stated POSITION by
position — for each act position, all of its
values on both sides together, and which families
agree at that position — has not been stated:
(i) the A closing run's combined sequences stated
position by position in full — at each position
1-8 (ranks 741-748): rank, index, act, size,
channel, class, run-102 membership and offset,
plus the gap to the next position where one
exists (positions 1-7).
(ii) the B closing run's combined sequences
stated position by position in full — the same
statement at each position 1-8 (ranks 743-750).
(iii) the closing-run combined comparison stated
position by position in full — at each act
position 1-8, which of the six act families
(size, channel, class, run-102 membership,
offset, index) agree at that position, stated
exactly; and at each gap position 1-7, whether
the gaps agree, stated exactly; with each
position's agreement set checked against the
family-by-family comparison of AES-NUM-245.
Tests: each position's printed values equal the
corresponding entries of the combined sequences
printed in AES-NUM-245, and each position's
printed agreement set equals the set derived
from AES-NUM-245's family comparisons (family
agreement counts over positions must re-sum to
size 4, channel 5, class 0, run-102 7, offset 0,
index 0, gap 3).
Any law NOT PROVEN unless the numbers prove
it; never invent one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

hef245.py lineage in ~/workspace/.verify-tmp/aesir245 is the base for hef246 (hef245 = the hef244 base plus arms245, sha256 19925ebd…). Launch with unbuffered output (`python3 -u`) and capture the exit code to a .exit file, per TASK_CONTRACT_4.175_RETRY's proven terms. Window ranges in the new section MUST be bounded by the measured list lengths (A acts 749, B acts 751) — no index or rank beyond the last measured position (A index 748, B index 750, A-offset rank 748, B-offset rank 750) may be requested.

One bounded host-side child per contract. Exactly ONE launch: check `tmux ls` + `ps` on Mimir for an existing hef246/h246 child BEFORE launching.
