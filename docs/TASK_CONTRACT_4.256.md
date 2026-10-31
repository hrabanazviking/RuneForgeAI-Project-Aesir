# TASK_CONTRACT_4.256 (AES-NUM-256)

Scope (from AES-NUM-255's NEXT + TODO 4.256).
AES-NUM-254 stated the cumulative remaining
totals position by position and AES-NUM-255
stated their cumulative-minus-remaining
differences; what remains of those totals against
their own final total 70 has not been stated:
(i) the closing-run cumulative-remaining
remaining-count sequence in full — at each act
position 1-8, the final cumulative remaining
total 70 minus that position's AES-NUM-254
cumulative remaining total (the cumulative
remaining instances still uncounted after that
position), stated as one sequence.
(ii) the distinct cumulative-remaining remainings
in full — each distinct remaining, the positions
at which it occurs, and its count, stated
exactly.
(iii) the gap cumulative-remaining remaining-count
sequence in full — at each gap position 1-7, the
final gap cumulative remaining total 15 minus
that position's AES-NUM-254 gap cumulative
remaining total, stated as one sequence and
checked against AES-NUM-254 and AES-NUM-245.
Tests: the printed remaining sequence equals
(55, 42, 30, 18, 9, 3, 0, 0);
the distinct remainings' counts sum to
8; each remaining plus that position's
cumulative remaining total equals 70; the last
remaining equals 0; the gap remaining
sequence equals
(12, 9, 6, 3, 1, 0, 0) and ends at 0.
Any law NOT PROVEN unless the numbers prove
it; never invent one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

hef255r.py lineage in ~/workspace/.verify-tmp/aesir255 is the base for hef256 (hef255r = the hef254 base plus arms255r, sha256 de15b976…). Launch with unbuffered output (`python3 -u`) and capture the exit code to a .exit file, per TASK_CONTRACT_4.175_RETRY's proven terms. Window ranges in the new section MUST be bounded by the measured list lengths (A acts 749, B acts 751) — no index or rank beyond the last measured position (A index 748, B index 750, A-offset rank 748, B-offset rank 750) may be requested.

One bounded host-side child per contract. Exactly ONE launch: check `tmux ls` + `ps` on Mimir for an existing hef256/h256 child BEFORE launching.
