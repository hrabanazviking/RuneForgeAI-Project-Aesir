# TASK_CONTRACT_4.194 (AES-NUM-194)

Scope (from AES-NUM-193's NEXT + TODO 4.194).
Run 102's walk continues in index order on both
sides; this slice takes the next three acts of
run 102, all measured in AES-NUM-193's own
output:
(i) the shared run-102 act at A 686 / B 688 in
full — (791570992, 32784, 1), measured in
AES-NUM-193 at A-offset rank 722 and B-offset
rank 702, the fourth act of run 102 (length 58,
shift +2, A 683–744 / B 685–746), following the
third run-102 act at A 685 immediately in both
index orders. Tests: the act in full on both
sides (indices, both offset ranks, class, run
and shift, occurrences); its neighbourhoods in
both index orders and both offset orders; its
correspondence key in full.
(ii) the shared run-102 act at A 687 / B 689
in full — (791603776, 26128, 1), measured in
AES-NUM-193 at A-offset rank 723 and B-offset
rank 703, the fifth act of run 102, following
the act in (i) immediately in both index
orders. Tests: as in (i), for this act.
(iii) the shared run-102 act at A 688 / B 690
in full — (791629904, 32784, 1), measured in
AES-NUM-193 at A-offset rank 724 and B-offset
rank 704, the sixth act of run 102, following
the act in (ii) immediately in both index
orders. Tests: as in (i), for this act.
Any law NOT PROVEN unless the numbers prove
it; never invent one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

hef193.py lineage in ~/workspace/.verify-tmp/aesir193 is the base for hef194 (hef193 = the hef192 base plus arms193, sha256 08a5bbed…). Launch with unbuffered output (`python3 -u`) and capture the exit code to a .exit file, per TASK_CONTRACT_4.175_RETRY's proven terms.

One bounded host-side child per contract. Exactly ONE launch: check `tmux ls` + `ps` on Mimir for an existing hef194/h194 child BEFORE launching.
