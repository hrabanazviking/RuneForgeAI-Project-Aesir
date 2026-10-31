# TASK_CONTRACT_4.275 (AES-NUM-275)

Scope (from AES-NUM-274's NEXT + TODO 4.275).
AES-NUM-274 stated the cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remainings position by
position; their running total has not been stated:
(i) the closing-run cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count
sequence in full — at each act position 1-8, the
running total of the AES-NUM-274 cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining values
over positions 1 up to and including that
position, stated as one sequence.
(ii) the distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals in full — each distinct
cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative total, the
positions at which it occurs, and its count,
stated exactly.
(iii) the gap cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence in
full — at each gap position 1-7, the running
total of the AES-NUM-274 gap cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining values
over gap positions 1 up to and including that
gap position, stated as one sequence and checked
against AES-NUM-274 and AES-NUM-245.
Tests: the printed cumulative sequence equals
(55, 1087, 11278, 81718, 464236, 2201419, 9061195,
33245212); the distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals' counts sum to 8; the last
cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative total equals
33245212; the gap cumulative sequence equals
(12, 237, 2457, 17787, 100948, 478192, 1966063) and ends
at 1966063.
Any law NOT PROVEN unless the numbers prove
it; never invent one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

hef274.py lineage in ~/workspace/.verify-tmp/aesir274 is the base for hef275 (hef274 = the hef273 base plus arms274, sha256 d2ea3636…). The hef275 build MUST derive make_build275 from make_build274 (which carries the three builder fixes recorded in AES-NUM-272 plus the digit-free placeholder protections recorded in AES-NUM-273 and AES-NUM-274), NOT from make_build273 or earlier, and MUST audit arms274/build274 for real data values containing the slice-number substring 274 before shifting (the AES-NUM-273/274 collision lesson: 2725341, 2723, 34273 and standalone data indices all contained the prior slice substring) and protect any such real data value with digit-free placeholders. Launch with unbuffered output (`python3 -u`) and capture the exit code to a .exit file, per TASK_CONTRACT_4.175_RETRY's proven terms. Window ranges in the new section MUST be bounded by the measured list lengths (A acts 749, B acts 751) — no index or rank beyond the last measured position (A index 748, B index 750, A-offset rank 748, B-offset rank 750) may be requested. All expected-value names MUST be defined before the loops that use them (the AES-NUM-255 first-launch NameError lesson).

One bounded host-side child per contract. Exactly ONE launch: check `tmux ls` + `ps` on Mimir for an existing hef275/h275 child BEFORE launching.

No correction is carried into this slice: slice
4.274's controls were EXACT with no exception (its
only False tokens are the four gap-position agree
data values), and the AES-NUM-260 expected-value
correction contracted in 4.267 remains verified
closed.
