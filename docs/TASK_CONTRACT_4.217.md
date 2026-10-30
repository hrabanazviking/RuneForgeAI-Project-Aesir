# TASK_CONTRACT_4.217 (AES-NUM-217)

Scope (from AES-NUM-216's NEXT + TODO 4.217).
AES-NUM-216's own output measured, in
A-offset order, the closing ranks of context
A; the three A-only acts sitting at A-offset
ranks 746–748 (A acts 749, ranks 0–748) have
each been measured in earlier slices (recorded
in the hef216 raw output's own earlier
sections) but none has been given in full in
this sequence:
(i) the act at A 746 in full —
(791779840, 24, 1), measured at
A-offset rank 746.
Tests: the act in full on both sides
(indices, offset ranks, class, run and
shift, occurrences); its neighbourhoods in
both index orders and both offset orders;
its correspondence key in full.
(ii) the act at A 747 in full —
(791780352, 24, 2), measured at
A-offset rank 747. Tests: as in (i), for
this act.
(iii) the act at A 748 in full —
(791780864, 24, 0), measured at
A-offset rank 748; and the A-offset-order
closure in full (rank 748 is the last
measured rank — A acts 749, ranks 0–748 —
so its gap to a next rank is None and no
rank beyond 748 may be requested).
Tests: the act in full as in (i); the
closure as stated.
Any law NOT PROVEN unless the numbers prove
it; never invent one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

hef216.py lineage in ~/workspace/.verify-tmp/aesir216 is the base for hef217 (hef216 = the hef215 base plus arms216, sha256 596dba5e…). Launch with unbuffered output (`python3 -u`) and capture the exit code to a .exit file, per TASK_CONTRACT_4.175_RETRY's proven terms. Window ranges in the new section MUST be bounded by the measured list lengths (A acts 749, B acts 751) — no index or rank beyond the last measured position (A index 748, B index 750, A-offset rank 748, B-offset rank 750) may be requested.

One bounded host-side child per contract. Exactly ONE launch: check `tmux ls` + `ps` on Mimir for an existing hef217/h217 child BEFORE launching.
