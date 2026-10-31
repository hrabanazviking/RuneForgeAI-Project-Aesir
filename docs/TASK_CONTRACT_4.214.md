# TASK_CONTRACT_4.214 (AES-NUM-214)

Scope (from AES-NUM-213's NEXT + TODO 4.214).
AES-NUM-213's own output measured, in
B-offset order, the run of ranks 729–736; the
three B-only acts sitting at ranks 737–739
have each been measured in earlier slices
(AES-NUM-180, recorded in the progress doc)
but none has been given in full in this
sequence:
(i) the act at B 17 in full —
(1196272096, 32728, 1), measured at
B-offset rank 737 as the offset-order
successor of the B 16 act at rank 736.
Tests: the act in full on both sides
(indices, offset ranks, class, run and
shift, occurrences); its neighbourhoods in
both index orders and both offset orders;
its correspondence key in full.
(ii) the act at B 19 in full —
(1196304896, 7712, 0), measured at
B-offset rank 738. Tests: as in (i), for
this act.
(iii) the act at B 20 in full —
(1196312608, 328, 0), measured at
B-offset rank 739; and the B-offset-order
run of ranks 737–744 in full (each rank's
act, its B index, and the gap to the next
rank, stated exactly where a next rank
exists). Tests: the act in full as in
(i); the run as stated.
Any law NOT PROVEN unless the numbers prove
it; never invent one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

hef213.py lineage in ~/workspace/.verify-tmp/aesir213 is the base for hef214 (hef213 = the hef212 base plus arms213, sha256 9ba09312…). Launch with unbuffered output (`python3 -u`) and capture the exit code to a .exit file, per TASK_CONTRACT_4.175_RETRY's proven terms. Window ranges in the new section MUST be bounded by the measured list lengths (A acts 749, B acts 751) — no index or rank beyond the last measured position (A index 748, B index 750, A-offset rank 748, B-offset rank 750) may be requested.

One bounded host-side child per contract. Exactly ONE launch: check `tmux ls` + `ps` on Mimir for an existing hef214/h214 child BEFORE launching.
