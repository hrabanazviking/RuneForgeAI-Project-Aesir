# TASK_CONTRACT_4.207 (AES-NUM-207)

Scope (from AES-NUM-206's NEXT + TODO 4.207).
Run 102's walk continues in index order on both
sides; this slice takes the next three acts of
run 102, all measured in AES-NUM-206's own
output:
(i) the shared run-102 act at A 725 / B 727 in
full — (791774208, 328, 0), measured in
AES-NUM-206 at A-offset rank 733 and B-offset
rank 713, the forty-third act of run 102 (length 58,
shift +2, A 683–744 / B 685–746), following the
forty-second run-102 act at A 724 immediately in both
index orders (in offset order its placement is
distant, at the ranks stated — the offset-order
neighbourhood is part of the test, not an
immediacy claim). Tests: the act in full on both
sides (indices, both offset ranks, class, run
and shift, occurrences); its neighbourhoods in
both index orders and both offset orders; its
correspondence key in full.
(ii) the shared run-102 act at A 726 / B 728
in full — (791774536, 328, 0), measured in
AES-NUM-206 at A-offset rank 734 and B-offset
rank 714, the forty-fourth act of run 102, following
the act in (i) immediately in both index
orders. Tests: as in (i), for this act.
(iii) the shared run-102 act at A 727 / B 729
in full — (791774864, 328, 0), measured in
AES-NUM-206 at A-offset rank 735 and B-offset
rank 715, the forty-fifth act of run 102, following
the act in (ii) immediately in both index
orders. Tests: as in (i), for this act.
Any law NOT PROVEN unless the numbers prove
it; never invent one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

hef206.py lineage in ~/workspace/.verify-tmp/aesir206 is the base for hef207 (hef206 = the hef205 base plus arms206, sha256 fdc2b8fe…). Launch with unbuffered output (`python3 -u`) and capture the exit code to a .exit file, per TASK_CONTRACT_4.175_RETRY's proven terms.

One bounded host-side child per contract. Exactly ONE launch: check `tmux ls` + `ps` on Mimir for an existing hef207/h207 child BEFORE launching.
