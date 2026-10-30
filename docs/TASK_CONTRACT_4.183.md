# TASK_CONTRACT_4.183 (AES-NUM-183)

Scope (from AES-NUM-182's NEXT + TODO 4.183):
(i) the two other acts of B 27's offset triplet
in full — the B-only act at B 1, measured in
AES-NUM-182 at B-offset rank 724 as
(873198592, 24, 0), and the B-only act at B 0,
measured at B-offset rank 725 as
(873199104, 24, 1). Tests: each act in full
(its act, B index, B-offset rank, class,
occurrences in both contexts); its B-index
neighbourhood in full; its B-offset-order
neighbourhood in full; whether it has an
A-side counterpart act in context A, and if
so where; its correspondence-key relation to
any A-side acts. Any law NOT PROVEN unless
the numbers prove it; never invent one.
(ii) the two further A-only acts inside
A 670's A-index neighbourhood in full — the
act at A 673, measured in AES-NUM-182 as
(791206912, 32784, 1) at A-offset rank 710,
and the act at A 675, measured as
(791266816, 32784, 1) at A-offset rank 712.
Tests: as in (i), for these acts, on the A
side (A index, A-offset rank, B-side
counterpart, correspondence key).
(iii) the shared run-93 act that follows both
B 671 and A 670 in offset order in full —
(791154688, 18448, 2) at A 671 / B 280,
measured in AES-NUM-182 at A-offset rank 708
and B-offset rank 690; AES-NUM-177 measured
run 93 as a -391 singleton. Tests: the act
in full on both sides (indices, both offset
ranks, class, run and shift, occurrences);
its neighbourhoods in both index orders and
both offset orders. Any law NOT PROVEN
unless the numbers prove it; never invent one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

hef182.py lineage in ~/workspace/.verify-tmp/aesir182 is the base for hef183 (hef182 = the hef181 base plus arms182, sha256 cf7708c7…). Launch with unbuffered output (`python3 -u`) and capture the exit code to a .exit file, per TASK_CONTRACT_4.175_RETRY's proven terms.

One bounded host-side child per contract. Exactly ONE launch: check `tmux ls` + `ps` on Mimir for an existing hef183/h183 child BEFORE launching.
