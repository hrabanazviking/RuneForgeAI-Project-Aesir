# TASK_CONTRACT_4.227 (AES-NUM-227)

Scope (from AES-NUM-226's NEXT + TODO 4.227).
AES-NUM-226's own output measured, in the
B-index and B-offset neighbourhoods of the
three acts given in full in 4.226, three
B-only acts that follow them in B-offset
order but have not themselves been given in
full in this sequence — the final three
B-offset ranks (748, 749, 750 of 750):
(i) the act at B 736 in full —
(1196444672, 24, 1), measured at
B-offset rank 748.
Tests: the act in full on both sides
(indices, offset ranks, class, run and
shift, occurrences); its neighbourhoods in
both index orders and both offset orders;
its correspondence key in full.
(ii) the act at B 737 in full —
(1196445184, 24, 2), measured at
B-offset rank 749. Tests: as in (i), for
this act.
(iii) the act at B 738 in full —
(1196445696, 24, 0), measured at
B-offset rank 750. Tests: as in (i), for
this act. Rank 750 is the last measured
B-offset rank: no outgoing gap exists for
it and none may be requested.
Any law NOT PROVEN unless the numbers prove
it; never invent one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

hef226.py lineage in ~/workspace/.verify-tmp/aesir226 is the base for hef227 (hef226 = the hef225 base plus arms226, sha256 591ac4af…). Launch with unbuffered output (`python3 -u`) and capture the exit code to a .exit file, per TASK_CONTRACT_4.175_RETRY's proven terms. Window ranges in the new section MUST be bounded by the measured list lengths (A acts 749, B acts 751) — no index or rank beyond the last measured position (A index 748, B index 750, A-offset rank 748, B-offset rank 750) may be requested.

One bounded host-side child per contract. Exactly ONE launch: check `tmux ls` + `ps` on Mimir for an existing hef227/h227 child BEFORE launching.
