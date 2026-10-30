# TASK_CONTRACT_4.218 (AES-NUM-218)

Scope (from AES-NUM-217's NEXT + TODO 4.218).
AES-NUM-217's own output measured, in the
B-index neighbourhoods and earlier sections,
the last three B indices of context B; the
three B-only acts sitting at B indices
748–750 (B acts 751, indices 0–750) have
each been measured in earlier slices (recorded
in the hef217 raw output's own earlier
sections) but none has been given in full in
this sequence:
(i) the act at B 748 in full —
(791781376, 24, 1), measured at
B-offset rank 721.
Tests: the act in full on both sides
(indices, offset ranks, class, run and
shift, occurrences); its neighbourhoods in
both index orders and both offset orders;
its correspondence key in full.
(ii) the act at B 749 in full —
(800053760, 24, 2), measured at
B-offset rank 723. Tests: as in (i), for
this act.
(iii) the act at B 750 in full —
(973679616, 24, 0), measured at
B-offset rank 727; and the B-index-order
closure in full (index 750 is the last
measured index — B acts 751, indices 0–750 —
so no index beyond 750 may be requested).
Tests: the act in full as in (i); the
closure as stated.
Any law NOT PROVEN unless the numbers prove
it; never invent one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

hef217.py lineage in ~/workspace/.verify-tmp/aesir217 is the base for hef218 (hef217 = the hef216 base plus arms217, sha256 0f0b7d30…). Launch with unbuffered output (`python3 -u`) and capture the exit code to a .exit file, per TASK_CONTRACT_4.175_RETRY's proven terms. Window ranges in the new section MUST be bounded by the measured list lengths (A acts 749, B acts 751) — no index or rank beyond the last measured position (A index 748, B index 750, A-offset rank 748, B-offset rank 750) may be requested.

One bounded host-side child per contract. Exactly ONE launch: check `tmux ls` + `ps` on Mimir for an existing hef218/h218 child BEFORE launching.
