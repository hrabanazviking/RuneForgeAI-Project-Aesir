# TASK_CONTRACT_4.255 (AES-NUM-255)

Scope (from AES-NUM-254's NEXT + TODO 4.255).
AES-NUM-254 stated the cumulative remaining
totals position by position; their
cumulative-minus-remaining differences have
not been stated:
(i) the closing-run cumulative-remaining-
minus-remaining difference sequence in full — at
each act position 1-8, that position's
AES-NUM-254 cumulative remaining total minus
its own AES-NUM-251 remaining value (the
cumulative remaining total before that
position's remaining value is counted), stated
as one sequence.
(ii) the distinct differences in full — each
distinct difference, the positions at which
it occurs, and its count, stated exactly.
(iii) the gap cumulative-remaining difference
sequence in full — at each gap position 1-7,
that position's AES-NUM-254 gap cumulative
remaining total minus its own AES-NUM-251 gap
remaining value, stated as one sequence and
checked against AES-NUM-254 and AES-NUM-245.
Tests: the printed difference sequence equals
(0, 15, 28, 40, 52, 61, 67, 70);
the distinct differences' counts sum to
8; each difference plus that position's
remaining value equals that position's
cumulative remaining total; the last
difference equals 70; the gap difference
sequence equals
(0, 3, 6, 9, 12, 14, 15) and ends at 15.
Any law NOT PROVEN unless the numbers prove
it; never invent one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

hef254.py lineage in ~/workspace/.verify-tmp/aesir254 is the base for hef255 (hef254 = the hef253 base plus arms254, sha256 cd757ce3…). Launch with unbuffered output (`python3 -u`) and capture the exit code to a .exit file, per TASK_CONTRACT_4.175_RETRY's proven terms. Window ranges in the new section MUST be bounded by the measured list lengths (A acts 749, B acts 751) — no index or rank beyond the last measured position (A index 748, B index 750, A-offset rank 748, B-offset rank 750) may be requested.

One bounded host-side child per contract. Exactly ONE launch: check `tmux ls` + `ps` on Mimir for an existing hef255/h255 child BEFORE launching.
