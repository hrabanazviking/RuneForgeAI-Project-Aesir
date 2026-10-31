# TASK_CONTRACT_4.252 (AES-NUM-252)

Scope (from AES-NUM-251's NEXT + TODO 4.252).
AES-NUM-250 stated the cumulative totals before
each position, AES-NUM-251 stated what remains
of the total after each position is counted;
what remains of the total before each position
is counted — the remaining-before-count totals —
has not been stated:
(i) the closing-run remaining-before-count
sequence in full — at each act position 1-8,
the total agreeing family-instances 16 minus
that position's cumulative-minus-count
difference of AES-NUM-250 (equivalently that
position's AES-NUM-251 remaining plus its own
agreement count), stated as one sequence.
(ii) the distinct remaining-before values in
full — each distinct remaining-before value,
the positions at which it occurs, and its
count, stated exactly.
(iii) the gap remaining-before-count sequence
in full — at each gap position 1-7, the gap
total 3 minus the gap cumulative count before
that gap position (the AES-NUM-249 gap
cumulative count minus that gap position's
AES-NUM-250 gap cumulative difference), stated
as one sequence and checked against
AES-NUM-249 and AES-NUM-245.
Tests: the printed remaining-before sequence
equals (16, 15, 13, 12, 12, 9, 6, 3); the
distinct remaining-before counts sum to 8;
each remaining-before minus its position's
agreement count equals that position's
AES-NUM-251 remaining; the first
remaining-before equals 16; the gap
remaining-before sequence equals
(3, 3, 3, 3, 3, 2, 1) and starts at 3.
Any law NOT PROVEN unless the numbers prove
it; never invent one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

hef251.py lineage in ~/workspace/.verify-tmp/aesir251 is the base for hef252 (hef251 = the hef250 base plus arms251, sha256 2ea8dfe5…). Launch with unbuffered output (`python3 -u`) and capture the exit code to a .exit file, per TASK_CONTRACT_4.175_RETRY's proven terms. Window ranges in the new section MUST be bounded by the measured list lengths (A acts 749, B acts 751) — no index or rank beyond the last measured position (A index 748, B index 750, A-offset rank 748, B-offset rank 750) may be requested.

One bounded host-side child per contract. Exactly ONE launch: check `tmux ls` + `ps` on Mimir for an existing hef252/h252 child BEFORE launching.
