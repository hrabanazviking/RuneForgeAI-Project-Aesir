# TASK_CONTRACT_4.203 (AES-NUM-203)

Scope (from AES-NUM-202's NEXT + TODO 4.203).
Run 102's walk continues in index order on both
sides; this slice takes the next three acts of
run 102, all measured in AES-NUM-202's own
output:
(i) the shared run-102 act at A 713 / B 715 in
full — (266832, 824, 0), measured in
AES-NUM-202 at A-offset rank 15 and B-offset
rank 15, the thirty-first act of run 102 (length 58,
shift +2, A 683–744 / B 685–746), following the
thirtieth run-102 act at A 712 immediately in both
index orders and both offset orders. Tests: the act in full on both
sides (indices, both offset ranks, class, run
and shift, occurrences); its neighbourhoods in
both index orders and both offset orders; its
correspondence key in full.
(ii) the shared run-102 act at A 714 / B 716
in full — (267656, 24, 0), measured in
AES-NUM-202 at A-offset rank 16 and B-offset
rank 16, the thirty-second act of run 102, following
the act in (i) immediately in both index
orders and both offset orders. Tests: as in (i), for this act.
(iii) the shared run-102 act at A 715 / B 717
in full — (267680, 24, 0), measured in
AES-NUM-202 at A-offset rank 17 and B-offset
rank 17, the thirty-third act of run 102, following
the act in (ii) immediately in both index
orders and both offset orders. Tests: as in (i), for this act.
Any law NOT PROVEN unless the numbers prove
it; never invent one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

hef202.py lineage in ~/workspace/.verify-tmp/aesir202 is the base for hef203 (hef202 = the hef201 base plus arms202, sha256 57ea1fff…). Launch with unbuffered output (`python3 -u`) and capture the exit code to a .exit file, per TASK_CONTRACT_4.175_RETRY's proven terms.

One bounded host-side child per contract. Exactly ONE launch: check `tmux ls` + `ps` on Mimir for an existing hef203/h203 child BEFORE launching.
