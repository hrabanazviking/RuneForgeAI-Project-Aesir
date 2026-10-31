# TASK_CONTRACT_4.238 (AES-NUM-238)

Scope (from AES-NUM-237's NEXT + TODO 4.238).
AES-NUM-237 closed the two closing runs' sixth
acts side by side, but the seventh acts of the
two closing runs have not been set side by side
in this sequence:
(i) the act at A-offset rank 747 in full —
(791780352, 24, 2) at A 747, rank 747; the
seventh act of the A closing run (ranks 741-748),
with its incoming and outgoing gaps in A-offset
order stated exactly.
(ii) the act at B-offset rank 749 in full —
(1196445184, 24, 2) at B 737, rank 749; the
seventh act of the B closing run (ranks 743-750),
with its incoming and outgoing gaps in B-offset
order stated exactly.
(iii) the closing-run seventh-act comparison in
full — the seventh acts of the two closing runs
(A rank 747 and B rank 749) stated side by
side: rank, index, act, class, run-102
membership, incoming gap and outgoing gap per
seventh act. Tests: each seventh act's stated
outgoing gap equals the seventh gap of its own
run's gap sequence as measured in AES-NUM-231
(A run gap sequence [512, 512, 512, 512, 512,
512, 512], seventh gap 512; B run gap sequence
[712, 26624, 14848, 33280, 512, 512, 512],
seventh gap 512).
Any law NOT PROVEN unless the numbers prove
it; never invent one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

hef237.py lineage in ~/workspace/.verify-tmp/aesir237 is the base for hef238 (hef237 = the hef236 base plus arms237, sha256 0718e21f…). Launch with unbuffered output (`python3 -u`) and capture the exit code to a .exit file, per TASK_CONTRACT_4.175_RETRY's proven terms. Window ranges in the new section MUST be bounded by the measured list lengths (A acts 749, B acts 751) — no index or rank beyond the last measured position (A index 748, B index 750, A-offset rank 748, B-offset rank 750) may be requested.

One bounded host-side child per contract. Exactly ONE launch: check `tmux ls` + `ps` on Mimir for an existing hef238/h238 child BEFORE launching.
