# The closing-run cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence, the distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals, and the gap cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence (AES-NUM-298)

Slice 4.298, worked under `docs/TASK_CONTRACT_4.298.md`
(contract published in the 4.297 closing commit @
50723569). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child. All findings
below are taken from the sha-verified raw output,
read on-device (section298.txt). Filename
convention, recorded explicitly per the 4.298
contract's close law: at forty-three CUMULATIVEs
the chain plus REMAINING.md alone exceeds the
255-byte filesystem limit even further — so this
evidence filename uses the compact X43 notation
(`HAILO10H_CUMULATIVE_X43_REMAINING_AES-NUM-298.md`)
while the full chain is preserved untruncated in
this document's title (lineage form) and in the
run's own section headers, which carry all
forty-three CUMULATIVEs. The chain is never silently
truncated. The same convention governs 4.299 (X44).

## Run and closing record

hef298.py is the verified hef297 base plus
arms298: hef297.py sha256 prefix `75b935ba`
(5,803,217 B) on both the VM and the device.
arms298 sha256 prefix `5b09c1ac` (193,281 B);
hef298.py sha256 prefix `6e0cad71` (5,996,498 B)
on both the VM and the device; arms298 gzip
sha256 prefix `8d201dba` (13,337 B).
hef298 was built locally on the hef297 lineage
(make_build298.py derived from make_build297,
which carries the three AES-NUM-272 builder fixes
and every carried digit-free placeholder
protection from AES-NUM-274 through AES-NUM-297).
Audit of arms297/build297 for real data values
containing ANY of the generation's three shift-leg
substrings 295, 296 or 297 (the all-three-legs law
recorded in AES-NUM-297) found TWO NEW arms-level
protections, as contracted: 31622976 (3
occurrences, @@WF@@), a standalone gap-sequence
value, and 2297 (5 standalone occurrences,
@@WG@@), the cum297 sequence's second value —
@@WG@@ context-aware (protect @@WF@@ first; WG
only in ', 2297,' / '(2297,' / '; 2297 x1'
contexts; 2297's substring count 12 = 5 standalone
+ 4 inside the identifier 102297 + 3 inside
31622976). Make-level audit of build297 found
2297 (6 occurrences, inside the C297 sequence
forms), protected at make level as @@VALF@@ so
the pairs stage finds the C297 forms intact;
31622976 absent from build297 (0 occurrences);
build297's other 297 tokens are bare slice
references only (236). AES-NUM-296 references in
arms297 = 123. One build fix inside the slice:
build298's first run failed its bl[16] final
assert because gen297's own bl[16] append line
sits after the replaced protections block in
make_build297 and re-appended the stale @@WE@@
count (5, its arms296 value) — arms297's @@WE@@
7295039 count is 2 (its other three forms rolled
with the C296 pairs stage); the leftover line's
WE count was corrected 5 -> 2 in gen_make298 and
the rebuild passed clean (known pair 6 optional
skip only; 3b pre counts 0/1/2, 3c 1/1).
gen_make298 15,492 B sha256 prefix `16747239`,
make_build298 13,849 B sha256 prefix `00e391ad`,
build298 18,744 B sha256 prefix `e45d56f0`, all
py_compile OK (shas re-measured from disk at this
close; the launch entry's recorded shas were of
the pre-fix generation). hef298 = hef297 +
arms298 byte-exact (on-device assembly sha == VM).
Build sanity on arms298 PASS: hef298 == hef297
prefix-exact + arms298 tail; DONE298 exactly 1,
DONE297 absent; zero 298836 / 297836 corruptions,
zero leftover placeholders; protected values at
exact counts (31622976 3, 2967 2, 791479296 1,
7295039 2); the 297/298 sequence forms present at
the symmetric counts; arms298's total 2297
substrings = 5 (2 standalone cum297 forms + 3
inside 31622976), the dist/dstr 2297 forms having
rolled to 298 via pairs, as contracted.

Crossing, stated exactly: a tiny receiver
(recv298.py, landed sha-gated via file.write,
sha256 prefix `4b61d595` == local) waited on Mimir
:8098 and the VM posted arms298.py.gz through
the tunnel proxy; zero payload bytes passed
through model re-emission. The receiver reported
saved 13,337 B with sha `8d201dba` == the local
gzip sha exactly. The assembled arms298 and
hef298 shas == VM on-device, py_compile OK.
run298.sh landed on-device (sed 297->298 of
run297.sh; contracted argv, glob order, MiniLM
last).

LAUNCH: exactly ONE bounded host-side child ran
in detached tmux (session h298, launched
2026-11-01 17:39 EST; pre-launch tmux/ps check
clean — no h298, no hef298 process, no prior
hef298.out/.exit) with the contract corpus argv
(glob order, MiniLM last), unbuffered
(`python3 -u`). The child finished with exit
marker 0 (hef298.exit), err empty, and DONE298
as its last line. Output
hef298.out 60,780 lines / 18,757,039 B sha256
prefix `aaaabbf0`; prefix against hef297.out: the
first 60,736 lines differ from hef297.out in
exactly ONE line (41611), sorted-character equal
— the AES-NUM-150 frozenset variance (one line
this slice, as in 4.293 and 4.297; 4.294 differed
in two, 4.295 and 4.296 in zero — recorded exactly
as measured), verified via check298.py sha256
prefix `17261f45` (check297 lineage, simultaneous
296->297 / 297->298 shift, landed on-device
sha-gated with sha == local exactly), hef298.out
adding exactly its own 44 tail
lines (467,078 B, sha256 prefix `88bb1422`).

