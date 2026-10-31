# TASK_CONTRACT_4.241 (AES-NUM-241)

Scope (from AES-NUM-240's NEXT + TODO 4.241).
AES-NUM-240 set the two closing runs side by
side in full; their size and channel sequences
have not been compared position by position:
(i) the A closing run's size and channel
sequences in full — the eight acts at A-offset
ranks 741-748 in rank order, with the run's
size sequence and channel sequence stated
exactly.
(ii) the B closing run's size and channel
sequences in full — the eight acts at B-offset
ranks 743-750 in rank order, with the run's
size sequence and channel sequence stated
exactly.
(iii) the closing-run size/channel comparison
— position by position (first through eighth
act): size on each side and whether the sizes
agree at that position; channel on each side
and whether the channels agree at that
position; the agreement counts over the eight
positions for sizes and for channels stated
exactly.
Tests: each run's printed size and channel
sequences equal the sequences read off the
per-act statements of AES-NUM-232..239 as
re-stated in AES-NUM-240 (A sizes
[24, 24, 24, 24, 24, 24, 24, 24], A channels
[1, 2, 0, 0, 0, 1, 2, 0]; B sizes
[280, 26128, 14352, 32784, 24, 24, 24, 24],
B channels [2, 2, 1, 2, 0, 1, 2, 0]).
Any law NOT PROVEN unless the numbers prove
it; never invent one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

hef240.py lineage in ~/workspace/.verify-tmp/aesir240 is the base for hef241 (hef240 = the hef239 base plus arms240, sha256 32decec8…). Launch with unbuffered output (`python3 -u`) and capture the exit code to a .exit file, per TASK_CONTRACT_4.175_RETRY's proven terms. Window ranges in the new section MUST be bounded by the measured list lengths (A acts 749, B acts 751) — no index or rank beyond the last measured position (A index 748, B index 750, A-offset rank 748, B-offset rank 750) may be requested.

One bounded host-side child per contract. Exactly ONE launch: check `tmux ls` + `ps` on Mimir for an existing hef241/h241 child BEFORE launching.
