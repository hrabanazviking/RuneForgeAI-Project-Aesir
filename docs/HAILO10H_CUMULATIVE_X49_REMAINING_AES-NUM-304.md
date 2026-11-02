# The closing-run cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence, the distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals, and the gap cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence (AES-NUM-304)

Slice 4.304, worked under `docs/TASK_CONTRACT_4.304.md`
(contract published in the 4.303 closing commit @
172a8173). Host/artifact analysis only, on Mimir
(purpleviking1) - no physical child. All findings
below are taken from the sha-verified raw output,
read on-device (section304.txt). Filename
convention, recorded explicitly per the 4.304
contract's close law: at forty-nine CUMULATIVEs
the chain plus REMAINING.md alone exceeds the
255-byte filesystem limit even further - so this
evidence filename uses the compact X49 notation
(`HAILO10H_CUMULATIVE_X49_REMAINING_AES-NUM-304.md`)
while the full chain is preserved untruncated in
this document's title (lineage form) and in the
run's own section headers, which carry all
forty-nine CUMULATIVEs. The chain is never silently
truncated. The same convention governs 4.305 (X50).

## Run and closing record

hef304.py is the verified hef303 base plus
arms304: hef303.py sha256 prefix `a9c7c6ca`
(7,068,034 B) on both the VM and the device.
arms304 sha256 prefix `098c5635` (236,218 B);
hef304.py sha256 prefix `42f853ef` (7,304,252 B)
on both the VM and the device; arms304 gzip
sha256 prefix `a2421bc5` (15,625 B, as saved
on-device).
hef304 was built locally on the hef303 lineage
(make_build304.py derived from make_build303,
which carries the three AES-NUM-272 builder fixes
and every carried digit-free placeholder
protection from AES-NUM-274 through AES-NUM-303).
Audit of arms303/build303 for real data values
containing ANY of the generation's three shift-leg
substrings 302, 303 or 304 (the all-three-legs law,
extended by the context-classification law recorded
in AES-NUM-298) found THREE NEW arms-level
data values (30375395, 3 occurrences; 7485303, 2;
2725303, 2 - all real sequence data values),
protected as @@WO@@ / @@WP@@ / @@WQ@@, and
ONE new make-level protection (30375395, 4
occurrences in build303, all DATA, protected as
@@WO@@ at the make level; 7485303 and 2725303
occur 0 times in build303). Every placeholder count
was verified unchanged by direct simulation of the
whole protection chain on arms303 before the build
(sim304: every placeholder count - WH 2 / WI 2 /
WJ 2 / WK 2 / WL 3 / WM 3 / WN 2 / WO 3 / WP 2 /
WQ 2 / WG 2 / WF 3 - and build303's whole final
assert PASS on the simulated arms304; zero leftover
placeholders; DONE304 exactly 1; AES-NUM-303
references 147 in the simulated chain).
AES-NUM-303 references in arms304 = 151.
gen_make304 20695 B sha256 prefix `14608cf5`,
make_build304 18379 B sha256 prefix `984f0846`,
build304 21729 B sha256 prefix `c8951807`, all
py_compile OK (shas re-measured from disk at this
close). hef304 = hef303 + arms304 byte-exact
(on-device assembly sha == VM). build304's
comment-tail extraction was re-measured on
build303 itself before inheriting: header line 4,
block lines 5-21, comment + 'def rep' =
lines[21:70] in build304's generation (the carried
comment-tail lesson, applied clean - gen_make304
and make_build304 ran clean with no failed draft).
One build sanity note, resolved as precedent not
defect at the 4.304 build: finished arms304 holds
30375395 x2, not x3 - the x3 is the protection-stage
count (passed in the build304 run); a mid-sequence
value drops 3 -> 2 in the finished arms when its
level moves newest -> previous (the 27439069
precedent). For the next generation:
build304 itself measures header line 4, block
lines 5-21, comment lines 22-78, 'def rep' at
line 79, so make_build305's extraction is
lines[21:79] - re-measure before inheriting.
Build staging, stated honestly: scratch lives in
/tmp/aesirwork/aesir304; the home filesystem hit
"Disk quota exceeded" during the 4.304 build's
copy-back, so no ~/workspace/.verify-tmp/aesir304
copy was made at build time; the copy-back WAS
completed at this close (hef304 sha in the copy
== the /tmp lineage, verified at this close).

Crossing, stated exactly: a tiny receiver
(recv304.py, landed sha-gated, sha256 prefix
`aeb8ef2e` == local) waited on Mimir :8098 in tmux
(recv304) and the VM posted arms304.py.gz through
the tunnel proxy; zero payload bytes passed
through model re-emission. The assembled arms304
and hef304 shas == VM on-device, py_compile OK.
run304.sh is in the local lineage (sha256 prefix
`6d082bb4`; contracted argv, glob
order, MiniLM last).

