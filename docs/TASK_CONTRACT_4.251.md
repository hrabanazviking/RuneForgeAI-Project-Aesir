# TASK_CONTRACT_4.251 (AES-NUM-251)

Scope (from AES-NUM-250's NEXT + TODO 4.251).
AES-NUM-249 stated the closing-run cumulative
agreement counts, AES-NUM-250 stated the
cumulative totals before each position; the
complementary cumulative totals after each
position — what remains of the total once that
position is counted — have not been stated:
(i) the closing-run remaining agreement-count
sequence in full — at each act position 1-8,
the total agreeing family-instances 16 minus
that position's cumulative agreement count of
AES-NUM-249, stated as one sequence.
(ii) the distinct remainings in full — each
distinct remaining value, the positions at
which it occurs, and its count, stated exactly.
(iii) the gap remaining agreement-count
sequence in full — at each gap position 1-7,
the gap total 3 minus the gap cumulative count
of AES-NUM-249, stated as one sequence and
checked against AES-NUM-249 and AES-NUM-245.
Tests: the printed remaining sequence equals
(15, 13, 12, 12, 9, 6, 3, 0); the distinct
remainings' counts sum to 8; each remaining
plus its position's cumulative total equals
16; the last remaining equals 0; the gap
remaining sequence equals (3, 3, 3, 3, 2, 1, 0)
and ends at 0.
Any law NOT PROVEN unless the numbers prove
it; never invent one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

hef250.py lineage in ~/workspace/.verify-tmp/aesir250 is the base for hef251 (hef250 = the hef249 base plus arms250, sha256 68f50056…). Launch with unbuffered output (`python3 -u`) and capture the exit code to a .exit file, per TASK_CONTRACT_4.175_RETRY's proven terms. Window ranges in the new section MUST be bounded by the measured list lengths (A acts 749, B acts 751) — no index or rank beyond the last measured position (A index 748, B index 750, A-offset rank 748, B-offset rank 750) may be requested.

One bounded host-side child per contract. Exactly ONE launch: check `tmux ls` + `ps` on Mimir for an existing hef251/h251 child BEFORE launching.
