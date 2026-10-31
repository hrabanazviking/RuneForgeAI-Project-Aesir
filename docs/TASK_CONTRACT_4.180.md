# TASK_CONTRACT_4.180 (AES-NUM-180)

Scope (from AES-NUM-179's NEXT + TODO 4.180):
(i) the B-offset-order acts at ranks 737–742 in
full — AES-NUM-179's extended range measured them
as B-only acts at B indices 17 (1196272096,
32728, 1), 19 (1196304896, 7712, 0), 20
(1196312608, 328, 0), 22 (1196313088, 24848, 1),
23 (1196337936, 264, 1) and 25 (1196338688,
30008, 2), none yet given in full. Tests: each
act in full (its act, B index, B-offset rank,
class, occurrences in both contexts); its
B-index neighbourhood in full; its B-offset-order
neighbourhood in full; whether any of these acts
has an A-side counterpart act in context A, and
if so where. Any law NOT PROVEN unless the
numbers prove it; never invent one.
(ii) the four B-only interrupter acts at B
735–738 in full — AES-NUM-179 measured them
inside run 102's B neighbourhood as the B-only
24 B acts (1196444160, 24, 0), (1196444672, 24,
1), (1196445184, 24, 2) and (1196445696, 24, 0)
at consecutive +512 offset steps, channels
0, 1, 2, 0, sitting between run 102's two B
blocks, none yet given in full and their
B-offset ranks not yet measured. Tests: each
act in full (its act, B index, B-offset rank,
class, occurrences in both contexts); its
B-index neighbourhood in full; its
B-offset-order neighbourhood in full; whether
any has an A-side counterpart. Any law NOT
PROVEN unless the numbers prove it; never
invent one.
(iii) the four A-only acts at A 733–736 in full
— AES-NUM-179 measured them inside run 102's A
neighbourhood as the A-only 24 B acts
(791776792, 24, 0), (791777280, 24, 1),
(791777792, 24, 2) and (791778304, 24, 0),
separating run 102's two blocks on the A side,
none yet given in full. Tests: each act in full
(its act, A index, A-offset rank, class,
occurrences in both contexts); its A-index
neighbourhood in full; its A-offset-order
neighbourhood in full; whether any has a B-side
counterpart act in context B, and if so where;
their correspondence-key relation to the
B-only interrupters of (ii). Any law NOT PROVEN
unless the numbers prove it; never invent one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

hef179.py lineage in ~/workspace/.verify-tmp/aesir179 is the base for hef180 (hef179 = the hef178 base plus arms179, sha256 20f1b3a0…). Launch with unbuffered output (`python3 -u`) and capture the exit code to a .exit file, per TASK_CONTRACT_4.175_RETRY's proven terms.

One bounded host-side child per contract. Exactly ONE launch: check `tmux ls` + `ps` on Mimir for an existing hef180/h180 child BEFORE launching.
