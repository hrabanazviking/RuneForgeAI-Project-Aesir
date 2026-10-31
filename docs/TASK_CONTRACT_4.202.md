# TASK_CONTRACT_4.202 (AES-NUM-202)

Scope (from AES-NUM-201's NEXT + TODO 4.202).
Run 102's walk continues in index order on both
sides; this slice takes the next three acts of
run 102, all measured in AES-NUM-201's own
output:
(i) the shared run-102 act at A 710 / B 712 in
full — (265728, 176, 0), measured in
AES-NUM-201 at A-offset rank 12 and B-offset
rank 12, the twenty-eighth act of run 102 (length 58,
shift +2, A 683–744 / B 685–746), following the
twenty-seventh run-102 act at A 709 immediately in both
index orders only. Tests: the act in full on both
sides (indices, both offset ranks, class, run
and shift, occurrences); its neighbourhoods in
both index orders and both offset orders; its
correspondence key in full.
(ii) the shared run-102 act at A 711 / B 713
in full — (265904, 344, 0), measured in
AES-NUM-201 at A-offset rank 13 and B-offset
rank 13, the twenty-ninth act of run 102, following
the act in (i) immediately in both index
orders and both offset orders. Tests: as in (i), for this act.
(iii) the shared run-102 act at A 712 / B 714
in full — (266248, 584, 0), measured in
AES-NUM-201 at A-offset rank 14 and B-offset
rank 14, the thirtieth act of run 102, following
the act in (ii) immediately in both index
orders and both offset orders. Tests: as in (i), for this act.
Any law NOT PROVEN unless the numbers prove
it; never invent one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

hef201.py lineage in ~/workspace/.verify-tmp/aesir201 is the base for hef202 (hef201 = the hef200 base plus arms201, sha256 33f10f04…). Launch with unbuffered output (`python3 -u`) and capture the exit code to a .exit file, per TASK_CONTRACT_4.175_RETRY's proven terms.

One bounded host-side child per contract. Exactly ONE launch: check `tmux ls` + `ps` on Mimir for an existing hef202/h202 child BEFORE launching.
