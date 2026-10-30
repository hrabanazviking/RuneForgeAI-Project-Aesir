# TASK_CONTRACT_4.190 (AES-NUM-190)

Scope (from AES-NUM-189's NEXT + TODO 4.190):
(i) the B-only act at B 26 in full — the act
(1196368696, 280, 2), measured in AES-NUM-189
at B-offset rank 743, following B 25 (rank 742)
in both B-index order and B-offset order, its
incoming gap +30008 exactly B 25's size.
Tests: the act in full (its act, B index,
B-offset rank, class, occurrences in both
contexts); its B-index neighbourhood in full;
its B-offset-order neighbourhood in full;
whether it has an A-side counterpart act in
context A; its correspondence key in full
(any act in A or B under its (offset, size)
key).
(ii) the B-only acts at B 229 and B 272 in
full — the acts (1196369408, 26128, 2) at
B-offset rank 744 and (1196396032, 14352, 1) at
B-offset rank 745, measured in AES-NUM-189,
continuing the B-offset run past rank 743
(gap +712 from B 26 to B 229, an excess of
432 over B 26's size 280; gap +26624 from
B 229 to B 272, an excess of 496 over B 229's
size 26128). Tests: as in
(i), for each act, on the B side (B index,
B-offset rank, A-side counterpart,
correspondence key); plus the three acts at
ranks 743-745 in rank order with their
offset gaps and (size, channel) sequence.
(iii) the shared run-100 act that follows the
run-99 act in full — (791419904, 32784, 2) at
A 680 / B 228, measured in AES-NUM-189 at
A-offset rank 717 and B-offset rank 698; the
secondary run table places run 100 immediately
after run 99, and AES-NUM-189's neighbourhoods
give run 100's shift as -452. Tests: the act
in full on both sides (indices, both offset
ranks, class, run and shift, occurrences);
its neighbourhoods in both index orders and
both offset orders. Any law NOT PROVEN
unless the numbers prove it; never invent
one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

hef189.py lineage in ~/workspace/.verify-tmp/aesir189 is the base for hef190 (hef189 = the hef188 base plus arms189, sha256 dc1278b8…). Launch with unbuffered output (`python3 -u`) and capture the exit code to a .exit file, per TASK_CONTRACT_4.175_RETRY's proven terms.

One bounded host-side child per contract. Exactly ONE launch: check `tmux ls` + `ps` on Mimir for an existing hef190/h190 child BEFORE launching.
