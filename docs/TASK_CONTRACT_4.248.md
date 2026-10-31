# TASK_CONTRACT_4.248 (AES-NUM-248)

Scope (from AES-NUM-247's NEXT + TODO 4.248).
AES-NUM-247 stated the closing-run agreement
sets as one sequence, their distinct forms, and
the gap-agreement sequence; the counts carried
by those sets as one sequence, their distinct
values, and the gap-agreement position lists as
lists have not been stated:
(i) the closing-run agreement-count sequence in
full — the number of agreeing families at each
act position of AES-NUM-247 stated as one
sequence, position by position (positions 1-8).
(ii) the distinct agreement counts in full —
each distinct count value, the positions at
which it occurs, and its count, stated exactly;
with the total number of agreeing
family-instances re-summed over positions and
checked against AES-NUM-245's family counts
(size 4 + channel 5 + class 0 + run-102 7 +
offset 0 + index 0 = 16).
(iii) the gap-agreement position lists in full
— the agreeing positions and the disagreeing
positions of AES-NUM-247 stated as two lists,
with their counts stated exactly and checked
against AES-NUM-245 (agreeing 5, 6, 7, count 3;
disagreeing 1, 2, 3, 4, count 4).
Tests: the printed agreement-count sequence
equals the counts of the sets printed in
AES-NUM-247 (1, 2, 1, 0, 3, 3, 3, 3); the
distinct-count counts sum to 8; the re-summed
agreeing family-instances equal 16; the
gap-agreement position lists equal
AES-NUM-247's agreeing and disagreeing
positions and their counts re-sum to 3 and 4.
Any law NOT PROVEN unless the numbers prove
it; never invent one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

hef247.py lineage in ~/workspace/.verify-tmp/aesir247 is the base for hef248 (hef247 = the hef246 base plus arms247, sha256 bbc3c446…). Launch with unbuffered output (`python3 -u`) and capture the exit code to a .exit file, per TASK_CONTRACT_4.175_RETRY's proven terms. Window ranges in the new section MUST be bounded by the measured list lengths (A acts 749, B acts 751) — no index or rank beyond the last measured position (A index 748, B index 750, A-offset rank 748, B-offset rank 750) may be requested.

One bounded host-side child per contract. Exactly ONE launch: check `tmux ls` + `ps` on Mimir for an existing hef248/h248 child BEFORE launching.