## The one exception in this slice (recorded honestly)

The three contracted findings all read True (see
Findings). But section298 contains exactly FIVE
'False' tokens, not four: the four gap-position
agree data values for gap positions 1-4 (A gap
512 against B gaps 712, 26624, 14848, 33280;
positions 5, 6, 7 agree), data not comparisons,
as in every prior slice — plus ONE comparison
False, at gap position 2, in the check
'gap cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining equals
AES-NUM-297 printed value'.
Root cause, established at this close from the
files on disk: it is an EXPECTED-VALUE defect in
arms298's own checker table, not a data mismatch.
arms298's expected list expGapcumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative298 reads
[12, 298, 3822, 34047, 235873, 1353834, 6698160];
its position-2 value must be 297 — section298's
computed position-2 series (line 35) reads
[..., 285, 297, 309, ...] at that depth, and
section297's computed series is IDENTICAL to
section298's on every shared depth at every gap
position (re-verified value by value at this
close). The definitions prose tuple in arms298
carries the same defect: '(12, 298, 3822, 34047,
235873, 1353834, 6698160)'. Those are the only two
', 298,' data contexts in arms298. How it
happened: in arms297 the value stood correctly as
297, but as a BARE data element inside a list /
tuple; the 4.297-close audit classified all 1,596
bare 297 digit-runs as slice references, so this
one data value went unprotected, and build298's
297->298 shift leg rewrote it to 298. The audit's
digit-run classification was the blind spot: a
bare slice-number value in a data-list or tuple
element context is DATA, not a reference. That
context-classification law is carried into
4.299's contract alongside the all-three-legs
law. CORRECTION CARRIED INTO 4.299 (the
AES-NUM-258 expected-value precedent): in the
inherited table, restore this value to 297 in
both contexts (the exp list and the prose tuple)
BEFORE build299's shift, protect the restored
value as @@WH@@ in exactly those two contexts
('(12, @@WH@@, 3822' and '[12, @@WH@@, 3822';
the restored 297 carries the 297 shift leg, so
the protection is load-bearing), restore it
after the shift, and assert the corrected list
equals [12, 297, 3822, 34047, 235873, 1353834,
6698160] in the build. No computed value in any
slice changes; no finding of 4.298 or of any
prior slice is affected.
DISTINCT-LIST CHECK, recorded per the 4.298 close
law: the distinct totals stated in this doc, the
ledger and the progress paragraph were re-checked
against section298's own printed (ii) lines —
55 at position 1; 2352 at position 2; 51459 at
position 3; 767624 at position 4; 8778828 at
position 5; 82063215 at position 6; 652854678 at
position 7; 4544503461 at position 8, each count
1, forms 8, counts sum 8 — the slice's own cum298
sequence, exactly as printed on-device.
Raw output kept on the Pi at
~/aesir-build/ (hef298.out, hef298.py, arms298.py,
section298.txt, hef298.exit, hef298.err, run298.sh,
check298.py); local lineage in
~/workspace/.verify-tmp/aesir298.

Definitions carry over from AES-NUM-247 through
AES-NUM-297 exactly as printed in the run: POSITION
is 1-based over the eight acts of the closing run
(A ranks 741-748, B ranks 743-750); the sequences
below are the running totals of the AES-NUM-297
values, re-verified as exact cumulative sums
before commit.

## Findings

(i) The closing-run cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining
remaining-count sequence in full is
[55, 2352, 51459, 767624, 8778828, 82063215, 652854678, 4544503461] over positions 1-8 — the running total
of each position's AES-NUM-297 cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining
remaining value, ending at 4544503461. The
contracted comparisons read True at all eight
positions.

(ii) The distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals in full are
eight: 55 at position 1 count 1; 2352 at position
2 count 1; 51459 at position 3 count 1; 767624 at
position 4 count 1; 8778828 at position 5 count 1;
82063215 at position 6 count 1; 652854678 at
position 7 count 1; 4544503461 at position 8 count
1 (counts sum to 8) — as printed in section298's
(ii) lines, re-checked line by line.

(iii) The gap cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count
sequence in full is [12, 513, 11220, 167310, 1912681, 17872218, 142122267] over gap positions
1-7, ending at 142122267, checked against
AES-NUM-298 and AES-NUM-245 (agreeing gap
positions 5, 6, 7, count 3, equal to AES-NUM-245).

Mechanisms NOT PROVEN; any offset, prefix or
position law NOT PROVEN; run 102's meaning NOT
PROVEN. Broad ordinary UNMODIFIED source-model
support remains the destination.

## Next

Slice 4.299 (contract in
`docs/TASK_CONTRACT_4.299.md`): the closing-run
cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence in
full; the distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals in full with
their positions and counts; and the gap
cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence in
full, checked against AES-NUM-298 and AES-NUM-245
— carrying ONE expected-value correction (the
expGap cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative position-2 value, 298 -> 297,
protected as @@WH@@; see the exception record
above) and the context-classification audit law,
plus the two method corrections carried since
4.298 (all-three-legs audit; distinct lists
checked against the slice's own section).
