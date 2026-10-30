# TASK_CONTRACT_4.198 (AES-NUM-198)

Scope (from AES-NUM-197's NEXT + TODO 4.198).
Run 102's walk continues in index order on both
sides; this slice takes the next three acts of
run 102, all measured in AES-NUM-197's own
output:
(i) the shared run-102 act at A 698 / B 700 in
full — (262776, 24, 0), measured in
AES-NUM-197 at A-offset rank 4 and B-offset
rank 4, the sixteenth act of run 102 (length 58,
shift +2, A 683–744 / B 685–746), following the
fifteenth run-102 act at A 697 immediately in both
index orders and both offset orders. Tests: the act in full on both
sides (indices, both offset ranks, class, run
and shift, occurrences); its neighbourhoods in
both index orders and both offset orders; its
correspondence key in full.
(ii) the shared run-102 act at A 699 / B 701
in full — (791773184, 248, 0), measured in
AES-NUM-197 at A-offset rank 729 and B-offset
rank 709, the seventeenth act of run 102, following
the act in (i) immediately in both index
orders. Tests: as in (i), for this act.
(iii) the shared run-102 act at A 700 / B 702
in full — (791773432, 176, 0), measured in
AES-NUM-197 at A-offset rank 730 and B-offset
rank 710, the eighteenth act of run 102, following
the act in (ii) immediately in both index
orders and both offset orders. Tests: as in (i), for this act.
Any law NOT PROVEN unless the numbers prove
it; never invent one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

hef197.py lineage in ~/workspace/.verify-tmp/aesir197 is the base for hef198 (hef197 = the hef196 base plus arms197, sha256 65a34526…). Launch with unbuffered output (`python3 -u`) and capture the exit code to a .exit file, per TASK_CONTRACT_4.175_RETRY's proven terms.

One bounded host-side child per contract. Exactly ONE launch: check `tmux ls` + `ps` on Mimir for an existing hef198/h198 child BEFORE launching.
