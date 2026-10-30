# TASK_CONTRACT_4.197 (AES-NUM-197)

Scope (from AES-NUM-196's NEXT + TODO 4.197).
Run 102's walk continues in index order on both
sides; this slice takes the next three acts of
run 102, all measured in AES-NUM-196's own
output:
(i) the shared run-102 act at A 695 / B 697 in
full — (262656, 24, 0), measured in
AES-NUM-196 at A-offset rank 1 and B-offset
rank 1, the thirteenth act of run 102 (length 58,
shift +2, A 683–744 / B 685–746), following the
twelfth run-102 act at A 694 immediately in both
index orders and both offset orders. Tests: the act in full on both
sides (indices, both offset ranks, class, run
and shift, occurrences); its neighbourhoods in
both index orders and both offset orders; its
correspondence key in full.
(ii) the shared run-102 act at A 696 / B 698
in full — (262680, 24, 0), measured in
AES-NUM-196 at A-offset rank 2 and B-offset
rank 2, the fourteenth act of run 102, following
the act in (i) immediately in both index
orders and both offset orders. Tests: as in (i), for this act.
(iii) the shared run-102 act at A 697 / B 699
in full — (262704, 72, 0), measured in
AES-NUM-196 at A-offset rank 3 and B-offset
rank 3, the fifteenth act of run 102, following
the act in (ii) immediately in both index
orders and both offset orders. Tests: as in (i), for this act.
Any law NOT PROVEN unless the numbers prove
it; never invent one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

hef196.py lineage in ~/workspace/.verify-tmp/aesir196 is the base for hef197 (hef196 = the hef195 base plus arms196, sha256 c79f0426…). Launch with unbuffered output (`python3 -u`) and capture the exit code to a .exit file, per TASK_CONTRACT_4.175_RETRY's proven terms.

One bounded host-side child per contract. Exactly ONE launch: check `tmux ls` + `ps` on Mimir for an existing hef197/h197 child BEFORE launching.
