# TASK_CONTRACT_4.250 (AES-NUM-250)

Scope (from AES-NUM-249's NEXT + TODO 4.250).
AES-NUM-249 stated the closing-run cumulative
agreement counts as one sequence, their distinct
values, and the gap cumulative sequence; the
difference forms of those cumulative sequences
have not been stated:
(i) the closing-run cumulative-minus-count
difference sequence in full — at each act
position 1-8, the cumulative agreement count of
AES-NUM-249 minus that position's own agreement
count of AES-NUM-248 (equivalently the cumulative
total before that position, 0 at position 1),
stated as one sequence.
(ii) the distinct differences in full — each
distinct difference value, the positions at
which it occurs, and its count, stated exactly.
(iii) the gap cumulative difference sequence in
full — at each gap position 1-7, the gap
cumulative count of AES-NUM-249 minus the
previous gap cumulative count (the per-gap
increment, 1 where the gap agrees and 0 where it
disagrees), stated as one sequence and checked
against AES-NUM-247 (agreeing positions 5, 6, 7)
and AES-NUM-245.
Tests: the printed difference sequence equals
(0, 1, 3, 4, 4, 7, 10, 13); the distinct
differences' counts sum to 8; each difference
plus its position's agreement count equals that
position's cumulative total; the gap difference
sequence equals (0, 0, 0, 0, 1, 1, 1) and sums
to 3.
Any law NOT PROVEN unless the numbers prove
it; never invent one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

hef249.py lineage in ~/workspace/.verify-tmp/aesir249 is the base for hef250 (hef249 = the hef248 base plus arms249, sha256 a6a06fa4…). Launch with unbuffered output (`python3 -u`) and capture the exit code to a .exit file, per TASK_CONTRACT_4.175_RETRY's proven terms. Window ranges in the new section MUST be bounded by the measured list lengths (A acts 749, B acts 751) — no index or rank beyond the last measured position (A index 748, B index 750, A-offset rank 748, B-offset rank 750) may be requested.

One bounded host-side child per contract. Exactly ONE launch: check `tmux ls` + `ps` on Mimir for an existing hef250/h250 child BEFORE launching.
