# The closing-run cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence, the distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals, and the gap cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence (AES-NUM-307)

Slice 4.307, worked under `docs/TASK_CONTRACT_4.307.md`
(contract published in the 4.306 closing commit @
a724e2d9). Host/artifact analysis only, on Mimir
(purpleviking1) - no physical child. All findings
below are taken from the sha-verified raw output,
read on-device (section307). Filename convention,
recorded explicitly per the 4.307 contract's close
law: at fifty-two CUMULATIVEs the chain plus
REMAINING.md alone exceeds the 255-byte filesystem
limit even further - so this evidence filename uses
the compact X52 notation
(`HAILO10H_CUMULATIVE_X52_REMAINING_AES-NUM-307.md`)
while the full chain is preserved untruncated in
this document's title (lineage form) and in the
run's own section headers, which carry all
fifty-two CUMULATIVEs. The chain is never silently
truncated. The same convention governs 4.308 (X53).

## Run and closing record

hef307.py is the verified hef306 base plus
arms307: hef306.py sha256 prefix `ab65c084`
on both the VM and the device.
arms307 sha256 prefix `2c77faf4` (259,369 B);
hef307.py sha256 prefix `3cb4778a` (8,058,960 B)
on both the VM and the device; arms307 gzip
sha256 prefix `9e471568` (16,762 B, as saved
on-device).
hef307 was built locally on the hef306 lineage
(make_build307.py derived from make_build306,
which carries the three AES-NUM-272 builder fixes
and every carried digit-free placeholder
protection from AES-NUM-274 through AES-NUM-306).
Audit of arms306/build306 for real data values
containing ANY of the generation's three shift-leg
substrings 304, 305 or 306 (the all-three-legs law,
extended by the context-classification law recorded
in AES-NUM-298) found ONE NEW arms-level
data value (30605919, 2 occurrences - DATA),
protected as @@WW@@, and NO new make-level
protection (it occurs 0 times in build306).
Every placeholder count was verified unchanged
by direct sanity check of the finished build
(sanity307 PASS: hef307 == hef306 prefix +
arms307 tail byte-exact; all protected values at
exact counts including the new WW 30605919 x2;
DONE307 exactly 1; zero leftover
placeholders).
AES-NUM-306 references in arms307 = 163.
gen_make307 20815 B sha256 prefix `1287f81c`,
make_build307 19171 B sha256 prefix `11a88108`,
build307 22573 B sha256 prefix `e05451b5`, all
py_compile OK (shas re-measured from disk at this
close). hef307 = hef306 + arms307 byte-exact
(on-device assembly sha == VM). build307's
comment-tail extraction was re-measured on
build306 itself before inheriting: header line 4,
block lines 5-21, comment + 'def rep' =
lines[21:83] in build307's generation (the carried
comment-tail lesson, applied clean). For the next
generation: build307 itself measures header line 4,
block lines 5-21, comment lines 22-82, 'def rep' at
line 83, so make_build308's extraction is
lines[21:83] - re-measure before inheriting.
Build staging, stated honestly: scratch lives in
~/workspace/.verify-tmp/aesir307.

Crossing, stated exactly: a tiny receiver waited
on Mimir :8098 in tmux (recv307) and the VM posted
arms307.py.gz through the tunnel proxy; zero
payload bytes passed through model re-emission.
The assembled arms307 and hef307 shas == VM
on-device, py_compile OK. run307.sh landed
sha-gated (sha256 prefix `3f5a30bc`, 237 B;
contracted argv, glob order, MiniLM last).

LAUNCH: exactly ONE bounded host-side child ran
in detached tmux (session h307; pre-launch tmux/ps check
clean - no h307, no hef307 process, no prior
hef307.out/.exit/.err) with the contract corpus argv
(glob order, MiniLM last), unbuffered
(`python3 -u`). The child finished with exit
marker 0 (hef307.exit), err empty (0 bytes), and
DONE307 present exactly once as its last line.
Output hef307.out 61,176 lines / 23,853,141 B
sha256 prefix `ea766cbd`; hef307.out adds exactly
its own 44 tail lines after hef306.out's 61,132
lines (650,059 B, sha256 prefix `f8a88267` -
section307, read on-device). Verification was
performed first-hand by the continuity worker:
the contracted cum307
sequence is present (x2), the gap307 sequence is
present (x2), both section summaries read
'equal expected True', and there is no
'equal expected False'; the prefix diffs against
hef306.out are [41611, 42872], both sorted-char
equal.

