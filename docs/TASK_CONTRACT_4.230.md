# TASK_CONTRACT_4.230 (AES-NUM-230)

Scope (from AES-NUM-229's NEXT + TODO 4.230).
AES-NUM-229 closed the A-offset order and took
its census, but the last A-offset act and the
closing run's sole shared act have not been
given in full in this sequence, and the two
orders' censuses have not been set side by side:
(i) the act at A-offset rank 748 in full —
(791780864, 24, 0) at A 748, rank 748; rank 748
is the last measured A-offset rank (A acts 749,
ranks 0-748), so no outgoing gap exists for it
in A-offset order and none may be requested;
its incoming gap is stated where a predecessor
exists.
(ii) the act at A-offset rank 744 in full —
(791778816, 24, 0) at A 744, rank 744; the sole
shared single-positioned act in the A closing
run (ranks 741-748) and the last act of
run 102, with its incoming and outgoing gaps
in A-offset order stated exactly.
(iii) the cross-order census comparison in
full — the A-offset-order census of
AES-NUM-229 and the B-offset-order census of
AES-NUM-228 stated side by side: acts total
and rank range per order, first and last act
per order, class census per order on the same
base classes, and run-102 membership count
per order. Tests: each order's class census
sums to its own acts total; first and last
acts of each order stated exactly.
Any law NOT PROVEN unless the numbers prove
it; never invent one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

hef229.py lineage in ~/workspace/.verify-tmp/aesir229 is the base for hef230 (hef229 = the hef228 base plus arms229, sha256 9f4beeb8…). Launch with unbuffered output (`python3 -u`) and capture the exit code to a .exit file, per TASK_CONTRACT_4.175_RETRY's proven terms. Window ranges in the new section MUST be bounded by the measured list lengths (A acts 749, B acts 751) — no index or rank beyond the last measured position (A index 748, B index 750, A-offset rank 748, B-offset rank 750) may be requested.

One bounded host-side child per contract. Exactly ONE launch: check `tmux ls` + `ps` on Mimir for an existing hef230/h230 child BEFORE launching.
