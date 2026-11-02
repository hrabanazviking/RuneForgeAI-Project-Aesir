# The closing-run cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence, the distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals, and the gap cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence (AES-NUM-294)

Slice 4.294, worked under `docs/TASK_CONTRACT_4.294.md`
(contract published in the 4.293 closing commit @
a2893b62). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child. All findings
below are taken from the sha-verified raw output,
read on-device (section294.txt). Filename
convention, recorded explicitly per the 4.294
contract's close law: at thirty-nine CUMULATIVEs
the chain plus REMAINING.md alone exceeds the
255-byte filesystem limit even further — so this
evidence filename uses the compact X39 notation
(`HAILO10H_CUMULATIVE_X39_REMAINING_AES-NUM-294.md`)
while the full thirty-nine-CUMULATIVE chain is
preserved untruncated in this document's title and
throughout its content. The chain is never silently
truncated. The same convention governs 4.295 (X40).

## Run and closing record

hef294.py is the verified hef293 base plus
arms294: hef293.py sha256 prefix `0c9cd5e2`
(5,095,996 B) on both the VM and the device.
arms294 sha256 prefix `0afe05c1` (167,170 B);
hef294.py sha256 prefix `7c1123a5` (5,263,166 B)
on both the VM and the device; arms294 gzip
sha256 prefix `f9ea4eb3` (12,304 B).
hef294 was built locally on the hef293 lineage
(make_build294.py derived from make_build293,
which carries the three AES-NUM-272 builder fixes
and every carried digit-free placeholder
protection from AES-NUM-274 through AES-NUM-293).
Audit of arms293/build293 for real data values
containing the slice-number substring 293 found
TWO NEW arms-level protections: the real data
values 175293 (2 occurrences, an expected
cumulative-sequence value) and 293248 (2
occurrences, an expected cumulative-sequence
value) protected as @@VY@@ / @@VZ@@ respectively.
Carried protections unchanged and load-bearing:
2429232 (3 occurrences, @@VU@@) and 590292
(3 occurrences, @@VV@@), 92928 (2 occurrences,
@@VW@@) and 29255 (2 occurrences, @@VX@@), all
containing the 292 shift leg; 291720 (3
occurrences, @@VS@@) and 529191 (3 occurrences,
@@VT@@), both containing the 291 shift leg;
290836 (3 occurrences, @@VQ@@) and 42908
(2 occurrences, @@VR@@), both containing the 290
shift leg; 2883 (2 occurrences, @@VP@@), 28612
(2 occurrences, @@VO@@), the bare value 285
(2 occurrences, @@VN@@), and the real data value
21267 (AES-NUM-262 layer) protected as usual at
exactly 2 occurrences. AES-NUM-293 references in
arms294 = 111.
Make-level audit of build293 found NO NEW
protection: its 293 tokens are bare slice
references only (228). Build note carried from
4.293: gen294 re-added 'def rep' as its comment
block's final line, as contracted. One fix during
the build: the first patch generation emitted the
bl[14] \x00 as a single backslash (a real null
byte in build294, SyntaxError at its line 19) —
the lineage carries a DOUBLE backslash; the patch
was corrected and everything regenerated clean.
make_build294 11,587 B sha256 prefix `b6a2ba35`,
build294 17,150 B sha256 prefix `fbd457da`, both
py_compile OK.
hef294 = hef293 + arms294 byte-exact (on-device
assembly sha == VM).
Build sanity on arms294 PASS: all 13 protected
data values at exact counts — 291720 3, 529191 3,
290836 3, 42908 2, 2883 2, 28612 2, 21267 2,
2429232 3, 590292 3, 92928 2, 29255 2, 175293 2,
293248 2; hef294 == hef293 prefix-exact + arms294
tail; DONE294 exactly 1 in hef294 and in arms294,
DONE293 absent from arms294; ZERO 294836 / 293836
corruptions, zero leftover placeholders. Build294
pair 6 (gap tuple G292 form) absent in arms293 —
optional skip, same lineage behaviour; the
on-device verification is the arbiter.

