# TASK_CONTRACT_4.232 (AES-NUM-232)

Scope (from AES-NUM-231's NEXT + TODO 4.232).
AES-NUM-231 closed the B-offset order's last
act and its closing run's first act and set the
two closing runs side by side, but the acts
immediately before each closing run's first act
and the two first acts themselves have not been
set side by side in this sequence:
(i) the act at B-offset rank 742 in full —
(1196338688, 30008, 2) at B 25, rank 742; the
act immediately before the B closing run's
first act, with its incoming and outgoing gaps
in B-offset order stated exactly.
(ii) the act at A-offset rank 741 in full —
(791777280, 24, 1) at A 734, rank 741; the
first act of the A closing run (ranks 741-748),
with its incoming and outgoing gaps in A-offset
order stated exactly.
(iii) the closing-run first-act comparison in
full — the first acts of the two closing runs
(A rank 741 and B rank 743) stated side by
side: rank, index, act, class, run-102
membership, incoming gap and outgoing gap per
first act. Tests: each first act's stated
outgoing gap equals the first gap of its own
run's gap sequence as measured in AES-NUM-231.
Any law NOT PROVEN unless the numbers prove
it; never invent one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

hef231.py lineage in ~/workspace/.verify-tmp/aesir231 is the base for hef232 (hef231 = the hef230 base plus arms231, sha256 1889ace3…). Launch with unbuffered output (`python3 -u`) and capture the exit code to a .exit file, per TASK_CONTRACT_4.175_RETRY's proven terms. Window ranges in the new section MUST be bounded by the measured list lengths (A acts 749, B acts 751) — no index or rank beyond the last measured position (A index 748, B index 750, A-offset rank 748, B-offset rank 750) may be requested.

One bounded host-side child per contract. Exactly ONE launch: check `tmux ls` + `ps` on Mimir for an existing hef232/h232 child BEFORE launching.
