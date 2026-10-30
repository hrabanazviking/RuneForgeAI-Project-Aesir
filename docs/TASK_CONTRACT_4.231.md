# TASK_CONTRACT_4.231 (AES-NUM-231)

Scope (from AES-NUM-230's NEXT + TODO 4.231).
AES-NUM-230 closed the A-offset order's last
acts and compared the two orders' censuses, but
the B-offset order's last act and its closing
run's first act have not been given in full in
this sequence, and the two closing runs have
not been set side by side:
(i) the act at B-offset rank 750 in full —
(1196445696, 24, 0) at B 738, rank 750; rank 750
is the last measured B-offset rank (B acts 751,
ranks 0-750), so no outgoing gap exists for it
in B-offset order and none may be requested;
its incoming gap is stated where a predecessor
exists.
(ii) the act at B-offset rank 743 in full —
(1196368696, 280, 2) at B 26, rank 743; the
first act of the B closing run (ranks 743-750),
with its incoming and outgoing gaps in B-offset
order stated exactly.
(iii) the closing-run comparison in full — the
A closing run of AES-NUM-229 (ranks 741-748)
and the B closing run of AES-NUM-228 (ranks
743-750) stated side by side: rank range and
act count per run, class composition per run,
run-102 membership per run, and the gap
sequence inside each run. Tests: each run
holds exactly 8 acts; each run's class
composition sums to 8.
Any law NOT PROVEN unless the numbers prove
it; never invent one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

hef230.py lineage in ~/workspace/.verify-tmp/aesir230 is the base for hef231 (hef230 = the hef229 base plus arms230, sha256 528eaccb…). Launch with unbuffered output (`python3 -u`) and capture the exit code to a .exit file, per TASK_CONTRACT_4.175_RETRY's proven terms. Window ranges in the new section MUST be bounded by the measured list lengths (A acts 749, B acts 751) — no index or rank beyond the last measured position (A index 748, B index 750, A-offset rank 748, B-offset rank 750) may be requested.

One bounded host-side child per contract. Exactly ONE launch: check `tmux ls` + `ps` on Mimir for an existing hef231/h231 child BEFORE launching.
