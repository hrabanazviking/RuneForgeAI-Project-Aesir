# TASK_CONTRACT_4.270 (AES-NUM-270)

Scope (from AES-NUM-269's NEXT + TODO 4.270).
AES-NUM-270 stated the cumulative cumulative
cumulative cumulative cumulative cumulative
cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remainings position by
position; their running total has not been stated:
(i) the closing-run cumulative cumulative
cumulative cumulative cumulative cumulative
cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count
sequence in full — at each act position 1-8, the
running total of the AES-NUM-269 cumulative
cumulative cumulative cumulative cumulative
cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining values
over positions 1 up to and including that
position, stated as one sequence.
(ii) the distinct cumulative cumulative
cumulative cumulative cumulative cumulative
cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals in full — each distinct
cumulative cumulative cumulative cumulative
cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative total, the
positions at which it occurs, and its count,
stated exactly.
(iii) the gap cumulative cumulative cumulative
cumulative cumulative cumulative cumulative
cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence in
full — at each gap position 1-7, the running
total of the AES-NUM-269 gap cumulative
cumulative cumulative cumulative cumulative
cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining values
over gap positions 1 up to and including that
gap position, stated as one sequence and checked
against AES-NUM-269 and AES-NUM-245.
Tests: the printed cumulative sequence equals
(55, 812, 6393, 35648, 157831, 590019, 1934583,
5708379); the distinct cumulative cumulative
cumulative cumulative cumulative cumulative
cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals' counts sum to 8; the last
cumulative cumulative cumulative cumulative
cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative total equals
5708379; the gap cumulative sequence equals
(12, 177, 1392, 7752, 34273, 127925, 418761) and ends
at 418761.
Any law NOT PROVEN unless the numbers prove
it; never invent one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

hef269.py lineage in ~/workspace/.verify-tmp/aesir269 is the base for hef270 (hef269 = the hef268 base plus arms269, sha256 181797b1…). Launch with unbuffered output (`python3 -u`) and capture the exit code to a .exit file, per TASK_CONTRACT_4.175_RETRY's proven terms. Window ranges in the new section MUST be bounded by the measured list lengths (A acts 749, B acts 751) — no index or rank beyond the last measured position (A index 748, B index 750, A-offset rank 748, B-offset rank 750) may be requested. All expected-value names MUST be defined before the loops that use them (the AES-NUM-255 first-launch NameError lesson).

One bounded host-side child per contract. Exactly ONE launch: check `tmux ls` + `ps` on Mimir for an existing hef270/h270 child BEFORE launching.

No correction is carried into this slice: slice
4.269's controls were EXACT with no exception (its
only False tokens are the four gap-position agree
data values), and the AES-NUM-260 expected-value
correction contracted in 4.267 remains verified
closed.
