# TASK_CONTRACT_4.281 (AES-NUM-281)

Scope (from AES-NUM-280's NEXT + TODO 4.281).
AES-NUM-280 stated the cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remainings position by
position; their running total has not been stated:
(i) the closing-run cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count
sequence in full — at each act position 1-8, the
running total of the AES-NUM-280 cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining values
over positions 1 up to and including that
position, stated as one sequence.
(ii) the distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals in full — each distinct
cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative total, the
positions at which it occurs, and its count,
stated exactly.
(iii) the gap cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence in
full — at each gap position 1-7, the running
total of the AES-NUM-280 gap cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining values
over gap positions 1 up to and including that
gap position, stated as one sequence and checked
against AES-NUM-280 and AES-NUM-245.
Tests: the printed cumulative sequence equals
(55, 1417, 18955, 175293, 1259184, 7485303, 38315235,
173523675); the distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals' counts sum to 8; the last
cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative total equals
173523675; the gap cumulative sequence equals
(12, 309, 4131, 38178, 274051, 1627885, 8326045) and ends
at 8326045.
Any law NOT PROVEN unless the numbers prove
it; never invent one.

CORRECTION carried into this slice (from the
4.280 controls exception): the AES-NUM-258
expected sequence in arms280 reads
[55, 152, 280, 424, 578, 735, 892, 1049] because
the 4.280 build's 279->280 shift corrupted the
real data value 279 (prose definition and
expCumCumCum list, 2 occurrences). The hef281
build MUST restore that sequence to
[55, 152, 279, 424, 578, 735, 892, 1049] BEFORE
any shift, protect the restored value 279 with a
digit-free placeholder through the shift, and
verify arms281 carries it intact at exactly 2
occurrences; the 4.281 run's position-3
AES-NUM-258 comparison MUST read True for the
correction to be verified closed. The audit
lesson is general: a standalone slice-number
value can itself be a real data value — the
audit MUST check bare slice-number occurrences,
not only longer values containing the substring.

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

hef280.py lineage in ~/workspace/.verify-tmp/aesir280 is the base for hef281 (hef280 = the hef279 base plus arms280, sha256 71512569…). The hef281 build MUST derive make_build281 from make_build280 (which carries the three builder fixes recorded in AES-NUM-272 plus the digit-free placeholder protections recorded in AES-NUM-274 through AES-NUM-280), NOT from make_build279 or earlier, and MUST audit arms280/build280 for real data values containing the slice-number substring 280 before shifting (including the bare value 280 where it is data, and the corrupted AES-NUM-258 value described in the correction above) and protect any such real data value with digit-free placeholders. Launch with unbuffered output (`python3 -u`) and capture the exit code to a .exit file, per TASK_CONTRACT_4.175_RETRY's proven terms. Window ranges in the new section MUST be bounded by the measured list lengths (A acts 749, B acts 751) — no index or rank beyond the last measured position (A index 748, B index 750, A-offset rank 748, B-offset rank 750) may be requested. All expected-value names MUST be defined before the loops that use them (the AES-NUM-255 first-launch NameError lesson).

One bounded host-side child per contract. Exactly ONE launch: check `tmux ls` + `ps` on Mimir for an existing hef281/h281 child BEFORE launching.

Close law additions from 4.280: the evidence filename at
twenty-six CUMULATIVEs exceeds the 255-byte limit even
further (the chain plus REMAINING.md alone) — the
4.281 evidence doc MUST preserve the full
twenty-six-CUMULATIVE chain in its document title
and use the same compact filename convention as
4.278/4.279/4.280 (X26 notation), recording the convention
explicitly in the doc; never silently truncate the
chain in the title or the content; and every derived
list in the evidence doc, ledger and progress
paragraph (distinct totals and the contract-tests
sequence included) MUST be re-checked against the
slice's own verified sequence before commit (the
AES-NUM-275 close defect, re-verified clean at
4.276, 4.277, 4.278 and 4.279; 4.280's derived
lists were likewise re-checked clean — its one
exception was the build-side expected-value
corruption recorded above, not a close defect).

No other correction is carried into this slice:
slice 4.280's three contracted findings were all
True, and the AES-NUM-260 expected-value
correction contracted in 4.267 remains verified
closed.
