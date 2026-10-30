# TASK_CONTRACT_4.216 (AES-NUM-216)

Scope (from AES-NUM-215's NEXT + TODO 4.216).
AES-NUM-215's own output measured, in
B-offset order, the closing run of ranks
745–750; the three B-only acts sitting at
ranks 748–750 have each been measured in
earlier slices (recorded in the progress
doc and in the hef215 raw output's own
earlier sections) but none has been given
in full in this sequence:
(i) the act at B 736 in full —
(1196444672, 24, 1), measured at
B-offset rank 748 as the offset-order
successor of the B 735 act at rank 747.
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
B-offset rank 750; and the B-offset-order
closure in full (rank 750 is the last
measured rank — B acts 751, ranks 0–750 —
so its gap to a next rank is None and no
rank beyond 750 may be requested).
Tests: the act in full as in (i); the
closure as stated.
Any law NOT PROVEN unless the numbers prove
it; never invent one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

hef215.py lineage in ~/workspace/.verify-tmp/aesir215 is the base for hef216 (hef215 = the hef214 base plus arms215, sha256 816f845c…). Launch with unbuffered output (`python3 -u`) and capture the exit code to a .exit file, per TASK_CONTRACT_4.175_RETRY's proven terms. Window ranges in the new section MUST be bounded by the measured list lengths (A acts 749, B acts 751) — no index or rank beyond the last measured position (A index 748, B index 750, A-offset rank 748, B-offset rank 750) may be requested.

One bounded host-side child per contract. Exactly ONE launch: check `tmux ls` + `ps` on Mimir for an existing hef216/h216 child BEFORE launching.
