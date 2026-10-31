# TASK_CONTRACT_4.220 (AES-NUM-220)

Scope (from AES-NUM-219's NEXT + TODO 4.220).
AES-NUM-219's own output measured, in the
B-index and B-offset neighbourhoods of the
three acts given in full in 4.219, three
B-only acts that interleave with them but
have not themselves been given in full in
this sequence:
(i) the act at B 27 in full —
(873199616, 24, 2), measured at
B-offset rank 726.
Tests: the act in full on both sides
(indices, offset ranks, class, run and
shift, occurrences); its neighbourhoods in
both index orders and both offset orders;
its correspondence key in full.
(ii) the act at B 5 in full —
(1196182016, 24, 2), measured at
B-offset rank 728. Tests: as in (i), for
this act.
(iii) the act at B 6 in full —
(1196182528, 24, 0), measured at
B-offset rank 729. Tests: as in (i), for
this act.
Any law NOT PROVEN unless the numbers prove
it; never invent one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

hef219.py lineage in ~/workspace/.verify-tmp/aesir219 is the base for hef220 (hef219 = the hef218 base plus arms219, sha256 70180d88…). Launch with unbuffered output (`python3 -u`) and capture the exit code to a .exit file, per TASK_CONTRACT_4.175_RETRY's proven terms. Window ranges in the new section MUST be bounded by the measured list lengths (A acts 749, B acts 751) — no index or rank beyond the last measured position (A index 748, B index 750, A-offset rank 748, B-offset rank 750) may be requested.

One bounded host-side child per contract. Exactly ONE launch: check `tmux ls` + `ps` on Mimir for an existing hef220/h220 child BEFORE launching.
