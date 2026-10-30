# TASK_CONTRACT_4.189 (AES-NUM-189)

Scope (from AES-NUM-188's NEXT + TODO 4.189):
(i) the B-only act at B 22 in full — the act
(1196313088, 24848, 1), measured in AES-NUM-188
at B-offset rank 740, following B 20 (rank 739)
in both B-index order and B-offset order, its
incoming gap +480 (not B 20's size 328).
Tests: the act in full (its act, B index,
B-offset rank, class, occurrences in both
contexts); its B-index neighbourhood in full;
its B-offset-order neighbourhood in full;
whether it has an A-side counterpart act in
context A; its correspondence key in full
(any act in A or B under its (offset, size)
key).
(ii) the B-only acts at B 23 and B 25 in
full — the acts (1196337936, 264, 1) at
B-offset rank 741 and (1196338688, 30008, 2) at
B-offset rank 742, measured in AES-NUM-188,
continuing the B-offset run past rank 740
(gap +24848 from B 22 to B 23, exactly B 22's
size; gap +752 from B 23 to B 25, an excess of
488 over B 23's size 264). Tests: as in
(i), for each act, on the B side (B index,
B-offset rank, A-side counterpart,
correspondence key); plus the three acts at
ranks 740-742 in rank order with their
offset gaps and (size, channel) sequence.
(iii) the shared run-99 act that follows the
run-98 act in full — (791386624, 32784, 2) at
A 679 / B 401, measured in AES-NUM-188 at
A-offset rank 716 and B-offset rank 697; the
secondary run table places run 99 immediately
after run 98, and AES-NUM-188's neighbourhoods
give run 99's shift as -278. Tests: the act
in full on both sides (indices, both offset
ranks, class, run and shift, occurrences);
its neighbourhoods in both index orders and
both offset orders. Any law NOT PROVEN
unless the numbers prove it; never invent
one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

hef188.py lineage in ~/workspace/.verify-tmp/aesir188 is the base for hef189 (hef188 = the hef187 base plus arms188, sha256 aea1e7df…). Launch with unbuffered output (`python3 -u`) and capture the exit code to a .exit file, per TASK_CONTRACT_4.175_RETRY's proven terms.

One bounded host-side child per contract. Exactly ONE launch: check `tmux ls` + `ps` on Mimir for an existing hef189/h189 child BEFORE launching.
