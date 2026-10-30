# TASK_CONTRACT_4.195 (AES-NUM-195)

Scope (from AES-NUM-194's NEXT + TODO 4.195).
Run 102's walk continues in index order on both
sides; this slice takes the next three acts of
run 102, all measured in AES-NUM-194's own
output:
(i) the shared run-102 act at A 689 / B 691 in
full — (791662688, 26128, 1), measured in
AES-NUM-194 at A-offset rank 725 and B-offset
rank 705, the seventh act of run 102 (length 58,
shift +2, A 683–744 / B 685–746), following the
sixth run-102 act at A 688 immediately in both
index orders. Tests: the act in full on both
sides (indices, both offset ranks, class, run
and shift, occurrences); its neighbourhoods in
both index orders and both offset orders; its
correspondence key in full.
(ii) the shared run-102 act at A 690 / B 692
in full — (791688816, 32784, 1), measured in
AES-NUM-194 at A-offset rank 726 and B-offset
rank 706, the eighth act of run 102, following
the act in (i) immediately in both index
orders. Tests: as in (i), for this act.
(iii) the shared run-102 act at A 691 / B 693
in full — (791721600, 32784, 1), measured in
AES-NUM-194 at A-offset rank 727 and B-offset
rank 707, the ninth act of run 102, following
the act in (ii) immediately in both index
orders. Tests: as in (i), for this act.
Any law NOT PROVEN unless the numbers prove
it; never invent one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

hef194.py lineage in ~/workspace/.verify-tmp/aesir194 is the base for hef195 (hef194 = the hef193 base plus arms194, sha256 4c4ed9c2…). Launch with unbuffered output (`python3 -u`) and capture the exit code to a .exit file, per TASK_CONTRACT_4.175_RETRY's proven terms.

One bounded host-side child per contract. Exactly ONE launch: check `tmux ls` + `ps` on Mimir for an existing hef195/h195 child BEFORE launching.
