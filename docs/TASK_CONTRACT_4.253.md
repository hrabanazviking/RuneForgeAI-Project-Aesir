# TASK_CONTRACT_4.253 (AES-NUM-253)

Scope (from AES-NUM-252's NEXT + TODO 4.253).
AES-NUM-252 stated the remaining-before totals
position by position; their running totals have
not been stated:
(i) the closing-run cumulative
remaining-before-count sequence in full — at
each act position 1-8, the running total of the
AES-NUM-252 remaining-before values over
positions 1 up to and including that position,
stated as one sequence.
(ii) the distinct cumulative remaining-before
totals in full — each distinct cumulative
remaining-before total, the positions at which
it occurs, and its count, stated exactly.
(iii) the gap cumulative remaining-before-count
sequence in full — at each gap position 1-7, the
running total of the AES-NUM-252 gap
remaining-before values over gap positions 1 up
to and including that position, stated as one
sequence and checked against AES-NUM-252 and
AES-NUM-245.
Tests: the printed cumulative remaining-before
sequence equals (16, 31, 44, 56, 68, 77, 83, 86);
the distinct cumulative totals' counts sum to
8; each cumulative total minus the previous
cumulative total equals that position's
AES-NUM-252 remaining-before value; the last
cumulative total equals 86; the gap cumulative
remaining-before sequence equals
(3, 6, 9, 12, 15, 17, 18) and ends at 18.
Any law NOT PROVEN unless the numbers prove
it; never invent one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

hef252.py lineage in ~/workspace/.verify-tmp/aesir252 is the base for hef253 (hef252 = the hef251 base plus arms252, sha256 32e8e55b…). Launch with unbuffered output (`python3 -u`) and capture the exit code to a .exit file, per TASK_CONTRACT_4.175_RETRY's proven terms. Window ranges in the new section MUST be bounded by the measured list lengths (A acts 749, B acts 751) — no index or rank beyond the last measured position (A index 748, B index 750, A-offset rank 748, B-offset rank 750) may be requested.

One bounded host-side child per contract. Exactly ONE launch: check `tmux ls` + `ps` on Mimir for an existing hef253/h253 child BEFORE launching.
