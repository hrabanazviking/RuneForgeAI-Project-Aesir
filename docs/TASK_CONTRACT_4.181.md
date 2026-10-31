# TASK_CONTRACT_4.181 (AES-NUM-181)

Scope (from AES-NUM-180's NEXT + TODO 4.181):
(i) the B-offset-order acts at ranks 743–746 in
full — AES-NUM-180's full range measured them
as B-only acts at B indices 26 (1196368696,
280, 2), 229 (1196369408, 26128, 2), 272
(1196396032, 14352, 1) and 674 (1196410880,
32784, 2), none yet given in full. Tests: each
act in full (its act, B index, B-offset rank,
class, occurrences in both contexts); its
B-index neighbourhood in full; its B-offset-order
neighbourhood in full; whether any of these acts
has an A-side counterpart act in context A, and
if so where. Any law NOT PROVEN unless the
numbers prove it; never invent one.
(ii) the A-only acts at A 745–747 in full —
AES-NUM-179 measured context A continuing after
run 102's last act with A-only acts at A
745–747, and AES-NUM-180 measured A 745
(791779328, 24, 0) at A-offset rank 745 and
A 746 (791779840, 24, 1) at A-offset rank 746
inside its A-offset neighbourhoods, none yet
given in full. Tests: each act in full (its
act, A index, A-offset rank, class, occurrences
in both contexts); its A-index neighbourhood
in full; its A-offset-order neighbourhood in
full; whether any has a B-side counterpart act
in context B, and if so where; their
correspondence-key relation to any B-side acts.
Any law NOT PROVEN unless the numbers prove
it; never invent one.
(iii) the A-offset-order acts at ranks
744–748 in full — AES-NUM-180 measured rank
744 as the shared run-102 act at A 744
(791778816, 24, 0) and ranks 745–746 as the
A-only acts of (ii); ranks 747–748 are not yet
measured. Tests: each act in full (its act,
A index, A-offset rank, class, occurrences in
both contexts); its A-index neighbourhood in
full; its A-offset-order neighbourhood in
full; whether any shared act among them is
single-positioned and, if so, its run and
shift, and whether any non-shared act has a
counterpart on the other side. Any law NOT
PROVEN unless the numbers prove it; never
invent one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

hef180.py lineage in ~/workspace/.verify-tmp/aesir180 is the base for hef181 (hef180 = the hef179 base plus arms180, sha256 14bc4c1d…). Launch with unbuffered output (`python3 -u`) and capture the exit code to a .exit file, per TASK_CONTRACT_4.175_RETRY's proven terms.

One bounded host-side child per contract. Exactly ONE launch: check `tmux ls` + `ps` on Mimir for an existing hef181/h181 child BEFORE launching.
