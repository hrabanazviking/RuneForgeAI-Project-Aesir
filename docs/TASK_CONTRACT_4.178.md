# TASK_CONTRACT_4.178 (AES-NUM-178)

Scope (from AES-NUM-177's NEXT + TODO 4.178):
(i) the B-offset-order window's upper acts at
ranks 728–732 in full — AES-NUM-177 measured the
window ranks 718–732: ranks 728–732 are B-only
acts at B indices 5 (1196182016, 24, 2), 6
(1196182528, 24, 0), 8 (1196183040, 32784, 1),
10 (1196216320, 7800, 2) and 11 (1196224120,
344, 2), none yet given in full; and the
window's lower shared boundary at ranks
718–720 in full (the shared run-102 acts at B
indices 733, 734, 746). Tests: each act in full
(its act, B index, B-offset rank, class,
occurrences in both contexts); its B-index
neighbourhood in full; its B-offset-order
neighbourhood in full; whether any of these
acts has an A-side counterpart act in context
A, and if so where. Any law NOT PROVEN unless
the numbers prove it; never invent one.
(ii) runs 96 and 97 in full — AES-NUM-177's run
table measured run 96 as a −283 singleton at
A 676 / B 393 and its A neighbourhood measured
run 97 as a −300 act at A 677 / B 377, neither
yet given in full. Tests: secondary runs 96
and 97 in full (acts, A/B extents, shifts, B
contiguity); their B neighbourhoods in full;
their A neighbourhoods in full. Any law NOT
PROVEN unless the numbers prove it; never
invent one.
(iii) runs 98 and 99 in full — not yet measured
in this line. Tests: secondary runs 98 and 99
in full (acts, A/B extents, shifts, B
contiguity); their B neighbourhoods in full;
their A neighbourhoods in full. Any law NOT
PROVEN unless the numbers prove it; never
invent one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

hef177.py lineage in ~/workspace/.verify-tmp/aesir177 is the base for hef178 (hef177 = the hef176 base plus arms177, sha256 f92d5efa…). Launch with unbuffered output (`python3 -u`) and capture the exit code to a .exit file, per TASK_CONTRACT_4.175_RETRY's proven terms.

One bounded host-side child per contract. Exactly ONE launch: check `tmux ls` + `ps` on Mimir for an existing hef178/h178 child BEFORE launching.
