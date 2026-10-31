# TASK_CONTRACT_4.245 (AES-NUM-245)

Scope (from AES-NUM-244's NEXT + TODO 4.245).
AES-NUM-241..244 compared the two closing runs'
size/channel, class/run-102, offset/index and
gap sequences position by position, one sequence
family per slice; the combined comparison — all
four sequence families stated together, as
AES-NUM-240 combined AES-NUM-232..239 — has not
been stated:
(i) the A closing run's combined sequences in
full — its size, channel, class, run-102
membership, offset, index and gap sequences
(ranks 741-748), stated exactly together.
(ii) the B closing run's combined sequences in
full — the same seven sequences (ranks 743-750),
stated exactly together.
(iii) the closing-run combined comparison —
sequence family by sequence family: whether
each pair of sequences is identical and the
agreement count over its positions, stated
exactly for every family.
Tests: each printed sequence equals the
sequence measured in its own slice
(AES-NUM-241 size/channel, AES-NUM-242
class/run-102, AES-NUM-243 offset/index,
AES-NUM-244 gaps), and each printed agreement
count equals that slice's printed count.
Any law NOT PROVEN unless the numbers prove
it; never invent one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

hef244.py lineage in ~/workspace/.verify-tmp/aesir244 is the base for hef245 (hef244 = the hef243 base plus arms244, sha256 2d0d5ffc…). Launch with unbuffered output (`python3 -u`) and capture the exit code to a .exit file, per TASK_CONTRACT_4.175_RETRY's proven terms. Window ranges in the new section MUST be bounded by the measured list lengths (A acts 749, B acts 751) — no index or rank beyond the last measured position (A index 748, B index 750, A-offset rank 748, B-offset rank 750) may be requested.

One bounded host-side child per contract. Exactly ONE launch: check `tmux ls` + `ps` on Mimir for an existing hef245/h245 child BEFORE launching.
