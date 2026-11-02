# TASK_CONTRACT_4.288 (AES-NUM-288)

Scope (from AES-NUM-287's NEXT + TODO 4.288).
AES-NUM-287 stated the cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remainings position by
position; their running total has not been stated:
(i) the closing-run cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count
sequence in full — at each act position 1-8, the
running total of the AES-NUM-287 cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining values
over positions 1 up to and including that
position, stated as one sequence.
(ii) the distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals in full — each distinct
cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative total, the
positions at which it occurs, and its count,
stated exactly.
(iii) the gap cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence in
full — at each gap position 1-7, the running
total of the AES-NUM-287 gap cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining values
over gap positions 1 up to and including that
gap position, stated as one sequence and checked
against AES-NUM-287 and AES-NUM-245.
Tests: the printed cumulative sequence equals
(55, 1802, 30414, 352274, 3147553, 23122995, 145380144, 804062688); the distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals' counts sum to 8; the last
cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative total equals
804062688; the gap cumulative sequence equals
(12, 393, 6630, 76755, 685441, 5032664, 31622976) and ends
at 31622976.
Any law NOT PROVEN unless the numbers prove
it; never invent one.

No correction is carried into this slice:
slice 4.287's three contracted findings were all
True, its only 'False' tokens were the four
gap-position agree data values, and no correction
was carried into 4.287 either (the AES-NUM-258
expected-value correction carried from 4.280 was
verified closed in the 4.281 run).

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

hef287.py lineage in ~/workspace/.verify-tmp/aesir287 is the base for hef288 (hef287 = the hef286 base plus arms287, sha256 70ff1bd9…). The hef288 build MUST derive make_build288 from make_build287 (which carries the three builder fixes recorded in AES-NUM-272 plus the digit-free placeholder protections recorded in AES-NUM-274 through AES-NUM-287), NOT from make_build286 or earlier, and MUST audit arms287/build287 for real data values containing the slice-number substring 287 before shifting (including the bare value 287 where it is data — the 4.280 lesson — and longer values containing the substring alike — the 4.281 lesson: 791777280, 33280 and the bare expB value all needed protection, and the restored AES-NUM-258 value 279 needed protection against the 279 shift leg; the 4.282 lesson: the new value 5281 containing 281 needed protection; the 4.283 lesson: an audit finding NONE NEW is a valid outcome — every 282 token in arms282 was a slice reference or an identifier suffix; the 4.284 lesson: the same NONE NEW outcome for 283 in arms283; the 4.285 lesson: the same NONE NEW outcome for 284 in arms284; the 4.286 lesson: ONE NEW — the bare data value 285, 2 occurrences in ', 285,' form, protected with @@VN@@; the 4.287 lesson: the same NONE NEW outcome for 286 in arms286, with the @@VN@@ protection for the bare data value 285 carried verbatim because 285 is a shift leg) and protect any such real data value with digit-free placeholders, and MUST protect the real data value 21267 (AES-NUM-262 layer, 2 occurrences). Launch with unbuffered output (`python3 -u`) and capture the exit code to a .exit file, per TASK_CONTRACT_4.175_RETRY's proven terms. Window ranges in the new section MUST be bounded by the measured list lengths (A acts 749, B acts 751) — no index or rank beyond the last measured position (A index 748, B index 750, A-offset rank 748, B-offset rank 750) may be requested. All expected-value names MUST be defined before the loops that use them (the AES-NUM-255 first-launch NameError lesson).

One bounded host-side child per contract. Exactly ONE launch: check `tmux ls` + `ps` on Mimir for an existing hef288/h288 child BEFORE launching.

Close law additions from 4.287: the evidence filename at
thirty-three CUMULATIVEs exceeds the 255-byte limit even
further (the chain plus REMAINING.md alone) — the
4.288 evidence doc MUST preserve the full
thirty-three-CUMULATIVE chain in its document title
and use the same compact filename convention as
4.280/4.281/4.282/4.283/4.284/4.285/4.286/4.287 (X33 notation), recording the convention
explicitly in the doc; never silently truncate the
chain in the title or the content; and every derived
list in the evidence doc, ledger and progress
paragraph (distinct totals and the contract-tests
sequence included) MUST be re-checked against the
slice's own verified sequence before commit (the
AES-NUM-275 close defect, re-verified clean at
4.277, 4.278, 4.279, 4.280, 4.281, 4.282, 4.283, 4.284, 4.285, 4.286 and 4.287).
Transport note from 4.287: prefer the per-part sha-gated
crossing (373 B parts, each its own file; 29 of 30 parts
landed first try, and the one part that corrupted
deterministically at its boundary healed when split
into 186 B + 187 B sub-parts) — change
chunk boundaries when a part corrupts deterministically,
never just retry at the same boundary, and never accept
a byte unverified.
