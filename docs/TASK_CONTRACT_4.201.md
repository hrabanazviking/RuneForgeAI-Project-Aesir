# TASK_CONTRACT_4.201 (AES-NUM-201)

Scope (from AES-NUM-200's NEXT + TODO 4.201).
Run 102's walk continues in index order on both
sides; this slice takes the next three acts of
run 102, all measured in AES-NUM-200's own
output:
(i) the shared run-102 act at A 707 / B 709 in
full — (265080, 24, 0), measured in
AES-NUM-200 at A-offset rank 11 and B-offset
rank 11, the twenty-fifth act of run 102 (length 58,
shift +2, A 683–744 / B 685–746), following the
twenty-fourth run-102 act at A 706 immediately in both
index orders and both offset orders. Tests: the act in full on both
sides (indices, both offset ranks, class, run
and shift, occurrences); its neighbourhoods in
both index orders and both offset orders; its
correspondence key in full.
(ii) the shared run-102 act at A 708 / B 710
in full — (791773696, 256, 0), measured in
AES-NUM-200 at A-offset rank 731 and B-offset
rank 711, the twenty-sixth act of run 102, following
the act in (i) immediately in both index
orders only. Tests: as in (i), for this act.
(iii) the shared run-102 act at A 709 / B 711
in full — (791773952, 176, 0), measured in
AES-NUM-200 at A-offset rank 732 and B-offset
rank 712, the twenty-seventh act of run 102, following
the act in (ii) immediately in both index
orders and both offset orders. Tests: as in (i), for this act.
Any law NOT PROVEN unless the numbers prove
it; never invent one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

hef200.py lineage in ~/workspace/.verify-tmp/aesir200 is the base for hef201 (hef200 = the hef199 base plus arms200, sha256 08bde3a5…). Launch with unbuffered output (`python3 -u`) and capture the exit code to a .exit file, per TASK_CONTRACT_4.175_RETRY's proven terms.

One bounded host-side child per contract. Exactly ONE launch: check `tmux ls` + `ps` on Mimir for an existing hef201/h201 child BEFORE launching.
