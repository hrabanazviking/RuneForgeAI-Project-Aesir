# TASK_CONTRACT_4.208 (AES-NUM-208)

Scope (from AES-NUM-207's NEXT + TODO 4.208).
Run 102's walk continues in index order on both
sides; this slice takes the next three acts of
run 102, all measured in AES-NUM-207's own
output:
(i) the shared run-102 act at A 728 / B 730 in
full — (3418112, 24, 0), measured in
AES-NUM-207 at A-offset rank 28 and B-offset
rank 28, the forty-sixth act of run 102 (length 58,
shift +2, A 683–744 / B 685–746), following the
forty-fifth run-102 act at A 727 immediately in both
index orders (in offset order its placement is
distant, at the ranks stated — the offset-order
neighbourhood is part of the test, not an
immediacy claim). Tests: the act in full on both
sides (indices, both offset ranks, class, run
and shift, occurrences); its neighbourhoods in
both index orders and both offset orders; its
correspondence key in full.
(ii) the shared run-102 act at A 729 / B 731
in full — (791775232, 24, 0), measured in
AES-NUM-207 at A-offset rank 736 and B-offset
rank 716, the forty-seventh act of run 102, following
the act in (i) immediately in both index
orders. Tests: as in (i), for this act.
(iii) the shared run-102 act at A 730 / B 732
in full — (791775744, 24, 1), measured in
AES-NUM-207 at A-offset rank 737 and B-offset
rank 717, the forty-eighth act of run 102, following
the act in (ii) immediately in both index
orders. Tests: as in (i), for this act.
Any law NOT PROVEN unless the numbers prove
it; never invent one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

hef207.py lineage in ~/workspace/.verify-tmp/aesir207 is the base for hef208 (hef207 = the hef206 base plus arms207, sha256 e525c2db…). Launch with unbuffered output (`python3 -u`) and capture the exit code to a .exit file, per TASK_CONTRACT_4.175_RETRY's proven terms.

One bounded host-side child per contract. Exactly ONE launch: check `tmux ls` + `ps` on Mimir for an existing hef208/h208 child BEFORE launching.
