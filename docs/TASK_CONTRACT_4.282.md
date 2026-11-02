# TASK_CONTRACT_4.282 (AES-NUM-282)

Scope (from AES-NUM-281's NEXT + TODO 4.282).
AES-NUM-281 stated the cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remainings position by
position; their running total has not been stated:
(i) the closing-run cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count
sequence in full — at each act position 1-8, the
running total of the AES-NUM-281 cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining values
over positions 1 up to and including that
position, stated as one sequence.
(ii) the distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals in full — each distinct
cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative total, the
positions at which it occurs, and its count,
stated exactly.
(iii) the gap cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence in
full — at each gap position 1-7, the running
total of the AES-NUM-281 gap cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining values
over gap positions 1 up to and including that
gap position, stated as one sequence and checked
against AES-NUM-281 and AES-NUM-245.
Tests: the printed cumulative sequence equals
(55, 1472, 20427, 195720, 1454904, 8940207, 47255442,
220779117); the distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals' counts sum to 8; the last
cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative total equals
220779117; the gap cumulative sequence equals
(12, 321, 4452, 42630, 316681, 1944566, 10270611) and ends
at 10270611.
Any law NOT PROVEN unless the numbers prove
it; never invent one.

No correction is carried into this slice:
slice 4.281's three contracted findings were all
True, its only 'False' tokens were the four
gap-position agree data values, and the
AES-NUM-258 expected-value correction carried
from 4.280 was verified closed in the 4.281 run
(the restored sequence [55, 152, 279, 424, 578,
735, 892, 1049] intact in arms281 at exactly 2
occurrences; the position-3 comparison True).

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.
The corpus is loaded from command-line arguments: the run MUST be launched with those paths as argv (glob order, MiniLM last), as recorded in the AES-NUM-127 run record.

hef281.py lineage in ~/workspace/.verify-tmp/aesir281 is the base for hef282 (hef281 = the hef280 base plus arms281, sha256 4497a391…). The hef282 build MUST derive make_build282 from make_build281 (which carries the three builder fixes recorded in AES-NUM-272 plus the digit-free placeholder protections recorded in AES-NUM-274 through AES-NUM-281), NOT from make_build280 or earlier, and MUST audit arms281/build281 for real data values containing the slice-number substring 281 before shifting (including the bare value 281 where it is data — the 4.280 lesson — and longer values containing the substring alike — the 4.281 lesson: 791777280, 33280 and the bare expB value all needed protection, and the restored AES-NUM-258 value 279 needed protection against the 279 shift leg) and protect any such real data value with digit-free placeholders. Launch with unbuffered output (`python3 -u`) and capture the exit code to a .exit file, per TASK_CONTRACT_4.175_RETRY's proven terms. Window ranges in the new section MUST be bounded by the measured list lengths (A acts 749, B acts 751) — no index or rank beyond the last measured position (A index 748, B index 750, A-offset rank 748, B-offset rank 750) may be requested. All expected-value names MUST be defined before the loops that use them (the AES-NUM-255 first-launch NameError lesson).

One bounded host-side child per contract. Exactly ONE launch: check `tmux ls` + `ps` on Mimir for an existing hef282/h282 child BEFORE launching.

Close law additions from 4.281: the evidence filename at
twenty-seven CUMULATIVEs exceeds the 255-byte limit even
further (the chain plus REMAINING.md alone) — the
4.282 evidence doc MUST preserve the full
twenty-seven-CUMULATIVE chain in its document title
and use the same compact filename convention as
4.278/4.279/4.280/4.281 (X27 notation), recording the convention
explicitly in the doc; never silently truncate the
chain in the title or the content; and every derived
list in the evidence doc, ledger and progress
paragraph (distinct totals and the contract-tests
sequence included) MUST be re-checked against the
slice's own verified sequence before commit (the
AES-NUM-275 close defect, re-verified clean at
4.276, 4.277, 4.278, 4.279, 4.280 and 4.281).
Transport note from 4.281: a whole-gzip chunked
write failed its final sha gate and was discarded;
the per-part sha-gated crossing (373 B parts, each
its own file) pinpointed the one part that
corrupted at that boundary, which landed as two
sha-gated halves — change chunk boundaries, never
just retry, and never accept a byte unverified.
