# TASK_CONTRACT_4.199 (AES-NUM-199)

Scope (from AES-NUM-198's NEXT + TODO 4.199).
Run 102's walk continues in index order on both
sides; this slice takes the next three acts of
run 102, all measured in AES-NUM-198's own
output:
(i) the shared run-102 act at A 701 / B 703 in
full — (263680, 816, 0), measured in
AES-NUM-198 at A-offset rank 5 and B-offset
rank 5, the nineteenth act of run 102 (length 58,
shift +2, A 683–744 / B 685–746), following the
eighteenth run-102 act at A 700 immediately in both
index orders only. Tests: the act in full on both
sides (indices, both offset ranks, class, run
and shift, occurrences); its neighbourhoods in
both index orders and both offset orders; its
correspondence key in full.
(ii) the shared run-102 act at A 702 / B 704
in full — (264496, 24, 0), measured in
AES-NUM-198 at A-offset rank 6 and B-offset
rank 6, the twentieth act of run 102, following
the act in (i) immediately in both index
orders and both offset orders. Tests: as in (i), for this act.
(iii) the shared run-102 act at A 703 / B 705
in full — (264520, 24, 0), measured in
AES-NUM-198 at A-offset rank 7 and B-offset
rank 7, the twenty-first act of run 102, following
the act in (ii) immediately in both index
orders and both offset orders. Tests: as in (i), for this act.
Any law NOT PROVEN unless the numbers prove
it; never invent one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

hef198.py lineage in ~/workspace/.verify-tmp/aesir198 is the base for hef199 (hef198 = the hef197 base plus arms198, sha256 8134ee19…). Launch with unbuffered output (`python3 -u`) and capture the exit code to a .exit file, per TASK_CONTRACT_4.175_RETRY's proven terms.

One bounded host-side child per contract. Exactly ONE launch: check `tmux ls` + `ps` on Mimir for an existing hef199/h199 child BEFORE launching.
