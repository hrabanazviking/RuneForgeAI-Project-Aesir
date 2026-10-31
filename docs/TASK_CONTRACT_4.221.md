# TASK_CONTRACT_4.221 (AES-NUM-221)

Scope (from AES-NUM-220's NEXT + TODO 4.221).
AES-NUM-220's own output measured, in the
B-index and B-offset neighbourhoods of the
three acts given in full in 4.220, three
B-only acts that interleave with them but
have not themselves been given in full in
this sequence:
(i) the act at B 8 in full —
(1196183040, 32784, 1), measured at
B-offset rank 730.
Tests: the act in full on both sides
(indices, offset ranks, class, run and
shift, occurrences); its neighbourhoods in
both index orders and both offset orders;
its correspondence key in full.
(ii) the act at B 10 in full —
(1196216320, 7800, 2), measured at
B-offset rank 731. Tests: as in (i), for
this act.
(iii) the act at B 11 in full —
(1196224120, 344, 2), measured at
B-offset rank 732. Tests: as in (i), for
this act.
Any law NOT PROVEN unless the numbers prove
it; never invent one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

hef220.py lineage in ~/workspace/.verify-tmp/aesir220 is the base for hef221 (hef220 = the hef219 base plus arms220, sha256 ee13cbdd…). Launch with unbuffered output (`python3 -u`) and capture the exit code to a .exit file, per TASK_CONTRACT_4.175_RETRY's proven terms. Window ranges in the new section MUST be bounded by the measured list lengths (A acts 749, B acts 751) — no index or rank beyond the last measured position (A index 748, B index 750, A-offset rank 748, B-offset rank 750) may be requested.

One bounded host-side child per contract. Exactly ONE launch: check `tmux ls` + `ps` on Mimir for an existing hef221/h221 child BEFORE launching.
