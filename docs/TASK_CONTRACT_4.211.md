# TASK_CONTRACT_4.211 (AES-NUM-211)

Scope (from AES-NUM-210's NEXT + TODO 4.211).
Run 102 has ended at A 744 / B 746; this slice
takes the tails of the two context lists that
follow it, all measured in AES-NUM-210's own
output (its extended resync test):
(i) the act at A 745 in full —
(791779328, 24, 0), measured in AES-NUM-210
at A index 745 as the first tail act after
the last run-102 act, differing in position
from the B tail. Tests: the act in full on
both sides (indices, offset ranks, class,
run and shift, occurrences); its
neighbourhoods in both index orders and
both offset orders; its correspondence key
in full.
(ii) the act at B 747 in full —
(791781888, 24, 0), measured in AES-NUM-210
at B index 747 as the first tail act after
the last run-102 act on the B side. Tests:
as in (i), for this act.
(iii) the tail ends in full — A indices
746–748 and B indices 748–750 (the last
three acts of each context list; A acts 749,
B acts 751, as measured in AES-NUM-210).
Tests: each tail act in full on the side
where it occurs; whether any tail act
(A 745–748 / B 747–750) occurs on the other
side at any index; and the full tail
comparison A 745–748 against B 747–750
(differing positions, stated exactly).
Any law NOT PROVEN unless the numbers prove
it; never invent one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

hef210r.py lineage in ~/workspace/.verify-tmp/aesir210r is the base for hef211 (hef210r = the hef209 base plus arms210r, sha256 0eaf6d14…). Launch with unbuffered output (`python3 -u`) and capture the exit code to a .exit file, per TASK_CONTRACT_4.175_RETRY's proven terms. Window ranges in the new section MUST be bounded by the measured list lengths (A acts 749, B acts 751) — no index or rank beyond the last measured position (A index 748, B index 750, A-offset rank 748, B-offset rank 750) may be requested.

One bounded host-side child per contract. Exactly ONE launch: check `tmux ls` + `ps` on Mimir for an existing hef211/h211 child BEFORE launching.
