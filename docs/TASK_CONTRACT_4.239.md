# TASK_CONTRACT_4.239 (AES-NUM-239)

Scope (from AES-NUM-238's NEXT + TODO 4.239).
AES-NUM-238 closed the two closing runs' seventh
acts side by side, but the eighth (terminal) acts
of the two closing runs have not been set side by
side in this sequence:
(i) the act at A-offset rank 748 in full —
(791780864, 24, 0) at A 748, rank 748; the
eighth and last act of the A closing run
(ranks 741-748) and the last act of context A
in A-offset order (749 acts, ranks 0-748), with
its incoming gap in A-offset order stated
exactly. It has NO outgoing gap: no rank 749
exists in A-offset order.
(ii) the act at B-offset rank 750 in full —
(1196445696, 24, 0) at B 738, rank 750; the
eighth and last act of the B closing run
(ranks 743-750) and the last act of context B
in B-offset order (751 acts, ranks 0-750), with
its incoming gap in B-offset order stated
exactly. It has NO outgoing gap: no rank 751
exists in B-offset order.
(iii) the closing-run eighth-act comparison in
full — the eighth acts of the two closing runs
(A rank 748 and B rank 750) stated side by
side: rank, index, act, class, run-102
membership, incoming gap per eighth act, and
terminal status (no outgoing gap on either
side). Tests: each eighth act's stated
incoming gap equals the seventh gap of its own
run's gap sequence as measured in AES-NUM-231
(A run gap sequence [512, 512, 512, 512, 512,
512, 512], seventh gap 512; B run gap sequence
[712, 26624, 14848, 33280, 512, 512, 512],
seventh gap 512) — the seventh gap of each run
is the transition from its seventh act to its
eighth act, i.e. the eighth act's incoming gap.
Any law NOT PROVEN unless the numbers prove
it; never invent one.

DEFECT FIX CARRIED FROM AES-NUM-238: in
arms238 the (iii) comparison computed the B
incoming gap against the act at rank 749 (the
act itself) instead of its predecessor at rank
748, printing +0. In this slice the comparison's
gap fields MUST be computed from exactly the
same predecessor ranks as the per-act
statements, and the section MUST print a
consistency check that the comparison's
incoming gaps equal the statements' incoming
gaps for both sides.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

hef238.py lineage in ~/workspace/.verify-tmp/aesir238 is the base for hef239 (hef238 = the hef237 base plus arms238, sha256 448fa3f1…). Launch with unbuffered output (`python3 -u`) and capture the exit code to a .exit file, per TASK_CONTRACT_4.175_RETRY's proven terms. Window ranges in the new section MUST be bounded by the measured list lengths (A acts 749, B acts 751) — no index or rank beyond the last measured position (A index 748, B index 750, A-offset rank 748, B-offset rank 750) may be requested; terminal neighbourhoods are truncated at the list end.

One bounded host-side child per contract. Exactly ONE launch: check `tmux ls` + `ps` on Mimir for an existing hef239/h239 child BEFORE launching.
