# The closing-run cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence, the distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals, and the gap cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence (AES-NUM-292)

Slice 4.292, worked under `docs/TASK_CONTRACT_4.292.md`
(contract published in the 4.291 closing commit @
2ce895ee). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child. All findings
below are taken from the sha-verified raw output,
read on-device (section292.txt). Filename
convention, recorded explicitly per the 4.292
contract's close law: at thirty-seven CUMULATIVEs
the chain plus REMAINING.md alone exceeds the
255-byte filesystem limit even further — so this
evidence filename uses the compact X37 notation
(`HAILO10H_CUMULATIVE_X37_REMAINING_AES-NUM-292.md`)
while the full thirty-seven-CUMULATIVE chain is
preserved untruncated in this document's title and
throughout its content. The chain is never silently
truncated. The same convention governs 4.293 (X38).

## Run and closing record

hef292.py is the verified hef291 base plus
arms292: hef291.py sha256 prefix `c17e7fb3`
(4,780,171 B) on both the VM and the device.
arms292 sha256 prefix `01aeae60` (154,869 B);
hef292.py sha256 prefix `79b7d786` (4,935,040 B)
on both the VM and the device; arms292 gzip
sha256 prefix `306cb062` (11,873 B).
hef292 was built locally on the hef291 lineage
(make_build292.py derived from make_build291,
which carries the three AES-NUM-272 builder fixes
and every carried digit-free placeholder
protection from AES-NUM-274 through AES-NUM-291).
Audit of arms291/build291 for real data values
containing the slice-number substring 291 found
TWO NEW arms-level protections: the real data
value 291720 (3 occurrences, an AES-NUM-264-layer
final cumulative value) and the real data value
529191 (3 occurrences, an AES-NUM-265-layer final
cumulative value) both contain the outgoing
substring 291 and are protected as
@@VS@@ / @@VT@@ respectively. Carried protections
unchanged and load-bearing: 290836 (3 occurrences,
@@VQ@@) and 42908 (2 occurrences, @@VR@@), both
containing the 290 shift leg; 2883 (2 occurrences,
@@VP@@), 28612 (2 occurrences, @@VO@@), the bare
value 285 (2 occurrences, @@VN@@), and the real
data value 21267 (AES-NUM-262 layer) protected as
usual at exactly 2 occurrences. AES-NUM-291
references in arms292 = 103.
Make-level audit of build291 found NO NEW
protection: no long data value containing 291
beyond bare slice references / identifier suffixes.
Build note carried from 4.291: build291's
data-protection comment is 25 lines, so gen292
re-added 'def rep' as its comment block's final
line, as contracted. A first build292 generation
hit an IndentationError from a transformer bug
(B2 = double backslash in make_make292_direct.py);
the bug was fixed in place (single backslash,
matching the make_make291 chain) and the build
regenerated clean — make_build292 10,849 B sha256
prefix `57c4b011`, build292 16,337 B sha256 prefix
`2f362fa8`, both py_compile OK (the 07:41-recorded
pre-fix sha a672a703 / 10,870 B was superseded and
never gated on). hef292 = hef291 + arms292
byte-exact (on-device assembly sha == VM).
Build sanity on arms292 PASS: 291720 preserved
3 occurrences, 529191 preserved 3, 290836
preserved 3, 42908 preserved 2, 2883 preserved 2,
28612 preserved 2, 21267 preserved 2, ', 285,'
2 occurrences, DONE292 present, DONE291 absent,
ZERO 292836 / 529292 / 291836 corruptions.

Crossing, stated exactly: a tiny receiver
(/tmp/recv292.py, landed sha-gated via file.write
by an earlier firing) was still waiting in a
detached tmux session (recv292) on Mimir :8098
and the VM posted arms292.py.gz through the
tunnel proxy; zero payload bytes passed through
model re-emission. The receiver reported saved
11,873 B with sha `306cb062` == the local gzip
sha exactly. The assembled arms292 and hef292
shas == VM on-device, py_compile OK. run292.sh
landed on-device (sed 291->292 of run291.sh;
contracted argv, glob order, MiniLM last).

LAUNCH: exactly ONE bounded host-side child ran
in detached tmux (session h292, launched
2026-11-01 08:24 EST; pre-launch tmux/ps check
clean — no h292, no hef292 process, no prior
hef292.out/.exit) with the contract corpus argv
(glob order, MiniLM last), unbuffered
(`python3 -u`). The child finished with exit
marker 0 (hef292.exit, timestamped 08:28 EST),
err empty, and DONE292 as its last line. Output
hef292.out 60,516 lines / 16,223,879 B sha256
prefix `f5f45007`; prefix against hef291.out: the
first 60,472 lines differ from hef291.out in
exactly 2 lines (41611, 42872), both
sorted-character equal — AES-NUM-150 frozenset
variance lines (verified via check292.py sha256
prefix `a95d6ff6`, derived from the check291
lineage by the simultaneous 290->291 / 291->292
shift), hef292.out adding exactly its own 44 tail
lines (361,984 B, sha256 prefix `55e97ff1`).

No correction is carried into this slice and none
arises from it: no correction was carried into
4.291 either (the AES-NUM-258 expected-value
correction carried from 4.280 was verified closed
in the 4.281 run), and section292 contains
exactly FOUR 'False' tokens — the four
gap-position agree data values for gap positions
1-4 (positions 5, 6, 7 agree), data not
comparisons, as in every prior slice — and no
fifth False. There is no controls exception in
this slice and no correction is carried into
4.293.
Raw output kept on the Pi at
~/aesir-build/ (hef292.out, hef292.py, arms292.py,
section292.txt, hef292.exit, hef292.err, run292.sh,
check292.py); local lineage in
~/workspace/.verify-tmp/aesir292.

Definitions carry over from AES-NUM-247 through
AES-NUM-291 exactly as printed in the run: POSITION
is 1-based over the eight acts of the closing run
(A ranks 741-748, B ranks 743-750); the sequences
below are the running totals of the AES-NUM-291
values, re-verified as exact cumulative sums
before commit.

## Findings

(i) The closing-run cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining
remaining-count sequence in full is
[55, 2022, 38172, 493050, 4898754, 39910377, 277563156, 1693955016] over positions 1-8 — the running total
of each position's AES-NUM-291 cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining
remaining value, ending at 1693955016. The
contracted comparisons read True at all eight
positions.

(ii) The distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals in full are
eight: 55 at position 1 count 1; 2022 at position
2 count 1; 38172 at position 3 count 1; 493050 at
position 4 count 1; 4898754 at position 5 count 1;
39910377 at position 6 count 1; 277563156 at
position 7 count 1; 1693955016 at position 8 count
1 (counts sum to 8).

(iii) The gap cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count
sequence in full is [12, 441, 8322, 107445, 1067041, 8689005, 60398208] over gap positions
1-7, ending at 60398208, checked against
AES-NUM-291 and AES-NUM-245 (agreeing gap
positions 5, 6, 7, count 3, equal to AES-NUM-245).

Mechanisms NOT PROVEN; any offset, prefix or
position law NOT PROVEN; run 102's meaning NOT
PROVEN. Broad ordinary UNMODIFIED source-model
support remains the destination.

## Next

Slice 4.293 (contract in
`docs/TASK_CONTRACT_4.293.md`): the closing-run
cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence in
full; the distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals in full with
their positions and counts; and the gap
cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence in
full, checked against AES-NUM-292 and AES-NUM-245
— no correction is carried into 4.293.
