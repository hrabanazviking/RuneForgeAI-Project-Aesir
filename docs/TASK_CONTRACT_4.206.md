# TASK_CONTRACT_4.206 (AES-NUM-206)

Scope (from AES-NUM-205's NEXT + TODO 4.206).
Run 102's walk continues in index order on both
sides; this slice takes the next three acts of
run 102, all measured in AES-NUM-205's own
output:
(i) the shared run-102 act at A 722 / B 724 in
full — (268816, 64, 0), measured in
AES-NUM-205 at A-offset rank 24 and B-offset
rank 24, the fortieth act of run 102 (length 58,
shift +2, A 683–744 / B 685–746), following the
thirty-ninth run-102 act at A 721 immediately in both
index orders and both offset orders. Tests: the act in full on both
sides (indices, both offset ranks, class, run
and shift, occurrences); its neighbourhoods in
both index orders and both offset orders; its
correspondence key in full.
(ii) the shared run-102 act at A 723 / B 725
in full — (268880, 24, 0), measured in
AES-NUM-205 at A-offset rank 25 and B-offset
rank 25, the forty-first act of run 102, following
the act in (i) immediately in both index
orders and both offset orders. Tests: as in (i), for this act.
(iii) the shared run-102 act at A 724 / B 726
in full — (268904, 216, 0), measured in
AES-NUM-205 at A-offset rank 26 and B-offset
rank 26, the forty-second act of run 102, following
the act in (ii) immediately in both index
orders and both offset orders. Tests: as in (i), for this act.
Any law NOT PROVEN unless the numbers prove
it; never invent one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

hef205.py lineage in ~/workspace/.verify-tmp/aesir205 is the base for hef206 (hef205 = the hef204 base plus arms205, sha256 89ef7496…). Launch with unbuffered output (`python3 -u`) and capture the exit code to a .exit file, per TASK_CONTRACT_4.175_RETRY's proven terms.

One bounded host-side child per contract. Exactly ONE launch: check `tmux ls` + `ps` on Mimir for an existing hef206/h206 child BEFORE launching.
