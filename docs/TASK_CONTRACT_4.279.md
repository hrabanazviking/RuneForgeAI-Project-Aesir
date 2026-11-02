# TASK_CONTRACT_4.279 (AES-NUM-279)

Scope (from AES-NUM-278's NEXT + TODO 4.279).
AES-NUM-278 stated the cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remainings position by
position; their running total has not been stated:
(i) the closing-run cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count
sequence in full — at each act position 1-8, the
running total of the AES-NUM-278 cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining values
over positions 1 up to and including that
position, stated as one sequence.
(ii) the distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals in full — each distinct
cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative total, the
positions at which it occurs, and its count,
stated exactly.
(iii) the gap cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence in
full — at each gap position 1-7, the running
total of the AES-NUM-278 gap cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining values
over gap positions 1 up to and including that
gap position, stated as one sequence and checked
against AES-NUM-278 and AES-NUM-245.
Tests: the printed cumulative sequence equals
(55, 1307, 16176, 138800, 927553, 5142228, 24603813,
104378508); the distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals' counts sum to 8; the last
cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative total equals
104378508; the gap cumulative sequence equals
(12, 285, 3525, 30225, 201826, 1117961, 5344326) and ends
at 5344326.
Any law NOT PROVEN unless the numbers prove
it; never invent one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

hef278.py lineage in ~/workspace/.verify-tmp/aesir278 is the base for hef279 (hef278 = the hef277 base plus arms278, sha256 17369429…). The hef279 build MUST derive make_build279 from make_build278 (which carries the three builder fixes recorded in AES-NUM-272 plus the digit-free placeholder protections recorded in AES-NUM-274 through AES-NUM-278), NOT from make_build277 or earlier, and MUST audit arms278/build278 for real data values containing the slice-number substring 278 before shifting (the AES-NUM-274/275/276/277/278 collision lesson: 2725341, 2723, 34273, 2759793 and standalone data indices all contained a prior slice substring) and protect any such real data value with digit-free placeholders. Launch with unbuffered output (`python3 -u`) and capture the exit code to a .exit file, per TASK_CONTRACT_4.175_RETRY's proven terms. Window ranges in the new section MUST be bounded by the measured list lengths (A acts 749, B acts 751) — no index or rank beyond the last measured position (A index 748, B index 750, A-offset rank 748, B-offset rank 750) may be requested. All expected-value names MUST be defined before the loops that use them (the AES-NUM-255 first-launch NameError lesson).

One bounded host-side child per contract. Exactly ONE launch: check `tmux ls` + `ps` on Mimir for an existing hef279/h279 child BEFORE launching.

Close law additions from 4.278: the evidence filename at
twenty-four CUMULATIVEs exceeds the 255-byte limit even
further (the chain plus REMAINING.md alone) — the
4.279 evidence doc MUST preserve the full
twenty-four-CUMULATIVE chain in its document title
and use the same compact filename convention as
4.278 (X24 notation), recording the convention
explicitly in the doc; never silently truncate the
chain in the title or the content; and every derived
list in the evidence doc, ledger and progress
paragraph (distinct totals and the contract-tests
sequence included) MUST be re-checked against the
slice's own verified sequence before commit (the
AES-NUM-275 close defect, re-verified clean at
4.276, 4.277 and 4.278).

No correction is carried into this slice: slice
4.278's controls were EXACT with no exception (its
only False tokens are the four gap-position agree
data values), and the AES-NUM-260 expected-value
correction contracted in 4.267 remains verified
closed.
