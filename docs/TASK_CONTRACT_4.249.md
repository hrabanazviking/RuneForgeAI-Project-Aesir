# TASK_CONTRACT_4.249 (AES-NUM-249)

Scope (from AES-NUM-248's NEXT + TODO 4.249).
AES-NUM-248 stated the closing-run agreement
counts as one sequence, their distinct values,
and the gap-agreement position lists; the
cumulative forms of those counts have not been
stated:
(i) the closing-run cumulative agreement-count
sequence in full — the running total of agreeing
family-instances after each act position of
AES-NUM-248 stated as one sequence, position by
position (positions 1-8), ending at the total 16.
(ii) the distinct cumulative totals in full —
each distinct cumulative total value, the
positions at which it occurs, and its count,
stated exactly.
(iii) the gap cumulative agreement-count
sequence in full — the running count of agreeing
gap positions after each gap position 1-7,
stated as one sequence and checked against
AES-NUM-245 (agreeing positions 5, 6, 7, count 3).
Tests: the printed cumulative agreement-count
sequence equals the running totals of
AES-NUM-248's printed counts (1, 3, 4, 4, 7, 10,
13, 16); the distinct cumulative totals' counts
sum to 8; the final cumulative total equals 16;
the gap cumulative sequence equals (0, 0, 0, 0,
1, 2, 3) and ends at 3.
Any law NOT PROVEN unless the numbers prove
it; never invent one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

hef248.py lineage in ~/workspace/.verify-tmp/aesir248 is the base for hef249 (hef248 = the hef247 base plus arms248, sha256 36ab3c64…). Launch with unbuffered output (`python3 -u`) and capture the exit code to a .exit file, per TASK_CONTRACT_4.175_RETRY's proven terms. Window ranges in the new section MUST be bounded by the measured list lengths (A acts 749, B acts 751) — no index or rank beyond the last measured position (A index 748, B index 750, A-offset rank 748, B-offset rank 750) may be requested.

One bounded host-side child per contract. Exactly ONE launch: check `tmux ls` + `ps` on Mimir for an existing hef249/h249 child BEFORE launching.
