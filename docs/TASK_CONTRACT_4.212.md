# TASK_CONTRACT_4.212 (AES-NUM-212)

Scope (from AES-NUM-211's NEXT + TODO 4.212).
Both context lists are now walked to their
ends; AES-NUM-211's own output measured, in
B-offset order, a run of B-only acts sitting
immediately after the B tail acts, none of
which has been given in full:
(i) the act at B 1 in full —
(873198592, 24, 0), measured in AES-NUM-211
at B-offset rank 724 as the offset-order
successor of the B tail act at B 749.
Tests: the act in full on both sides
(indices, offset ranks, class, run and
shift, occurrences); its neighbourhoods in
both index orders and both offset orders;
its correspondence key in full.
(ii) the act at B 0 in full —
(873199104, 24, 1), measured in AES-NUM-211
at B-offset rank 725. Tests: as in (i),
for this act.
(iii) the acts at B 27 and B 5 in full —
(873199616, 24, 2) at B-offset rank 726 and
(1196182016, 24, 2) at B-offset rank 728,
the latter measured in AES-NUM-211 as the
offset-order successor of the last B tail
act at B 750 (rank 727). Tests: each act in
full as in (i); and the B-offset-order run
of ranks 721–728 in full (each rank's act,
its B index, and the gap to the next rank,
stated exactly where a next rank exists).
Any law NOT PROVEN unless the numbers prove
it; never invent one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

hef211.py lineage in ~/workspace/.verify-tmp/aesir211 is the base for hef212 (hef211 = the hef210r base plus arms211, sha256 3c6d275f…). Launch with unbuffered output (`python3 -u`) and capture the exit code to a .exit file, per TASK_CONTRACT_4.175_RETRY's proven terms. Window ranges in the new section MUST be bounded by the measured list lengths (A acts 749, B acts 751) — no index or rank beyond the last measured position (A index 748, B index 750, A-offset rank 748, B-offset rank 750) may be requested.

One bounded host-side child per contract. Exactly ONE launch: check `tmux ls` + `ps` on Mimir for an existing hef212/h212 child BEFORE launching.
