# TASK_CONTRACT_4.185 (AES-NUM-185)

Scope (from AES-NUM-184's NEXT + TODO 4.185):
(i) the B-only act at B 750 in full — the act
(973679616, 24, 0), measured in AES-NUM-184
at B-offset rank 727, preceding the B-only
act at B 5 (rank 728) in B-offset order inside
the all-B-only B-offset run at ranks 725-732.
Tests: the act in full (its act, B index,
B-offset rank, class, occurrences in both
contexts); its B-index neighbourhood in full;
its B-offset-order neighbourhood in full;
whether it has an A-side counterpart act in
context A; its correspondence key in full
(any act in A or B under its (offset, size)
key).
(ii) the B-only act at B 8 in full — the act
(1196183040, 32784, 1), measured in
AES-NUM-184 at B-offset rank 730, following
B 6 (rank 729) in both B-index order (B 8
after B 5-B 7) and B-offset order, and
completing the +512/+512 offset triplet at
ranks 728-730. Tests: as in (i), for this
act, on the B side (B index, B-offset rank,
A-side counterpart, correspondence key);
plus the triplet in full (its three acts in
rank order, its offset gaps, its (size,
channel) sequence).
(iii) the shared run-95 act that follows the
run-94 act in both offset orders in full —
(791240192, 26128, 1) at A 674 / B 676,
measured in AES-NUM-184 at A-offset rank 711
and B-offset rank 692; the secondary run
table gives run 95 as a singleton of length
1 with shift +2. Tests: the act in full on
both sides (indices, both offset ranks,
class, run and shift, occurrences); its
neighbourhoods in both index orders and
both offset orders. Any law NOT PROVEN
unless the numbers prove it; never invent
one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

hef184.py lineage in ~/workspace/.verify-tmp/aesir184 is the base for hef185 (hef184 = the hef183 base plus arms184, sha256 97e7c078…). Launch with unbuffered output (`python3 -u`) and capture the exit code to a .exit file, per TASK_CONTRACT_4.175_RETRY's proven terms.

One bounded host-side child per contract. Exactly ONE launch: check `tmux ls` + `ps` on Mimir for an existing hef185/h185 child BEFORE launching.
