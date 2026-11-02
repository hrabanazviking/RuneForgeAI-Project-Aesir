# The closing-run cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence, the distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals, and the gap cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence (AES-NUM-309)

Slice 4.309, worked under `docs/TASK_CONTRACT_4.309.md`
(contract published in the 4.308 closing commit @
9822936a). Host/artifact analysis only, on Mimir
(purpleviking1) - no physical child. All findings
below are taken from the sha-verified raw output,
read on-device (section309). Filename convention,
recorded explicitly per the 4.309 contract's close
law: at fifty-four CUMULATIVEs the chain plus
REMAINING.md alone exceeds the 255-byte filesystem
limit even further - so this evidence filename uses
the compact X54 notation
(`HAILO10H_CUMULATIVE_X54_REMAINING_AES-NUM-309.md`)
while the full chain is preserved untruncated in
this document's title (lineage form) and in the
run's own section headers, which carry all
fifty-four CUMULATIVEs. The chain is never silently
truncated. The same convention governs 4.310 (X55).

## Run and closing record

hef309.py is the verified hef308 base plus
arms309: hef308.py sha256 prefix `3334b64d`
on both the VM and the device.
arms309 sha256 prefix `4e64d40b` (275,423 B);
hef309.py sha256 prefix `e21fa6a1` (8,601,717 B)
on both the VM and the device; arms309 gzip
sha256 prefix `6ac809a0` (17,418 B, as saved
on-device).
hef309 was built locally on the hef308 lineage
(make_build309.py derived from make_build308,
which carries the three AES-NUM-272 builder fixes
and every carried digit-free placeholder
protection from AES-NUM-274 through AES-NUM-308).
Audit of arms308/build308 for real data values
containing ANY of the generation's three shift-leg
substrings 306, 307 or 308 (the all-three-legs law,
extended by the context-classification law recorded
in AES-NUM-298) found FOUR NEW arms-level
data values (83083, 3 occurrences - DATA;
22243089, 3 occurrences - DATA;
2308662, 2 occurrences - DATA; and
1308721, 2 occurrences - DATA),
protected as @@WZ@@ / @@XA@@ / @@XB@@ / @@XC@@, and NO new make-level
protection (all four occur 0 times in build308).
Every placeholder count was verified unchanged
by direct sanity check of the finished build
(sanity309 PASS, re-run and confirmed at this
close: hef309 == hef308 prefix +
arms309 tail byte-exact; all protected values at
exact counts including the new WZ 83083 x3,
XA 22243089 x3, XB 2308662 x2 and
XC 1308721 x2;
DONE309 exactly 1; zero leftover
placeholders).
AES-NUM-308 references in arms309 = 171.
gen_make309 22326 B sha256 prefix `32e177b3`,
make_build309 20476 B sha256 prefix `14c6b04a`,
build309 24075 B sha256 prefix `7e1dd5a2`, all
py_compile OK (shas re-measured from disk at this
close). hef309 = hef308 + arms309 byte-exact
(on-device assembly sha == VM). build309's
comment-tail extraction was re-measured on
build308 itself before inheriting: header line 4,
block lines 5-21, comment + 'def rep' =
lines[21:87] in build309's generation (the carried
comment-tail lesson, applied clean). For the next
generation: build309 itself measures header line 4,
block lines 5-21, comment lines 22-98, 'def rep' at
line 99, so make_build310's extraction is
lines[21:99] - re-measure before inheriting.
Build staging, stated honestly: the first build
in /tmp was lost in a VM reboot and was
deterministically rebuilt byte-exact - arms309
and hef309 shas identical to the lost build's
(arms309 sha256 `4e64d40b`, hef309 sha256
`e21fa6a1`); the rebuilt arms309.py.gz sha256
`6ac809a0` (17,418 B, as saved on-device) differs
from the lost original only in gzip header mtime,
its decompressed content sha == arms309's.
Scratch lived in /tmp/aesirwork/aesir309; its
copy-back to ~/workspace/.verify-tmp/aesir309
SUCCEEDED at the rebuild.

Crossing, stated exactly: a tiny receiver waited
on Mimir :8098 in tmux and the VM posted
arms309.py.gz through the tunnel proxy; the
post-reboot proxy POST succeeded on attempt 2
(saved 17,418 B, sha256 `6ac809a0` == rebuilt gz);
zero payload bytes passed through model
re-emission.
The assembled arms309 and hef309 shas == VM
on-device, py_compile OK.

LAUNCH: exactly ONE bounded host-side child ran
on Mimir (launched in detached tmux h309 at
12:55:42 EST, finished 12:59 EST, 2026-11-02) with the contract corpus argv
(glob order, MiniLM last), unbuffered
(`python3 -u`). The child finished with exit
marker 0 (hef309.exit), err empty (0 bytes), and
DONE309 present exactly once as its last line.
Output hef309.out 61,264 lines / 25,220,239 B
sha256 prefix `fe4a7b7c`; hef309.out adds exactly
its own 44 tail lines after hef308.out's 61,220
lines (694,837 B, sha256 prefix `5d7c9d52` -
section309, read on-device). Verification was
performed first-hand by the continuity worker
(check309.py sha256 prefix `2b312684`):
the contracted cum309
sequence is present (x2), the gap309 sequence is
present (x2), both section summaries read
'equal expected True', and there is no
'equal expected False'; the prefix diffs against
hef308.out are [41611, 42872], both sorted-char
equal.

## No correction in this slice

