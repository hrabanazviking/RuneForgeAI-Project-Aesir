# TASK_CONTRACT_4.233 (AES-NUM-233)

Scope (from AES-NUM-232's NEXT + TODO 4.233).
AES-NUM-232 closed the two closing runs' first
acts side by side, but the second acts of the
two closing runs have not been set side by side
in this sequence:
(i) the act at A-offset rank 742 in full —
(791777792, 24, 2) at A 735, rank 742; the
second act of the A closing run (ranks 741-748),
with its incoming and outgoing gaps in A-offset
order stated exactly.
(ii) the act at B-offset rank 744 in full —
(1196369408, 26128, 2) at B 229, rank 744; the
second act of the B closing run (ranks 743-750),
with its incoming and outgoing gaps in B-offset
order stated exactly.
(iii) the closing-run second-act comparison in
full — the second acts of the two closing runs
(A rank 742 and B rank 744) stated side by
side: rank, index, act, class, run-102
membership, incoming gap and outgoing gap per
second act. Tests: each second act's stated
outgoing gap equals the second gap of its own
run's gap sequence as measured in AES-NUM-231
(A run gap sequence [512, 512, 512, 512, 512,
512, 512], second gap 512; B run gap sequence
[712, 26624, 14848, 33280, 512, 512, 512],
second gap 26624).
Any law NOT PROVEN unless the numbers prove
it; never invent one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

hef232.py lineage in ~/workspace/.verify-tmp/aesir232 is the base for hef233 (hef232 = the hef231 base plus arms232, sha256 eabb65fa…). Launch with unbuffered output (`python3 -u`) and capture the exit code to a .exit file, per TASK_CONTRACT_4.175_RETRY's proven terms. Window ranges in the new section MUST be bounded by the measured list lengths (A acts 749, B acts 751) — no index or rank beyond the last measured position (A index 748, B index 750, A-offset rank 748, B-offset rank 750) may be requested.

One bounded host-side child per contract. Exactly ONE launch: check `tmux ls` + `ps` on Mimir for an existing hef233/h233 child BEFORE launching.
