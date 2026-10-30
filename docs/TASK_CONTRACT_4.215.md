# TASK_CONTRACT_4.215 (AES-NUM-215)

Scope (from AES-NUM-214's NEXT + TODO 4.215).
AES-NUM-214's own output measured, in
B-offset order, the run of ranks 737–744; the
three B-only acts sitting at ranks 745–747
have each been measured in earlier slices
(recorded in the progress doc and in the
hef214 raw output's own earlier sections)
but none has been given in full in this
sequence:
(i) the act at B 272 in full —
(1196396032, 14352, 1), measured at
B-offset rank 745 as the offset-order
successor of the B 229 act at rank 744.
Tests: the act in full on both sides
(indices, offset ranks, class, run and
shift, occurrences); its neighbourhoods in
both index orders and both offset orders;
its correspondence key in full.
(ii) the act at B 674 in full —
(1196410880, 32784, 2), measured at
B-offset rank 746. Tests: as in (i), for
this act.
(iii) the act at B 735 in full —
(1196444160, 24, 0), measured at
B-offset rank 747; and the B-offset-order
run of ranks 745–750 in full (each rank's
act, its B index, and the gap to the next
rank, stated exactly where a next rank
exists — rank 750 is the last measured
rank, so the run closes the B-offset
order). Tests: the act in full as in
(i); the run as stated.
Any law NOT PROVEN unless the numbers prove
it; never invent one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

hef214.py lineage in ~/workspace/.verify-tmp/aesir214 is the base for hef215 (hef214 = the hef213 base plus arms214, sha256 961e6bbf…). Launch with unbuffered output (`python3 -u`) and capture the exit code to a .exit file, per TASK_CONTRACT_4.175_RETRY's proven terms. Window ranges in the new section MUST be bounded by the measured list lengths (A acts 749, B acts 751) — no index or rank beyond the last measured position (A index 748, B index 750, A-offset rank 748, B-offset rank 750) may be requested.

One bounded host-side child per contract. Exactly ONE launch: check `tmux ls` + `ps` on Mimir for an existing hef215/h215 child BEFORE launching.
