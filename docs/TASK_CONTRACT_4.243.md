# TASK_CONTRACT_4.243 (AES-NUM-243)

Scope (from AES-NUM-242's NEXT + TODO 4.243).
AES-NUM-242 compared the two closing runs' class
and run-102 membership sequences position by
position; their offset and index sequences have
not been compared position by position:
(i) the A closing run's offset and index
sequences in full — the eight acts at A-offset
ranks 741-748 in rank order, with the run's
offset sequence (act[0] per act) and index
sequence (the act's index in context A per act)
stated exactly.
(ii) the B closing run's offset and index
sequences in full — the eight acts at B-offset
ranks 743-750 in rank order, with the run's
offset sequence and index sequence stated
exactly.
(iii) the closing-run offset/index comparison
— position by position (first through eighth
act): offset on each side and whether the
offsets agree at that position; index on each
side and whether the indices agree at that
position; the agreement counts over the eight
positions for offsets and for indices stated
exactly.
Tests: each run's printed offset and index
sequences equal the sequences read off the
per-act statements of AES-NUM-232..239 as
re-stated in AES-NUM-240 (A offsets
[791777280, 791777792, 791778304, 791778816,
791779328, 791779840, 791780352, 791780864],
A indices [734, 735, 736, 744, 745, 746, 747,
748]; B offsets [1196368696, 1196369408,
1196396032, 1196410880, 1196444160, 1196444672,
1196445184, 1196445696], B indices [26, 229,
272, 674, 735, 736, 737, 738]).
Any law NOT PROVEN unless the numbers prove
it; never invent one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

hef242.py lineage in ~/workspace/.verify-tmp/aesir242 is the base for hef243 (hef242 = the hef241 base plus arms242, sha256 e07625ff…). Launch with unbuffered output (`python3 -u`) and capture the exit code to a .exit file, per TASK_CONTRACT_4.175_RETRY's proven terms. Window ranges in the new section MUST be bounded by the measured list lengths (A acts 749, B acts 751) — no index or rank beyond the last measured position (A index 748, B index 750, A-offset rank 748, B-offset rank 750) may be requested.

One bounded host-side child per contract. Exactly ONE launch: check `tmux ls` + `ps` on Mimir for an existing hef243/h243 child BEFORE launching.
