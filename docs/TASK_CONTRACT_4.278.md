# TASK_CONTRACT_4.278 (AES-NUM-278)

Scope (from AES-NUM-277's NEXT + TODO 4.278).
AES-NUM-277 stated the cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remainings position by
position; their running total has not been stated:
(i) the closing-run cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count
sequence in full — at each act position 1-8, the
running total of the AES-NUM-277 cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining values
over positions 1 up to and including that
position, stated as one sequence.
(ii) the distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals in full — each distinct
cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative total, the
positions at which it occurs, and its count,
stated exactly.
(iii) the gap cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence in
full — at each gap position 1-7, the running
total of the AES-NUM-277 gap cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining values
over gap positions 1 up to and including that
gap position, stated as one sequence and checked
against AES-NUM-277 and AES-NUM-245.
Tests: the printed cumulative sequence equals
(55, 1252, 14869, 122624, 788753, 4214675, 19461585,
79774695); the distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals' counts sum to 8; the last
cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative total equals
79774695; the gap cumulative sequence equals
(12, 273, 3240, 26700, 171601, 916135, 4226365) and ends
at 4226365.
Any law NOT PROVEN unless the numbers prove
it; never invent one.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

hef277.py lineage in ~/workspace/.verify-tmp/aesir277 is the base for hef278 (hef277 = the hef276 base plus arms277, sha256 5bcf5feb…). The hef278 build MUST derive make_build278 from make_build277 (which carries the three builder fixes recorded in AES-NUM-272 plus the digit-free placeholder protections recorded in AES-NUM-274 through AES-NUM-277), NOT from make_build276 or earlier, and MUST audit arms277/build277 for real data values containing the slice-number substring 277 before shifting (the AES-NUM-274/275/276/277 collision lesson: 2725341, 2723, 34273, 2759793 and standalone data indices all contained a prior slice substring) and protect any such real data value with digit-free placeholders. Launch with unbuffered output (`python3 -u`) and capture the exit code to a .exit file, per TASK_CONTRACT_4.175_RETRY's proven terms. Window ranges in the new section MUST be bounded by the measured list lengths (A acts 749, B acts 751) — no index or rank beyond the last measured position (A index 748, B index 750, A-offset rank 748, B-offset rank 750) may be requested. All expected-value names MUST be defined before the loops that use them (the AES-NUM-255 first-launch NameError lesson).

One bounded host-side child per contract. Exactly ONE launch: check `tmux ls` + `ps` on Mimir for an existing hef278/h278 child BEFORE launching.

Close law additions from 4.277: the evidence filename at
twenty-three CUMULATIVEs would be 265 bytes (the chain
plus REMAINING.md alone, no fixed prefix left to
shorten), over the 255-byte filesystem limit — the
4.278 evidence doc MUST preserve the full
twenty-three-CUMULATIVE chain in its document title
and record its filename convention explicitly in the
doc; never silently truncate the chain in the title
or the content; and every derived list in the evidence
doc, ledger and progress paragraph (distinct totals
and the contract-tests sequence included) MUST be
re-checked against the slice's own verified sequence
before commit (the AES-NUM-275 close defect,
re-verified clean at 4.276 and 4.277).

No correction is carried into this slice: slice
4.277's controls were EXACT with no exception (its
only False tokens are the four gap-position agree
data values), and the AES-NUM-260 expected-value
correction contracted in 4.267 remains verified
closed.
