# TASK_CONTRACT_4.186 (AES-NUM-186)

Scope (from AES-NUM-185's NEXT + TODO 4.186):
(i) the B-only act at B 10 in full — the act
(1196216320, 7800, 2), measured in AES-NUM-185
at B-offset rank 731, following B 8 (rank 730)
in both B-index order and B-offset order.
Tests: the act in full (its act, B index,
B-offset rank, class, occurrences in both
contexts); its B-index neighbourhood in full;
its B-offset-order neighbourhood in full;
whether it has an A-side counterpart act in
context A; its correspondence key in full
(any act in A or B under its (offset, size)
key).
(ii) the B-only acts at B 11 and B 13 in
full — the acts (1196224120, 344, 2) at
B-offset rank 732 and (1196224512, 32768, 1)
at B-offset rank 733, measured in AES-NUM-185,
continuing the B-offset run past rank 730
(gaps +7800 from B 10 to B 11, +392 from
B 11 to B 13). Tests: as in (i), for each
act, on the B side (B index, B-offset rank,
A-side counterpart, correspondence key);
plus the three acts at ranks 731-733 in
rank order with their offset gaps and
(size, channel) sequence.
(iii) the shared run-96 act that follows the
run-95 act in full — (791300096, 26128, 2) at
A 676 / B 393, measured in AES-NUM-185 at
A-offset rank 713 and B-offset rank 694; the
secondary run table places run 96 immediately
after run 95, and AES-NUM-185's neighbourhoods
give run 96's shift as -283. Tests: the act
in full on both sides (indices, both offset
ranks, class, run and shift, occurrences);
its neighbourhoods in both index orders and
both offset orders. Any law NOT PROVEN
unless the numbers prove it; never invent
one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

hef185.py lineage in ~/workspace/.verify-tmp/aesir185 is the base for hef186 (hef185 = the hef184 base plus arms185, sha256 8cf0210b…). Launch with unbuffered output (`python3 -u`) and capture the exit code to a .exit file, per TASK_CONTRACT_4.175_RETRY's proven terms.

One bounded host-side child per contract. Exactly ONE launch: check `tmux ls` + `ps` on Mimir for an existing hef186/h186 child BEFORE launching.
