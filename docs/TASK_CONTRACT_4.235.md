# TASK_CONTRACT_4.235 (AES-NUM-235)

Scope (from AES-NUM-234's NEXT + TODO 4.235).
AES-NUM-234 closed the two closing runs' third
acts side by side, but the fourth acts of the
two closing runs have not been set side by side
in this sequence:
(i) the act at A-offset rank 744 in full —
(791778816, 24, 0) at A 744, rank 744; the
fourth act of the A closing run (ranks 741-748),
with its incoming and outgoing gaps in A-offset
order stated exactly.
(ii) the act at B-offset rank 746 in full —
(1196410880, 32784, 2) at B 674, rank 746; the
fourth act of the B closing run (ranks 743-750),
with its incoming and outgoing gaps in B-offset
order stated exactly.
(iii) the closing-run fourth-act comparison in
full — the fourth acts of the two closing runs
(A rank 744 and B rank 746) stated side by
side: rank, index, act, class, run-102
membership, incoming gap and outgoing gap per
fourth act. Tests: each fourth act's stated
outgoing gap equals the fourth gap of its own
run's gap sequence as measured in AES-NUM-231
(A run gap sequence [512, 512, 512, 512, 512,
512, 512], fourth gap 512; B run gap sequence
[712, 26624, 14848, 33280, 512, 512, 512],
fourth gap 33280).
Any law NOT PROVEN unless the numbers prove
it; never invent one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

hef234.py lineage in ~/workspace/.verify-tmp/aesir234 is the base for hef235 (hef234 = the hef233 base plus arms234, sha256 c59c2dcc…). Launch with unbuffered output (`python3 -u`) and capture the exit code to a .exit file, per TASK_CONTRACT_4.175_RETRY's proven terms. Window ranges in the new section MUST be bounded by the measured list lengths (A acts 749, B acts 751) — no index or rank beyond the last measured position (A index 748, B index 750, A-offset rank 748, B-offset rank 750) may be requested.

One bounded host-side child per contract. Exactly ONE launch: check `tmux ls` + `ps` on Mimir for an existing hef235/h235 child BEFORE launching.
