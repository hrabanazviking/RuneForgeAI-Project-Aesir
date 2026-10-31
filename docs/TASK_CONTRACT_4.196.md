# TASK_CONTRACT_4.196 (AES-NUM-196)

Scope (from AES-NUM-195's NEXT + TODO 4.196).
Run 102's walk continues in index order on both
sides; this slice takes the next three acts of
run 102, all measured in AES-NUM-195's own
output:
(i) the shared run-102 act at A 692 / B 694 in
full — (791754384, 18448, 1), measured in
AES-NUM-195 at A-offset rank 728 and B-offset
rank 708, the tenth act of run 102 (length 58,
shift +2, A 683–744 / B 685–746), following the
ninth run-102 act at A 691 immediately in both
index orders. Tests: the act in full on both
sides (indices, both offset ranks, class, run
and shift, occurrences); its neighbourhoods in
both index orders and both offset orders; its
correspondence key in full.
(ii) the shared run-102 act at A 693 / B 695
in full — (3415040, 24, 1), measured in
AES-NUM-195 at A-offset rank 27 and B-offset
rank 27, the eleventh act of run 102, following
the act in (i) immediately in both index
orders. Tests: as in (i), for this act.
(iii) the shared run-102 act at A 694 / B 696
in full — (262144, 376, 0), measured in
AES-NUM-195 at A-offset rank 0 and B-offset
rank 0, the twelfth act of run 102, following
the act in (ii) immediately in both index
orders. Tests: as in (i), for this act.
Any law NOT PROVEN unless the numbers prove
it; never invent one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

hef195.py lineage in ~/workspace/.verify-tmp/aesir195 is the base for hef196 (hef195 = the hef194 base plus arms195, sha256 6e29db04…). Launch with unbuffered output (`python3 -u`) and capture the exit code to a .exit file, per TASK_CONTRACT_4.175_RETRY's proven terms.

One bounded host-side child per contract. Exactly ONE launch: check `tmux ls` + `ps` on Mimir for an existing hef196/h196 child BEFORE launching.