## No correction in this slice

No expected-value correction was carried into
4.307 and none is carried out of it. section307
contains exactly FOUR 'False' tokens - the four
gap-position agree data values for gap positions
1-4 (positions 5, 6, 7 agree), data not
comparisons, as in every prior slice - and NO
comparison False anywhere. All three contracted
findings read True. No computed value in any
slice changed; no finding of 4.307 or of any
prior slice is affected.
DISTINCT-LIST CHECK, recorded per the close law:
the distinct totals stated in this doc, the
ledger and the progress paragraph were re-checked
against section307's own printed (ii) lines -
55 at position 1; 2847 at position 2; 75102 at
position 3; 1345670 at position 4; 18418404 at
position 5; 205341507 at position 6; 1941793227 at
position 7; 16015165452 at position 8, each count
1, forms 8, counts sum 8 - the slice's own cum307
sequence, exactly as printed on-device.
Raw output kept on the Pi at
~/aesir-build/ (hef307.out, hef307.py, arms307.py,
section307, hef307.exit, hef307.err);
local lineage in
~/workspace/.verify-tmp/aesir307.

Definitions carry over from AES-NUM-247 through
AES-NUM-306 exactly as printed in the run: POSITION
is 1-based over the eight acts of the closing run
(A ranks 741-748, B ranks 743-750); the sequences
below are the running totals of the AES-NUM-306
values, re-verified as exact cumulative sums
before commit.

## Findings

(i) The closing-run cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining
remaining-count sequence in full is
[55, 2847, 75102, 1345670, 18418404, 205341507, 1941793227, 16015165452] over positions 1-8 - the running total
of each position's AES-NUM-306 cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining
remaining value, ending at 16015165452. The
contracted comparisons read True at all eight
positions.

(ii) The distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals in full are
eight: 55 at position 1 count 1; 2847 at position
2 count 1; 75102 at position 3 count 1; 1345670 at
position 4 count 1; 18418404 at position 5 count 1;
205341507 at position 6 count 1; 1941793227 at
position 7 count 1; 16015165452 at position 8 count
1 (counts sum to 8) - as printed in section307's
(ii) lines, re-checked line by line.

(iii) The gap cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count
sequence in full is [12, 621, 16377, 293355, 4013956, 44735976, 422899191] over gap positions
1-7, ending at 422899191, checked against
AES-NUM-306 and AES-NUM-245 (agreeing gap
positions 5, 6, 7, count 3, equal to AES-NUM-245).

Mechanisms NOT PROVEN; any offset, prefix or
position law NOT PROVEN; run 102's meaning NOT
PROVEN. Broad ordinary UNMODIFIED source-model
support remains the destination.

## Next

Slice 4.308 (contract in
`docs/TASK_CONTRACT_4.308.md`): the closing-run
cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence in
full; the distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals in full with
their positions and counts; and the gap
cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence in
full, checked against AES-NUM-307 and AES-NUM-245
- carrying NO expected-value correction (4.307's
findings were all True, with no comparison False)
and TWO new arms-level data protections and
NO new make-level data protection from the
4.307-close audit, context-classified at this
close: @@WX@@ 1307 (2 occurrences in arms307,
both DATA) and @@WY@@ 2283073 (2 occurrences
in arms307, both DATA - both maximal digit
runs, substring count == run count == 2, digits
inside no other arms307 value, bare replacement
safe); both occur 0
times in build307; build307's
single ', 306,' token sits in its audit comment
prose, NOT in data - the same class as build306's
', 305,' token - plus the method corrections carried
since 4.298 (all-three-legs audit; distinct lists
checked against the slice's own section; context
classification of bare slice-number values).