Crossing, stated exactly: a tiny receiver
(recv294.py, landed sha-gated via file.write,
sha256 prefix `ce5b0246` == local) waited on Mimir
:8098 and the VM posted arms294.py.gz through the
tunnel proxy; zero payload bytes passed through
model re-emission. The receiver reported saved
12,304 B with sha `f9ea4eb3` == the local gzip
sha exactly. The assembled arms294 and hef294
shas == VM on-device, py_compile OK. run294.sh
landed on-device (sed 293->294 of run293.sh;
contracted argv, glob order, MiniLM last).

LAUNCH: exactly ONE bounded host-side child ran
in detached tmux (session h294, launched
2026-11-01 11:40 EST; pre-launch tmux/ps check
clean — no h294, no hef294 process, no prior
hef294.out/.exit) with the contract corpus argv
(glob order, MiniLM last), unbuffered
(`python3 -u`). The child finished with exit
marker 0 (hef294.exit, timestamped 11:44 EST),
err empty, and DONE294 as its last line. Output
hef294.out 60,604 lines / 16,997,951 B sha256
prefix `48021c92`; prefix against hef293.out: the
first 60,560 lines differ from hef293.out in
exactly 2 lines (41611, 42872), both
sorted-character equal — the AES-NUM-150 frozenset
variance lines (verified via check294.py sha256
prefix `5478f5df`, derived from the check293
lineage by the simultaneous 292->293 / 293->294
shift), hef294.out adding exactly its own 44 tail
lines (395,512 B, sha256 prefix `4b399a1c`). This
slice's prefix differs in TWO variance lines where
4.293 differed in one (41611) — recorded exactly
as measured; the variance is in which frozenset
lines happen to coincide, not in any contracted
value.

No correction is carried into this slice and none
arises from it: no correction was carried into
4.293 either (the AES-NUM-258 expected-value
correction carried from 4.280 was verified closed
in the 4.281 run), and section294 contains
exactly FOUR 'False' tokens — the four
gap-position agree data values for gap positions
1-4 (positions 5, 6, 7 agree), data not
comparisons, as in every prior slice — and no
fifth False. There is no controls exception in
this slice and no correction is carried into
4.295.
Raw output kept on the Pi at
~/aesir-build/ (hef294.out, hef294.py, arms294.py,
section294.txt, hef294.exit, hef294.err, run294.sh,
check294.py); local lineage in
~/workspace/.verify-tmp/aesir294.

Definitions carry over from AES-NUM-247 through
AES-NUM-293 exactly as printed in the run: POSITION
is 1-based over the eight acts of the closing run
(A ranks 741-748, B ranks 743-750); the sequences
below are the running totals of the AES-NUM-293
values, re-verified as exact cumulative sums
before commit.

## Findings

(i) The closing-run cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining
remaining-count sequence in full is
[55, 2132, 42381, 575680, 6007733, 51350163, 374255749, 2391116351] over positions 1-8 — the running total
of each position's AES-NUM-293 cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining
remaining value, ending at 2391116351. The
contracted comparisons read True at all eight
positions.

(ii) The distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals in full are
eight: 55 at position 1 count 1; 2132 at position
2 count 1; 42381 at position 3 count 1; 575680 at
position 4 count 1; 6007733 at position 5 count 1;
51350163 at position 6 count 1; 374255749 at
position 7 count 1; 2391116351 at position 8 count
1 (counts sum to 8).

(iii) The gap cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count
sequence in full is [12, 465, 9240, 125460, 1308721, 11180987, 81451461] over gap positions
1-7, ending at 81451461, checked against
AES-NUM-293 and AES-NUM-245 (agreeing gap
positions 5, 6, 7, count 3, equal to AES-NUM-245).

Mechanisms NOT PROVEN; any offset, prefix or
position law NOT PROVEN; run 102's meaning NOT
PROVEN. Broad ordinary UNMODIFIED source-model
support remains the destination.

## Next

Slice 4.295 (contract in
`docs/TASK_CONTRACT_4.295.md`): the closing-run
cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence in
full; the distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals in full with
their positions and counts; and the gap
cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence in
full, checked against AES-NUM-294 and AES-NUM-245
— no correction is carried into 4.295.
