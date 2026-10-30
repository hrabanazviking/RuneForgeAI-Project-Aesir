# TASK_CONTRACT_4.213 (AES-NUM-213)

Scope (from AES-NUM-212's NEXT + TODO 4.213).
AES-NUM-212's own output measured, in
B-offset order, the three B-only acts sitting
immediately after rank 728, none of which has
been given in full:
(i) the act at B 6 in full —
(1196182528, 24, 0), measured in AES-NUM-212
at B-offset rank 729 as the offset-order
successor of the B 5 act at rank 728.
Tests: the act in full on both sides
(indices, offset ranks, class, run and
shift, occurrences); its neighbourhoods in
both index orders and both offset orders;
its correspondence key in full.
(ii) the act at B 8 in full —
(1196183040, 32784, 1), measured in
AES-NUM-212 at B-offset rank 730. Tests:
as in (i), for this act.
(iii) the act at B 10 in full —
(1196216320, 7800, 2), measured in
AES-NUM-212 at B-offset rank 731; and the
B-offset-order run of ranks 729–736 in
full (each rank's act, its B index, and
the gap to the next rank, stated exactly
where a next rank exists). Tests: the act
in full as in (i); the run as stated.
Any law NOT PROVEN unless the numbers prove
it; never invent one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

hef212.py lineage in ~/workspace/.verify-tmp/aesir212 is the base for hef213 (hef212 = the hef211 base plus arms212, sha256 ba5ca27d…). Launch with unbuffered output (`python3 -u`) and capture the exit code to a .exit file, per TASK_CONTRACT_4.175_RETRY's proven terms. Window ranges in the new section MUST be bounded by the measured list lengths (A acts 749, B acts 751) — no index or rank beyond the last measured position (A index 748, B index 750, A-offset rank 748, B-offset rank 750) may be requested.

One bounded host-side child per contract. Exactly ONE launch: check `tmux ls` + `ps` on Mimir for an existing hef213/h213 child BEFORE launching.
