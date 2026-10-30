# TASK_CONTRACT_4.229 (AES-NUM-229)

Scope (from AES-NUM-228's NEXT + TODO 4.229).
AES-NUM-228's census named the first act of
B-offset order and closed that order, but the
rank-0 act has not been given in full in this
sequence, and the A-offset order has had
neither a closure in full nor a census:
(i) the act at B-offset rank 0 in full —
(262144, 376, 0) at B 696, rank 0; rank 0 has
no predecessor, so no incoming gap exists
for it and none may be requested; its
outgoing gap is stated where a next rank
exists.
(ii) the A-offset-order closure in full —
the last six A-offset ranks, each with A
index, act, class and gap to the next rank
where a next rank exists in the measured
list (A acts 749, max rank 748, so the last
rank's gap is None); followed by the
closing run of the last eight A-offset
ranks in full on the same terms. Tests:
every rank in the closing run stated
exactly; no rank beyond the last measured
A-offset rank may be requested.
(iii) the full-order census over A-offset
order — A acts 749, ranks 0 to the last
measured rank; the act at rank 0 and the
act at the last rank; the class census over
all A acts in that order (counts per class
as defined in the controls); the run-102
membership count over that order.
Tests: the census counts sum to the A act
count; first and last acts stated exactly.
Any law NOT PROVEN unless the numbers prove
it; never invent one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

hef228.py lineage in ~/workspace/.verify-tmp/aesir228 is the base for hef229 (hef228 = the hef227 base plus arms228, sha256 6d89b8ab…). Launch with unbuffered output (`python3 -u`) and capture the exit code to a .exit file, per TASK_CONTRACT_4.175_RETRY's proven terms. Window ranges in the new section MUST be bounded by the measured list lengths (A acts 749, B acts 751) — no index or rank beyond the last measured position (A index 748, B index 750, A-offset rank 748, B-offset rank 750) may be requested.

One bounded host-side child per contract. Exactly ONE launch: check `tmux ls` + `ps` on Mimir for an existing hef229/h229 child BEFORE launching.
