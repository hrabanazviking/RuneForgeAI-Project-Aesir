# TASK_CONTRACT_4.188 (AES-NUM-188)

Scope (from AES-NUM-187's NEXT + TODO 4.188):
(i) the B-only act at B 17 in full — the act
(1196272096, 32728, 1), measured in AES-NUM-187
at B-offset rank 737, following B 16 (rank 736)
in both B-index order and B-offset order, its
incoming gap +24 exactly B 16's size.
Tests: the act in full (its act, B index,
B-offset rank, class, occurrences in both
contexts); its B-index neighbourhood in full;
its B-offset-order neighbourhood in full;
whether it has an A-side counterpart act in
context A; its correspondence key in full
(any act in A or B under its (offset, size)
key).
(ii) the B-only acts at B 19 and B 20 in
full — the acts (1196304896, 7712, 0) at
B-offset rank 738 and (1196312608, 328, 0) at
B-offset rank 739, measured in AES-NUM-187,
continuing the B-offset run past rank 737
(gap +32800 from B 17 to B 19, an excess of
72 over B 17's size; gap +7712 from B 19 to
B 20, exactly B 19's size). Tests: as in
(i), for each act, on the B side (B index,
B-offset rank, A-side counterpart,
correspondence key); plus the three acts at
ranks 737-739 in rank order with their
offset gaps and (size, channel) sequence.
(iii) the shared run-98 act that follows the
run-97 act in full — (791360000, 26128, 2) at
A 678 / B 223, measured in AES-NUM-187 at
A-offset rank 715 and B-offset rank 696; the
secondary run table places run 98 immediately
after run 97, and AES-NUM-187's neighbourhoods
give run 98's shift as -455. Tests: the act
in full on both sides (indices, both offset
ranks, class, run and shift, occurrences);
its neighbourhoods in both index orders and
both offset orders. Any law NOT PROVEN
unless the numbers prove it; never invent
one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

hef187.py lineage in ~/workspace/.verify-tmp/aesir187 is the base for hef188 (hef187 = the hef186 base plus arms187, sha256 fc7290ed…). Launch with unbuffered output (`python3 -u`) and capture the exit code to a .exit file, per TASK_CONTRACT_4.175_RETRY's proven terms.

One bounded host-side child per contract. Exactly ONE launch: check `tmux ls` + `ps` on Mimir for an existing hef188/h188 child BEFORE launching.
