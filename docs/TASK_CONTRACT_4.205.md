# TASK_CONTRACT_4.205 (AES-NUM-205)

Scope (from AES-NUM-204's NEXT + TODO 4.205).
Run 102's walk continues in index order on both
sides; this slice takes the next three acts of
run 102, all measured in AES-NUM-204's own
output:
(i) the shared run-102 act at A 719 / B 721 in
full — (268648, 24, 0), measured in
AES-NUM-204 at A-offset rank 21 and B-offset
rank 21, the thirty-seventh act of run 102 (length 58,
shift +2, A 683–744 / B 685–746), following the
thirty-sixth run-102 act at A 718 immediately in both
index orders and both offset orders. Tests: the act in full on both
sides (indices, both offset ranks, class, run
and shift, occurrences); its neighbourhoods in
both index orders and both offset orders; its
correspondence key in full.
(ii) the shared run-102 act at A 720 / B 722
in full — (268672, 120, 0), measured in
AES-NUM-204 at A-offset rank 22 and B-offset
rank 22, the thirty-eighth act of run 102, following
the act in (i) immediately in both index
orders and both offset orders. Tests: as in (i), for this act.
(iii) the shared run-102 act at A 721 / B 723
in full — (268792, 24, 0), measured in
AES-NUM-204 at A-offset rank 23 and B-offset
rank 23, the thirty-ninth act of run 102, following
the act in (ii) immediately in both index
orders and both offset orders. Tests: as in (i), for this act.
Any law NOT PROVEN unless the numbers prove
it; never invent one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

hef204.py lineage in ~/workspace/.verify-tmp/aesir204 is the base for hef205 (hef204 = the hef203 base plus arms204, sha256 04adf577…). Launch with unbuffered output (`python3 -u`) and capture the exit code to a .exit file, per TASK_CONTRACT_4.175_RETRY's proven terms.

One bounded host-side child per contract. Exactly ONE launch: check `tmux ls` + `ps` on Mimir for an existing hef205/h205 child BEFORE launching.
