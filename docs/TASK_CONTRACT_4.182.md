# TASK_CONTRACT_4.182 (AES-NUM-182)

Scope (from AES-NUM-181's NEXT + TODO 4.182):
(i) the B-only act at B 27 in full —
AES-NUM-181 measured it inside B 26's B-index
neighbourhood as (873199616, 24, 2) at B-offset
rank 726, not yet given in full in this line.
Tests: the act in full (its act, B index,
B-offset rank, class, occurrences in both
contexts); its B-index neighbourhood in full;
its B-offset-order neighbourhood in full;
whether it has an A-side counterpart act in
context A, and if so where; its correspondence-key
relation to any A-side acts. Any law NOT PROVEN
unless the numbers prove it; never invent one.
(ii) the B-only act at B 271 in full —
AES-NUM-181 measured it inside B 272's B-index
neighbourhood as (3429888, 2064, 1) at B-offset
rank 29, not yet given in full in this line.
Tests: as in (i), for this act.
(iii) the B-only act at B 671 in full —
AES-NUM-181 measured it inside B 674's B-index
neighbourhood as (791121408, 32784, 2) at
B-offset rank 689, not yet given in full in
this line; earlier slices in other lines noted
an A-side act (791121408, 32784, 1) at A 670
with the same (offset, size) key and a different
channel. Tests: as in (i), for this act, plus
its correspondence-key relation to that A-side
act in full. Any law NOT PROVEN unless the
numbers prove it; never invent one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

hef181.py lineage in ~/workspace/.verify-tmp/aesir181 is the base for hef182 (hef181 = the hef180 base plus arms181, sha256 40e8b7be…). Launch with unbuffered output (`python3 -u`) and capture the exit code to a .exit file, per TASK_CONTRACT_4.175_RETRY's proven terms.

One bounded host-side child per contract. Exactly ONE launch: check `tmux ls` + `ps` on Mimir for an existing hef182/h182 child BEFORE launching.