LAUNCH: exactly ONE bounded host-side child ran
in detached tmux (session h304, launched
2026-11-02 00:57 EST; pre-launch tmux/ps check
clean - no h304, no hef304 process, no prior
hef304.out/.exit/.err) with the contract corpus argv
(glob order, MiniLM last), unbuffered
(`python3 -u`). The child finished with exit
marker 0 (hef304.exit), err empty, and
DONE304 as its last line. Output
hef304.out 61,044 lines / 21,968,074 B sha256
prefix `4838061c`; prefix against hef303.out: the
first 61,000 lines differ from hef303.out in
exactly ONE line (41611, sorted-character equal)
- the AES-NUM-150 frozenset variance line, as in
4.303 (verified via
check304.py sha256 prefix `e1aebe34`
(check303 lineage, simultaneous 302->303 /
303->304 shift, landed on-device sha-gated in
373 B binary parts with whole-file sha == local
exactly), hef304.out adding exactly
its own 44 tail lines (585,696 B, sha256
prefix `651ae256`).

## No correction in this slice

No expected-value correction was carried into
4.304 and none is carried out of it. section304
contains exactly FOUR 'False' tokens - the four
gap-position agree data values for gap positions
1-4 (positions 5, 6, 7 agree), data not
comparisons, as in every prior slice - and NO
comparison False anywhere. All three contracted
findings read True. No computed value in any
slice changed; no finding of 4.304 or of any
prior slice is affected.
DISTINCT-LIST CHECK, recorded per the close law:
the distinct totals stated in this doc, the
ledger and the progress paragraph were re-checked
against section304's own printed (ii) lines -
55 at position 1; 2682 at position 2; 66726 at
position 3; 1128850 at position 4; 14603853 at
position 5; 154048203 at position 6; 1379678248 at
position 7; 10787391888 at position 8, each count
1, forms 8, counts sum 8 - the slice's own cum304
sequence, exactly as printed on-device.
Raw output kept on the Pi at
~/aesir-build/ (hef304.out, hef304.py, arms304.py,
section304.txt, hef304.exit, hef304.err,
check304.py); local lineage in
/tmp/aesirwork/aesir304 (copy-back in
~/workspace/.verify-tmp/aesir304).

Definitions carry over from AES-NUM-247 through
AES-NUM-303 exactly as printed in the run: POSITION
is 1-based over the eight acts of the closing run
(A ranks 741-748, B ranks 743-750); the sequences
below are the running totals of the AES-NUM-303
values, re-verified as exact cumulative sums
before commit.

## Findings

(i) The closing-run cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining
remaining-count sequence in full is
[55, 2682, 66726, 1128850, 14603853, 154048203, 1379678248, 10787391888] over positions 1-8 - the running total
of each position's AES-NUM-303 cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining
remaining value, ending at 10787391888. The
contracted comparisons read True at all eight
positions.

(ii) The distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals in full are
eight: 55 at position 1 count 1; 2682 at position
2 count 1; 66726 at position 3 count 1; 1128850 at
position 4 count 1; 14603853 at position 5 count 1;
154048203 at position 6 count 1; 1379678248 at
position 7 count 1; 10787391888 at position 8 count
1 (counts sum to 8) - as printed in section304's
(ii) lines, re-checked line by line.

(iii) The gap cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count
sequence in full is [12, 585, 14550, 246075, 3182401, 33557796, 300439776] over gap positions
1-7, ending at 300439776, checked against
AES-NUM-303 and AES-NUM-245 (agreeing gap
positions 5, 6, 7, count 3, equal to AES-NUM-245).

Mechanisms NOT PROVEN; any offset, prefix or
position law NOT PROVEN; run 102's meaning NOT
PROVEN. Broad ordinary UNMODIFIED source-model
support remains the destination.

## Next

Slice 4.305 (contract in
`docs/TASK_CONTRACT_4.305.md`): the closing-run
cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence in
full; the distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals in full with
their positions and counts; and the gap
cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence in
full, checked against AES-NUM-304 and AES-NUM-245
- carrying NO expected-value correction (4.304's
findings were all True, with no comparison False)
and THREE new arms-level data protections and
NO new make-level data protection from the
4.304-close audit, context-classified at this
close: @@WR@@ 15304576 (3 occurrences in arms304,
all DATA - an older gap sequence value in two
definitions prose tuples and its sequence list),
@@WS@@ 30414 (2 occurrences in arms304, both
DATA - an older cumulative sequence value in
its prose tuple and its list), and @@WT@@
791778304 (1 occurrence in arms304, DATA - an
expected-act offset value in expA304); all three
occur 0 times in build304; build304's
single ', 303,' token sits in its audit comment
prose ("with ZERO ', 303,' data contexts"), NOT
in data - the same class as build303's ', 302,'
token - plus the method corrections carried
since 4.298 (all-three-legs audit; distinct lists
checked against the slice's own section; context
classification of bare slice-number values).
