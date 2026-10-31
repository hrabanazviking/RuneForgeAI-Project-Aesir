# TASK_CONTRACT_4.259 (AES-NUM-259)

Scope (from AES-NUM-258's NEXT + TODO 4.259).
AES-NUM-258 stated the cumulative cumulative
cumulative-remaining remainings position by
position; their running total has not been stated:
(i) the closing-run cumulative cumulative
cumulative cumulative-remaining remaining-count
sequence in full — at each act position 1-8, the
running total of the AES-NUM-258 cumulative
cumulative cumulative-remaining remaining values
over positions 1 up to and including that
position, stated as one sequence.
(ii) the distinct cumulative cumulative
cumulative totals in full — each distinct
cumulative cumulative cumulative total, the
positions at which it occurs, and its count,
stated exactly.
(iii) the gap cumulative cumulative cumulative
cumulative-remaining remaining-count sequence
in full — at each gap position 1-7, the running
total of the AES-NUM-258 gap cumulative
cumulative cumulative-remaining remaining values
over gap positions 1 up to and including that
gap position, stated as one sequence and checked
against AES-NUM-258 and AES-NUM-245.
Tests: the printed cumulative sequence equals
(55, 207, 486, 910, 1488, 2223, 3115, 4164);
the distinct cumulative cumulative cumulative
totals' counts sum to 8; the last cumulative
cumulative cumulative total equals 4164; the
gap cumulative sequence equals
(12, 45, 105, 195, 316, 468, 651) and ends
at 651.
Any law NOT PROVEN unless the numbers prove
it; never invent one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

hef258.py lineage in ~/workspace/.verify-tmp/aesir258 is the base for hef259 (hef258 = the hef257 base plus arms258, sha256 73920f1a…). Launch with unbuffered output (`python3 -u`) and capture the exit code to a .exit file, per TASK_CONTRACT_4.175_RETRY's proven terms. Window ranges in the new section MUST be bounded by the measured list lengths (A acts 749, B acts 751) — no index or rank beyond the last measured position (A index 748, B index 750, A-offset rank 748, B-offset rank 750) may be requested. All expected-value names MUST be defined before the loops that use them (the AES-NUM-255 first-launch NameError lesson).

One bounded host-side child per contract. Exactly ONE launch: check `tmux ls` + `ps` on Mimir for an existing hef259/h259 child BEFORE launching.
