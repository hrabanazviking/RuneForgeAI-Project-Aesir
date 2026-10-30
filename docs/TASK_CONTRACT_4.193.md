# TASK_CONTRACT_4.193 (AES-NUM-193)

Scope (from AES-NUM-192's NEXT + TODO 4.193).
The B-only walk in B-offset rank order is
COMPLETE (AES-NUM-192: rank 750 is the last
rank; no B act exists after B 738), so this
slice takes the acts measured in AES-NUM-192's
own output that stand next in line:
(i) the A-only act at A 681 in full — the act
(791452688, 26128, 2), measured in AES-NUM-192
at A-offset rank 718, immediately before the
shared run-102 act in A-offset order, and in
A-index order immediately after the shared
run-100 act at A 680 and immediately before
the shared run-101 act at A 682. Tests: the
act in full (its act, A index, A-offset rank,
class, occurrences in both contexts); its
A-index neighbourhood in full; its A-offset-
order neighbourhood in full; whether it has a
B-side counterpart act in context B; its
correspondence key in full (any act in A or B
under its (offset, size) key).
(ii) the shared run-102 act at A 684 / B 686
in full — (791512080, 32784, 1), measured in
AES-NUM-192 at A-offset rank 720 and B-offset
rank 700, the second act of run 102 (length
58, shift +2, A 683–744 / B 685–746),
following the run-102 act at A 683 immediately
in both index orders. Tests: the act in full
on both sides (indices, both offset ranks,
class, run and shift, occurrences); its
neighbourhoods in both index orders and both
offset orders.
(iii) the shared run-102 act at A 685 / B 687
in full — (791544864, 26128, 1), measured in
AES-NUM-192 at A-offset rank 721 and B-offset
rank 701, the third act of run 102, following
the act in (ii) immediately in both index
orders. Tests: as in (ii), for this act.
Any law NOT PROVEN unless the numbers prove
it; never invent one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

hef192.py lineage in ~/workspace/.verify-tmp/aesir192 is the base for hef193 (hef192 = the hef191r base plus arms192, sha256 2b4a3f53…). Launch with unbuffered output (`python3 -u`) and capture the exit code to a .exit file, per TASK_CONTRACT_4.175_RETRY's proven terms.

One bounded host-side child per contract. Exactly ONE launch: check `tmux ls` + `ps` on Mimir for an existing hef193/h193 child BEFORE launching.
