# TASK_CONTRACT_4.204 (AES-NUM-204)

Scope (from AES-NUM-203's NEXT + TODO 4.204).
Run 102's walk continues in index order on both
sides; this slice takes the next three acts of
run 102, all measured in AES-NUM-203's own
output:
(i) the shared run-102 act at A 716 / B 718 in
full — (267704, 96, 0), measured in
AES-NUM-203 at A-offset rank 18 and B-offset
rank 18, the thirty-fourth act of run 102 (length 58,
shift +2, A 683–744 / B 685–746), following the
thirty-third run-102 act at A 715 immediately in both
index orders and both offset orders. Tests: the act in full on both
sides (indices, both offset ranks, class, run
and shift, occurrences); its neighbourhoods in
both index orders and both offset orders; its
correspondence key in full.
(ii) the shared run-102 act at A 717 / B 719
in full — (267800, 176, 0), measured in
AES-NUM-203 at A-offset rank 19 and B-offset
rank 19, the thirty-fifth act of run 102, following
the act in (i) immediately in both index
orders and both offset orders. Tests: as in (i), for this act.
(iii) the shared run-102 act at A 718 / B 720
in full — (267976, 672, 0), measured in
AES-NUM-203 at A-offset rank 20 and B-offset
rank 20, the thirty-sixth act of run 102, following
the act in (ii) immediately in both index
orders and both offset orders. Tests: as in (i), for this act.
Any law NOT PROVEN unless the numbers prove
it; never invent one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

hef203.py lineage in ~/workspace/.verify-tmp/aesir203 is the base for hef204 (hef203 = the hef202 base plus arms203, sha256 70b6362e…). Launch with unbuffered output (`python3 -u`) and capture the exit code to a .exit file, per TASK_CONTRACT_4.175_RETRY's proven terms.

One bounded host-side child per contract. Exactly ONE launch: check `tmux ls` + `ps` on Mimir for an existing hef204/h204 child BEFORE launching.
