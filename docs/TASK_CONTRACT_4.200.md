# TASK_CONTRACT_4.200 (AES-NUM-200)

Scope (from AES-NUM-199's NEXT + TODO 4.200).
Run 102's walk continues in index order on both
sides; this slice takes the next three acts of
run 102, all measured in AES-NUM-199's own
output:
(i) the shared run-102 act at A 704 / B 706 in
full — (264544, 416, 0), measured in
AES-NUM-199 at A-offset rank 8 and B-offset
rank 8, the twenty-second act of run 102 (length 58,
shift +2, A 683–744 / B 685–746), following the
twenty-first run-102 act at A 703 immediately in both
index orders and both offset orders. Tests: the act in full on both
sides (indices, both offset ranks, class, run
and shift, occurrences); its neighbourhoods in
both index orders and both offset orders; its
correspondence key in full.
(ii) the shared run-102 act at A 705 / B 707
in full — (264960, 96, 0), measured in
AES-NUM-199 at A-offset rank 9 and B-offset
rank 9, the twenty-third act of run 102, following
the act in (i) immediately in both index
orders and both offset orders. Tests: as in (i), for this act.
(iii) the shared run-102 act at A 706 / B 708
in full — (265056, 24, 0), measured in
AES-NUM-199 at A-offset rank 10 and B-offset
rank 10, the twenty-fourth act of run 102, following
the act in (ii) immediately in both index
orders and both offset orders. Tests: as in (i), for this act.
Any law NOT PROVEN unless the numbers prove
it; never invent one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

hef199.py lineage in ~/workspace/.verify-tmp/aesir199 is the base for hef200 (hef199 = the hef198 base plus arms199, sha256 daa54fe2…). Launch with unbuffered output (`python3 -u`) and capture the exit code to a .exit file, per TASK_CONTRACT_4.175_RETRY's proven terms.

One bounded host-side child per contract. Exactly ONE launch: check `tmux ls` + `ps` on Mimir for an existing hef200/h200 child BEFORE launching.
