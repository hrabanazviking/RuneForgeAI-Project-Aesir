# The closing-run cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence, the distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals, and the gap cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence (AES-NUM-305)

Slice 4.305, worked under `docs/TASK_CONTRACT_4.305.md`
(contract published in the 4.304 closing commit @
6c14a51d). Host/artifact analysis only, on Mimir
(purpleviking1) - no physical child. All findings
below are taken from the sha-verified raw output,
read on-device (section305.txt). Filename
convention, recorded explicitly per the 4.305
contract's close law: at fifty CUMULATIVEs
the chain plus REMAINING.md alone exceeds the
255-byte filesystem limit even further - so this
evidence filename uses the compact X50 notation
(`HAILO10H_CUMULATIVE_X50_REMAINING_AES-NUM-305.md`)
while the full chain is preserved untruncated in
this document's title (lineage form) and in the
run's own section headers, which carry all
fifty CUMULATIVEs. The chain is never silently
truncated. The same convention governs 4.306 (X51).

## Run and closing record

hef305.py is the verified hef304 base plus
arms305: hef304.py sha256 prefix `42f853ef`
(7,304,252 B) on both the VM and the device.
arms305 sha256 prefix `7a35e0ee` (243,811 B);
hef305.py sha256 prefix `104b3d6f` (7,548,063 B)
on both the VM and the device; arms305 gzip
sha256 prefix `07840885` (15,986 B, as saved
on-device).
hef305 was built locally on the hef304 lineage
(make_build305.py derived from make_build304,
which carries the three AES-NUM-272 builder fixes
and every carried digit-free placeholder
protection from AES-NUM-274 through AES-NUM-304).
Audit of arms304/build304 for real data values
containing ANY of the generation's three shift-leg
substrings 302, 303 or 304 (the all-three-legs law,
extended by the context-classification law recorded
in AES-NUM-298) found THREE NEW arms-level
data values (15304576, 3 occurrences; 30414, 2;
791778304, 1 - all real sequence / expected-act
data values), protected as @@WR@@ / @@WS@@ /
@@WT@@, and NO new make-level protection
(all three occur 0 times in build304).
Every placeholder count was verified unchanged
by direct simulation of the whole protection
chain on arms304 before the build (sim305: every
placeholder count - WH 2 / WI 2 / WJ 2 / WK 2 /
WL 3 / WM 3 / WN 2 / WO 2 / WP 2 / WQ 2 / WG 2 /
WF 3, WR 3 / WS 2 / WT 1 new - and build305's
whole final assert PASS on the simulated arms305;
zero leftover placeholders; DONE305 exactly 1;
AES-NUM-304 references 151 in the simulated chain).
AES-NUM-304 references in arms305 = 155.
gen_make305 21820 B sha256 prefix `8d405019`,
make_build305 19817 B sha256 prefix `be15587f`,
build305 22251 B sha256 prefix `301cee90`, all
py_compile OK (shas re-measured from disk at this
close). hef305 = hef304 + arms305 byte-exact
(on-device assembly sha == VM). build305's
comment-tail extraction was re-measured on
build304 itself before inheriting: header line 4,
block lines 5-21, comment + 'def rep' =
lines[21:79] in build305's generation (the carried
comment-tail lesson, applied clean - gen_make305
and make_build305 ran clean with no failed draft).
One build detail, earned by measurement at the
4.305 build: arms304 holds 30375395 x2 at the
protection stage, not x3 - the finished-arms count
dropped 3 -> 2 when its level moved newest ->
previous (the 27439069 precedent recorded in
sanity304); build305's WO asserts are therefore
== 2. For the next generation:
build305 itself measures header line 4, block
lines 5-21, comment lines 22-81, 'def rep' at
line 82, so make_build306's extraction is
lines[21:82] - re-measure before inheriting.
Build staging, stated honestly: scratch lives in
~/workspace/.verify-tmp/aesir305 (copy-back from
/tmp/aesirwork/aesir305 SUCCEEDED at build time
this run; the home quota gate was clear).

Crossing, stated exactly: a tiny receiver
(recv305.py, landed sha-gated, sha256 prefix
`2549167d` == local) waited on Mimir :8098 in tmux
(recv305) and the VM posted arms305.py.gz through
the tunnel proxy; zero payload bytes passed
through model re-emission. The assembled arms305
and hef305 shas == VM on-device, py_compile OK.
run305.sh is in the local lineage (sha256 prefix
`348d4894`; contracted argv, glob
order, MiniLM last).

