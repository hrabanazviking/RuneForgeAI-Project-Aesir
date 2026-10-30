# TASK_CONTRACT_4.219 (AES-NUM-219)

Scope (from AES-NUM-218's NEXT + TODO 4.219).
AES-NUM-218's own output measured, in the
B-index and B-offset neighbourhoods of the
last three B indices, three B-only acts that
interleave with the acts given in full in
4.218 but have not themselves been given in
full in this sequence:
(i) the act at B 747 in full —
(791781888, 24, 0), measured at
B-offset rank 722.
Tests: the act in full on both sides
(indices, offset ranks, class, run and
shift, occurrences); its neighbourhoods in
both index orders and both offset orders;
its correspondence key in full.
(ii) the act at B 1 in full —
(873198592, 24, 0), measured at
B-offset rank 724. Tests: as in (i), for
this act.
(iii) the act at B 0 in full —
(873199104, 24, 1), measured at
B-offset rank 725. Tests: as in (i), for
this act.
Any law NOT PROVEN unless the numbers prove
it; never invent one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

hef218.py lineage in ~/workspace/.verify-tmp/aesir218 is the base for hef219 (hef218 = the hef217 base plus arms218, sha256 3d0ca59f…). Launch with unbuffered output (`python3 -u`) and capture the exit code to a .exit file, per TASK_CONTRACT_4.175_RETRY's proven terms. Window ranges in the new section MUST be bounded by the measured list lengths (A acts 749, B acts 751) — no index or rank beyond the last measured position (A index 748, B index 750, A-offset rank 748, B-offset rank 750) may be requested.

One bounded host-side child per contract. Exactly ONE launch: check `tmux ls` + `ps` on Mimir for an existing hef219/h219 child BEFORE launching.
