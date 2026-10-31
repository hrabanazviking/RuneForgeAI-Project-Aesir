# TASK_CONTRACT_4.247 (AES-NUM-247)

Scope (from AES-NUM-246's NEXT + TODO 4.247).
AES-NUM-246 stated the two closing runs' combined
material position by position, with a per-position
agreement set at each act position; those sets as
one sequence, their distinct forms, and the
gap-agreement sequence as one sequence have not
been stated:
(i) the closing-run agreement-set sequence in
full — the eight per-position agreement sets of
AES-NUM-246 stated as one sequence, position by
position (positions 1-8).
(ii) the distinct agreement sets in full — each
distinct set form, the positions at which it
occurs, and its count, stated exactly; with the
per-family position lists re-derived from the
sets alone (for each of the six act families,
the positions whose set contains it) and checked
against AES-NUM-245's family comparisons.
(iii) the gap-agreement sequence in full — the
seven gap positions' agreement results of
AES-NUM-246 stated as one sequence (positions
1-7), with its agreeing positions and count
stated exactly and checked against AES-NUM-245.
Tests: the printed agreement-set sequence equals
the sequence of sets printed in AES-NUM-246;
the distinct-set counts sum to 8; the per-family
position lists re-derived from the sets equal
AES-NUM-245's agreeing-position lists (size
5, 6, 7, 8; channel 2, 5, 6, 7, 8; class none;
run-102 1, 2, 3, 5, 6, 7, 8; offset none; index
none); the gap-agreement sequence equals
AES-NUM-246's printed gap results and its count
re-sums to 3.
Any law NOT PROVEN unless the numbers prove
it; never invent one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

hef246.py lineage in ~/workspace/.verify-tmp/aesir246 is the base for hef247 (hef246 = the hef245 base plus arms246, sha256 19d779cc…). Launch with unbuffered output (`python3 -u`) and capture the exit code to a .exit file, per TASK_CONTRACT_4.175_RETRY's proven terms. Window ranges in the new section MUST be bounded by the measured list lengths (A acts 749, B acts 751) — no index or rank beyond the last measured position (A index 748, B index 750, A-offset rank 748, B-offset rank 750) may be requested.

One bounded host-side child per contract. Exactly ONE launch: check `tmux ls` + `ps` on Mimir for an existing hef247/h247 child BEFORE launching.