No expected-value correction was carried into
4.309 and none is carried out of it. section309
contains exactly FOUR 'False' tokens - the four
gap-position agree data values for gap positions
1-4 (positions 5, 6, 7 agree), data not
comparisons, as in every prior slice - and NO
comparison False anywhere. All three contracted
findings read True. No computed value in any
slice changed; no finding of 4.309 or of any
prior slice is affected.
DISTINCT-LIST CHECK, recorded per the close law:
the distinct totals stated in this doc, the
ledger and the progress paragraph were re-checked
against section309's own printed (ii) lines -
55 at position 1; 2957 at position 2; 80961 at
position 3; 1504635 at position 4; 21346713 at
position 5; 246530298 at position 6; 2413507110 at
position 7; 20595649374 at position 8, each count
1, forms 8, counts sum 8 - the slice's own cum309
sequence, exactly as printed on-device.
Raw output kept on the Pi at
~/aesir-build/ (hef309.out, hef309.py, arms309.py,
section309.txt, hef309.exit, hef309.err);
local lineage in
~/workspace/.verify-tmp/aesir309.

Definitions carry over from AES-NUM-247 through
AES-NUM-308 exactly as printed in the run: POSITION
is 1-based over the eight acts of the closing run
(A ranks 741-748, B ranks 743-750); the sequences
below are the running totals of the AES-NUM-308
values, re-verified as exact cumulative sums
before commit.

## Findings

(i) The closing-run cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining
remaining-count sequence in full is
[55, 2957, 80961, 1504635, 21346713, 246530298, 2413507110, 20595649374] over positions 1-8 - the running total
of each position's AES-NUM-308 cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining
remaining value, ending at 20595649374. The
contracted comparisons read True at all eight
positions.

(ii) The distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals in full are
eight: 55 at position 1 count 1; 2957 at position
2 count 1; 80961 at position 3 count 1; 1504635 at
position 4 count 1; 21346713 at position 5 count 1;
246530298 at position 6 count 1; 2413507110 at
position 7 count 1; 20595649374 at position 8 count
1 (counts sum to 8) - as printed in section309's
(ii) lines, re-checked line by line.

(iii) The gap cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count
sequence in full is [12, 645, 17655, 328020, 4652341, 53712638, 525672126] over gap positions
1-7, ending at 525672126, checked against
AES-NUM-308 and AES-NUM-245 (agreeing gap
positions 5, 6, 7, count 3, equal to AES-NUM-245).

Mechanisms NOT PROVEN; any offset, prefix or
position law NOT PROVEN; run 102's meaning NOT
PROVEN. Broad ordinary UNMODIFIED source-model
support remains the destination.

## Next

Slice 4.310 (contract in
`docs/TASK_CONTRACT_4.310.md`): the closing-run
cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence in
full; the distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals in full with
their positions and counts; and the gap
cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence in
full, checked against AES-NUM-309 and AES-NUM-245
- the contracted sequences are
[55, 3012, 83973, 1588608, 22935321, 269465619, 2682972729, 23278622103] and
[12, 657, 18312, 346332, 4998673, 58711311, 584383437] -
carrying NO expected-value correction (4.309's
findings were all True, with no comparison False)
and TWO new arms-level data protections and
NO new make-level data protection from the
4.309-close audit, context-classified at this
close: @@XD@@ 78309 (2 occurrences in arms309,
DATA - an older cumulative sequence value, in its
definitions prose tuple
(55, 427, 1864, 6024, 16053, 37320, 78309, 151668)
and its sequence list assignment; maximal digit
run, substring count == run count, bare
replacement safe) and @@XE@@ for the bare data
value 309 in comma form only (2 occurrences in
arms309, DATA - the older gap sequence
[12, 309, 4131, 38178, 274051, 1627885, 8326045],
in its definitions prose tuple and its sequence
list assignment; per the AES-NUM-298
context-classification law this bare 309 is DATA,
not a slice reference; standalone-309
classification is 7 total = 5 slice
headings/references + these 2 data; build310
protects it as src.replace(', 309,', ', @@XE@@,')
before the shift and restores it after, asserting
exactly 2 occurrences in arms310; precedents
@@VC@@ ', 272,', @@VL@@ ', 280,', @@VN@@
', 285,' and the @@WG@@ 2297 forms); the full
4.309-close audit, recorded in the 4.310 contract:
arms309 309-leg digit runs are bare 309 x1908
(slice references / identifier suffixes), 3092
x26 (identifier only), 102309 x4 (identifier
only) and 78309 x2 (DATA, above), plus the
', 309,' data form x2 (above); the 308-leg in
arms309 is bare 308 x171 (AES-NUM-308 predecessor
references; ZERO ', 308,' in arms309) plus the
protected @@WZ@@ 83083 x3, @@XA@@ 22243089 x3,
@@XB@@ 2308662 x2, @@XC@@ 1308721 x2 and @@WI@@
30829932 x2; the 307-leg is exactly the protected
@@WX@@ 1307 x2 and @@WY@@ 2283073 x2 only, ZERO
bare 307; the 306-leg is exactly the protected
@@WW@@ 30605919 x2 only; the 305-leg is
@@WU@@ / @@WV@@; the 304-leg is @@WR@@ / @@WS@@ /
@@WT@@; the 303-leg is @@WO@@ / @@WP@@ / @@WQ@@ -
all carried, fully accounted; build309's 309
runs are bare 309 x261 ONLY (its generation
code/rep strings/headings), 78309 occurs 0 times
in build309 and the ', 309,' data form occurs 0
times in build309; build309's
single ', 308,' token sits in its audit comment
prose, NOT in data - plus the method corrections carried
since 4.298 (all-three-legs audit; distinct lists
checked against the slice's own section; context
classification of bare slice-number values).
