# TASK_CONTRACT_4.191 (AES-NUM-191)

Scope (from AES-NUM-190's NEXT + TODO 4.191):
(i) the B-only act at B 674 in full — the act
(1196410880, 32784, 2), measured in AES-NUM-190
at B-offset rank 746, following B 272 (rank 745)
in B-offset order, its incoming gap +14848, an
excess of 496 over B 272's size 14352.
Tests: the act in full (its act, B index,
B-offset rank, class, occurrences in both
contexts); its B-index neighbourhood in full;
its B-offset-order neighbourhood in full;
whether it has an A-side counterpart act in
context A; its correspondence key in full
(any act in A or B under its (offset, size)
key).
(ii) the B-only acts at B 735 and B 736 in
full — the acts (1196444160, 24, 0) at
B-offset rank 747 and (1196444672, 24, 1) at
B-offset rank 748, measured in AES-NUM-190,
continuing the B-offset run past rank 746
(gap +33280 from B 674 to B 735; gap +512
from B 735 to B 736). Tests: as in
(i), for each act, on the B side (B index,
B-offset rank, A-side counterpart,
correspondence key); plus the three acts at
ranks 746-748 in rank order with their
offset gaps and (size, channel) sequence.
(iii) the shared run-101 act that follows the
run-100 act in full — (3446784, 24, 2) at
A 682 / B 675, measured in AES-NUM-190 at
A-offset rank 29; AES-NUM-190's A-index
neighbourhood of A 680 gives run 101's shift
as -7 and its B position as 675. Tests: the act
in full on both sides (indices, both offset
ranks, class, run and shift, occurrences);
its neighbourhoods in both index orders and
both offset orders. Any law NOT PROVEN
unless the numbers prove it; never invent
one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

hef190.py lineage in ~/workspace/.verify-tmp/aesir190 is the base for hef191 (hef190 = the hef189 base plus arms190, sha256 d4df4283…). Launch with unbuffered output (`python3 -u`) and capture the exit code to a .exit file, per TASK_CONTRACT_4.175_RETRY's proven terms.

One bounded host-side child per contract. Exactly ONE launch: check `tmux ls` + `ps` on Mimir for an existing hef191/h191 child BEFORE launching.
