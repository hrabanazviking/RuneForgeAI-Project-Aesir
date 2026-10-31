# TASK_CONTRACT_4.254 (AES-NUM-254)

Scope (from AES-NUM-253's NEXT + TODO 4.254).
AES-NUM-251 stated the remaining totals
position by position; their running totals have
not been stated:
(i) the closing-run cumulative
remaining-count sequence in full — at
each act position 1-8, the running total of the
AES-NUM-251 remaining values over
positions 1 up to and including that position,
stated as one sequence.
(ii) the distinct cumulative remaining
totals in full — each distinct cumulative
remaining total, the positions at which
it occurs, and its count, stated exactly.
(iii) the gap cumulative remaining-count
sequence in full — at each gap position 1-7, the
running total of the AES-NUM-251 gap
remaining values over gap positions 1 up
to and including that position, stated as one
sequence and checked against AES-NUM-251 and
AES-NUM-245.
Tests: the printed cumulative remaining
sequence equals (15, 28, 40, 52, 61, 67, 70, 70);
the distinct cumulative totals' counts sum to
8; each cumulative total minus the previous
cumulative total equals that position's
AES-NUM-251 remaining value; the last
cumulative total equals 70; the gap cumulative
remaining sequence equals
(3, 6, 9, 12, 14, 15, 15) and ends at 15.
Any law NOT PROVEN unless the numbers prove
it; never invent one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

hef253.py lineage in ~/workspace/.verify-tmp/aesir253 is the base for hef254 (hef253 = the hef252 base plus arms253, sha256 831909bb…). Launch with unbuffered output (`python3 -u`) and capture the exit code to a .exit file, per TASK_CONTRACT_4.175_RETRY's proven terms. Window ranges in the new section MUST be bounded by the measured list lengths (A acts 749, B acts 751) — no index or rank beyond the last measured position (A index 748, B index 750, A-offset rank 748, B-offset rank 750) may be requested.

One bounded host-side child per contract. Exactly ONE launch: check `tmux ls` + `ps` on Mimir for an existing hef254/h254 child BEFORE launching.
