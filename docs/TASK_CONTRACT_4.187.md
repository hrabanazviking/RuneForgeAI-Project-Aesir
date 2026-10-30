# TASK_CONTRACT_4.187 (AES-NUM-187)

Scope (from AES-NUM-186's NEXT + TODO 4.187):
(i) the B-only act at B 14 in full — the act
(1196257280, 14416, 1), measured in AES-NUM-186
at B-offset rank 734, following B 13 (rank 733)
in both B-index order and B-offset order, its
incoming gap +32768 exactly B 13's size.
Tests: the act in full (its act, B index,
B-offset rank, class, occurrences in both
contexts); its B-index neighbourhood in full;
its B-offset-order neighbourhood in full;
whether it has an A-side counterpart act in
context A; its correspondence key in full
(any act in A or B under its (offset, size)
key).
(ii) the B-only acts at B 15 and B 16 in
full — the acts (1196271696, 376, 1) at
B-offset rank 735 and (1196272072, 24, 1) at
B-offset rank 736, measured in AES-NUM-186,
continuing the B-offset run past rank 734
(gaps +14416 from B 14 to B 15, +376 from
B 15 to B 16, each exactly the lower act's
size). Tests: as in (i), for each act, on the
B side (B index, B-offset rank, A-side
counterpart, correspondence key); plus the
three acts at ranks 734-736 in rank order
with their offset gaps and (size, channel)
sequence.
(iii) the shared run-97 act that follows the
run-96 act in full — (791326720, 32784, 2) at
A 677 / B 377, measured in AES-NUM-186 at
A-offset rank 714 and B-offset rank 695; the
secondary run table places run 97 immediately
after run 96, and AES-NUM-186's neighbourhoods
give run 97's shift as -300. Tests: the act
in full on both sides (indices, both offset
ranks, class, run and shift, occurrences);
its neighbourhoods in both index orders and
both offset orders. Any law NOT PROVEN
unless the numbers prove it; never invent
one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

hef186.py lineage in ~/workspace/.verify-tmp/aesir186 is the base for hef187 (hef186 = the hef185 base plus arms186, sha256 802eee9e…). Launch with unbuffered output (`python3 -u`) and capture the exit code to a .exit file, per TASK_CONTRACT_4.175_RETRY's proven terms.

One bounded host-side child per contract. Exactly ONE launch: check `tmux ls` + `ps` on Mimir for an existing hef187/h187 child BEFORE launching.
