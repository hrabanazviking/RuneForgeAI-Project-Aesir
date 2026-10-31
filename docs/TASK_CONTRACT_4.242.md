# TASK_CONTRACT_4.242 (AES-NUM-242)

Scope (from AES-NUM-241's NEXT + TODO 4.242).
AES-NUM-241 compared the two closing runs' size
and channel sequences position by position; their
class and run-102 membership sequences have not
been compared position by position:
(i) the A closing run's class and run-102
membership sequences in full — the eight acts at
A-offset ranks 741-748 in rank order, with the
run's class sequence (base class per act, without
run/shift detail) and run-102 membership sequence
stated exactly.
(ii) the B closing run's class and run-102
membership sequences in full — the eight acts at
B-offset ranks 743-750 in rank order, with the
run's class sequence and run-102 membership
sequence stated exactly.
(iii) the closing-run class/run-102 comparison
— position by position (first through eighth
act): class on each side and whether the classes
agree at that position; run-102 membership on
each side and whether the memberships agree at
that position; the agreement counts over the
eight positions for classes and for memberships
stated exactly.
Tests: each run's printed class and membership
sequences equal the sequences read off the
per-act statements of AES-NUM-232..239 as
re-stated in AES-NUM-240 (A classes
[A-only distinct, A-only distinct, A-only
distinct, shared single-positioned, A-only
distinct, A-only distinct, A-only distinct,
A-only distinct], A run-102 membership
[False, False, False, True, False, False, False,
False]; B classes [B-only distinct x8], B run-102
membership [False x8]).
Any law NOT PROVEN unless the numbers prove
it; never invent one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

hef241.py lineage in ~/workspace/.verify-tmp/aesir241 is the base for hef242 (hef241 = the hef240 base plus arms241, sha256 117f7197…). Launch with unbuffered output (`python3 -u`) and capture the exit code to a .exit file, per TASK_CONTRACT_4.175_RETRY's proven terms. Window ranges in the new section MUST be bounded by the measured list lengths (A acts 749, B acts 751) — no index or rank beyond the last measured position (A index 748, B index 750, A-offset rank 748, B-offset rank 750) may be requested.

One bounded host-side child per contract. Exactly ONE launch: check `tmux ls` + `ps` on Mimir for an existing hef242/h242 child BEFORE launching.
