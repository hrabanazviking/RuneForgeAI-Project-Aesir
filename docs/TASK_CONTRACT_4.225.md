# TASK_CONTRACT_4.225 (AES-NUM-225)

Scope (from AES-NUM-224's NEXT + TODO 4.225).
AES-NUM-224's own output measured, in the
B-index and B-offset neighbourhoods of the
three acts given in full in 4.224, three
B-only acts that follow them in B-offset
order but have not themselves been given in
full in this sequence:
(i) the act at B 25 in full —
(1196338688, 30008, 2), measured at
B-offset rank 742.
Tests: the act in full on both sides
(indices, offset ranks, class, run and
shift, occurrences); its neighbourhoods in
both index orders and both offset orders;
its correspondence key in full.
(ii) the act at B 26 in full —
(1196368696, 280, 2), measured at
B-offset rank 743. Tests: as in (i), for
this act.
(iii) the act at B 229 in full —
(1196369408, 26128, 2), measured at
B-offset rank 744. Tests: as in (i), for
this act.
Any law NOT PROVEN unless the numbers prove
it; never invent one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

hef224.py lineage in ~/workspace/.verify-tmp/aesir224 is the base for hef225 (hef224 = the hef223 base plus arms224, sha256 881bbd4e…). Launch with unbuffered output (`python3 -u`) and capture the exit code to a .exit file, per TASK_CONTRACT_4.175_RETRY's proven terms. Window ranges in the new section MUST be bounded by the measured list lengths (A acts 749, B acts 751) — no index or rank beyond the last measured position (A index 748, B index 750, A-offset rank 748, B-offset rank 750) may be requested.

One bounded host-side child per contract. Exactly ONE launch: check `tmux ls` + `ps` on Mimir for an existing hef225/h225 child BEFORE launching.