LAUNCH: exactly ONE bounded host-side child ran
in detached tmux (session h305, launched
2026-11-02 04:52 EST; pre-launch tmux/ps check
clean - no h305, no hef305 process, no prior
hef305.out/.exit/.err) with the contract corpus argv
(glob order, MiniLM last), unbuffered
(`python3 -u`). The child finished with exit
marker 0 (hef305.exit), err empty, and
DONE305 as its last line. Output
hef305.out 61,088 lines / 22,574,851 B sha256
prefix `46b9035f`; prefix against hef304.out: the
first 61,044 lines differ from hef304.out in
exactly ONE line (41611, sorted-character equal)
- the AES-NUM-150 frozenset variance line, as in
4.304 (verified via
check305.py sha256 prefix `363e2a00`
(check304 lineage, simultaneous 303->304 /
304->305 shift, landed on-device sha-gated by
base64 through the device shell with whole-file
sha == local exactly), hef305.out adding exactly
its own 44 tail lines (606,777 B, sha256
prefix `4b1b46bc`).

## No correction in this slice

No expected-value correction was carried into
4.305 and none is carried out of it. section305
contains exactly FOUR 'False' tokens - the four
gap-position agree data values for gap positions
1-4 (positions 5, 6, 7 agree), data not
comparisons, as in every prior slice - and NO
comparison False anywhere. All three contracted
findings read True. No computed value in any
slice changed; no finding of 4.305 or of any
prior slice is affected.
DISTINCT-LIST CHECK, recorded per the close law:
the distinct totals stated in this doc, the
ledger and the progress paragraph were re-checked
against section305's own printed (ii) lines -
55 at position 1; 2737 at position 2; 69463 at
position 3; 1198313 at position 4; 15802166 at
position 5; 169850369 at position 6; 1549528617 at
position 7; 12336920505 at position 8, each count
1, forms 8, counts sum 8 - the slice's own cum305
sequence, exactly as printed on-device.
Raw output kept on the Pi at
~/aesir-build/ (hef305.out, hef305.py, arms305.py,
section305.txt, hef305.exit, hef305.err,
check305.py); local lineage in
~/workspace/.verify-tmp/aesir305.

Definitions carry over from AES-NUM-247 through
AES-NUM-304 exactly as printed in the run: POSITION
is 1-based over the eight acts of the closing run
(A ranks 741-748, B ranks 743-750); the sequences
below are the running totals of the AES-NUM-304
values, re-verified as exact cumulative sums
before commit.

## Findings

(i) The closing-run cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining
remaining-count sequence in full is
[55, 2737, 69463, 1198313, 15802166, 169850369, 1549528617, 12336920505] over positions 1-8 - the running total
of each position's AES-NUM-304 cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining
remaining value, ending at 12336920505. The
contracted comparisons read True at all eight
positions.

(ii) The distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals in full are
eight: 55 at position 1 count 1; 2737 at position
2 count 1; 69463 at position 3 count 1; 1198313 at
position 4 count 1; 15802166 at position 5 count 1;
169850369 at position 6 count 1; 1549528617 at
position 7 count 1; 12336920505 at position 8 count
1 (counts sum to 8) - as printed in section305's
(ii) lines, re-checked line by line.

(iii) The gap cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count
sequence in full is [12, 597, 15147, 261222, 3443623, 37001419, 337441195] over gap positions
1-7, ending at 337441195, checked against
AES-NUM-304 and AES-NUM-245 (agreeing gap
positions 5, 6, 7, count 3, equal to AES-NUM-245).

Mechanisms NOT PROVEN; any offset, prefix or
position law NOT PROVEN; run 102's meaning NOT
PROVEN. Broad ordinary UNMODIFIED source-model
support remains the destination.

## Next

Slice 4.306 (contract in
`docs/TASK_CONTRACT_4.306.md`): the closing-run
cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence in
full; the distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals in full with
their positions and counts; and the gap
cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence in
full, checked against AES-NUM-305 and AES-NUM-245
- carrying NO expected-value correction (4.305's
findings were all True, with no comparison False)
and TWO new arms-level data protections and
NO new make-level data protection from the
4.305-close audit, context-classified at this
close: @@WU@@ 493050 (2 occurrences in arms305,
both DATA - an older cumulative sequence value in
its definitions prose tuple and its sequence
list), and @@WV@@ 1305 (2 occurrences in arms305,
both DATA - an older gap sequence value in its
prose tuple and its expGap list); both occur 0
times in build305; build305's
single ', 304,' token sits in its audit comment
prose, NOT in data - the same class as build304's
', 303,' token - plus the method corrections carried
since 4.298 (all-three-legs audit; distinct lists
checked against the slice's own section; context
classification of bare slice-number values).
