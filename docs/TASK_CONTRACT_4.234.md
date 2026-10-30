# TASK_CONTRACT_4.234 (AES-NUM-234)

Scope (from AES-NUM-233's NEXT + TODO 4.234).
AES-NUM-233 closed the two closing runs' second
acts side by side, but the third acts of the
two closing runs have not been set side by side
in this sequence:
(i) the act at A-offset rank 743 in full —
(791778304, 24, 0) at A 736, rank 743; the
third act of the A closing run (ranks 741-748),
with its incoming and outgoing gaps in A-offset
order stated exactly.
(ii) the act at B-offset rank 745 in full —
(1196396032, 14352, 1) at B 272, rank 745; the
third act of the B closing run (ranks 743-750),
with its incoming and outgoing gaps in B-offset
order stated exactly.
(iii) the closing-run third-act comparison in
full — the third acts of the two closing runs
(A rank 743 and B rank 745) stated side by
side: rank, index, act, class, run-102
membership, incoming gap and outgoing gap per
third act. Tests: each third act's stated
outgoing gap equals the third gap of its own
run's gap sequence as measured in AES-NUM-231
(A run gap sequence [512, 512, 512, 512, 512,
512, 512], third gap 512; B run gap sequence
[712, 26624, 14848, 33280, 512, 512, 512],
third gap 14848).
Any law NOT PROVEN unless the numbers prove
it; never invent one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

hef233.py lineage in ~/workspace/.verify-tmp/aesir233 is the base for hef234 (hef233 = the hef232 base plus arms233, sha256 325e58ca…). Launch with unbuffered output (`python3 -u`) and capture the exit code to a .exit file, per TASK_CONTRACT_4.175_RETRY's proven terms. Window ranges in the new section MUST be bounded by the measured list lengths (A acts 749, B acts 751) — no index or rank beyond the last measured position (A index 748, B index 750, A-offset rank 748, B-offset rank 750) may be requested.

One bounded host-side child per contract. Exactly ONE launch: check `tmux ls` + `ps` on Mimir for an existing hef234/h234 child BEFORE launching.
