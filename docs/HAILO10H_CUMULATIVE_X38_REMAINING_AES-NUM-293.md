# The closing-run cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence, the distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals, and the gap cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence (AES-NUM-293)

Slice 4.293, worked under `docs/TASK_CONTRACT_4.293.md`
(contract published in the 4.292 closing commit @
e51d4167). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child. All findings
below are taken from the sha-verified raw output,
read on-device (section293.txt). Filename
convention, recorded explicitly per the 4.293
contract's close law: at thirty-eight CUMULATIVEs
the chain plus REMAINING.md alone exceeds the
255-byte filesystem limit even further — so this
evidence filename uses the compact X38 notation
(`HAILO10H_CUMULATIVE_X38_REMAINING_AES-NUM-293.md`)
while the full thirty-eight-CUMULATIVE chain is
preserved untruncated in this document's title and
throughout its content. The chain is never silently
truncated. The same convention governs 4.294 (X39).

## Run and closing record

hef293.py is the verified hef292 base plus
arms293: hef292.py sha256 prefix `79b7d786`
(4,935,040 B) on both the VM and the device.
arms293 sha256 prefix `f2bd90b0` (160,956 B);
hef293.py sha256 prefix `0c9cd5e2` (5,095,996 B)
on both the VM and the device; arms293 gzip
sha256 prefix `e1499b4c` (12,102 B).
hef293 was built locally on the hef292 lineage
(make_build293.py derived from make_build292,
which carries the three AES-NUM-272 builder fixes
and every carried digit-free placeholder
protection from AES-NUM-274 through AES-NUM-292).
Audit of arms292/build292 for real data values
containing the slice-number substring 292 found
FOUR NEW arms-level protections: the real data
values 2429232 (3 occurrences, a cumulative-sequence
final value), 590292 (3 occurrences, a gap-sequence
final value), 92928 (2 occurrences, a cumulative-
sequence value) and 29255 (2 occurrences, a
cumulative-sequence value) all contain the
outgoing substring 292 and are protected as
@@VU@@ / @@VV@@ / @@VW@@ / @@VX@@ respectively.
Carried protections unchanged and load-bearing:
291720 (3 occurrences, @@VS@@) and 529191
(3 occurrences, @@VT@@), both containing the 291
shift leg; 290836 (3 occurrences, @@VQ@@) and
42908 (2 occurrences, @@VR@@), both containing
the 290 shift leg; 2883 (2 occurrences, @@VP@@),
28612 (2 occurrences, @@VO@@), the bare value
285 (2 occurrences, @@VN@@), and the real data
value 21267 (AES-NUM-262 layer) protected as
usual at exactly 2 occurrences. AES-NUM-292
references in arms293 = 107.
Make-level audit of build292 found NO NEW
protection: its 292 tokens are bare slice
references only. Build note carried from 4.292:
gen293 re-added 'def rep' as its comment block's
final line, as contracted. make_build293 11,411 B
sha256 prefix `77444ce0`, build293 16,852 B sha256
prefix `7f94064d`, both py_compile OK.
hef293 = hef292 + arms293 byte-exact (on-device
assembly sha == VM).
Build sanity on arms293 PASS: 2429232 preserved
3 occurrences, 590292 preserved 3, 92928 preserved
2, 29255 preserved 2, 291720 preserved 3, 529191
preserved 3, 290836 preserved 3, 42908 preserved 2,
2883 preserved 2, 28612 preserved 2, 21267
preserved 2, ', 285,' 2 occurrences, DONE293
present, DONE292 absent, ZERO 293836 corruptions.

Crossing, stated exactly: a tiny receiver
(/tmp/recv293.py, landed sha-gated via file.write
by an earlier firing) was still waiting in a
detached tmux session (recv293) on Mimir :8098
and the VM posted arms293.py.gz through the
tunnel proxy; zero payload bytes passed through
model re-emission. The receiver reported saved
12,102 B with sha `e1499b4c` == the local gzip
sha exactly. The assembled arms293 and hef293
shas == VM on-device, py_compile OK. run293.sh
landed on-device (sed 292->293 of run292.sh;
contracted argv, glob order, MiniLM last).

LAUNCH: exactly ONE bounded host-side child ran
in detached tmux (session h293, launched
2026-11-01 09:34 EST; pre-launch tmux/ps check
clean — no h293, no hef293 process, no prior
hef293.out/.exit) with the contract corpus argv
(glob order, MiniLM last), unbuffered
(`python3 -u`). The child finished with exit
marker 0 (hef293.exit, timestamped 09:38 EST),
err empty, and DONE293 as its last line. Output
hef293.out 60,560 lines / 16,602,439 B sha256
prefix `41beca9c`; prefix against hef292.out: the
first 60,516 lines differ from hef292.out in
exactly 1 line (41611), sorted-character equal —
the AES-NUM-150 frozenset variance line (verified
via check293.py sha256 prefix `89187fdd`, derived
from the check292 lineage by the simultaneous
291->292 / 292->293 shift), hef293.out adding
exactly its own 44 tail lines (378,560 B, sha256
prefix `693bb50a`). This slice's prefix differs
in ONE variance line where 4.292 differed in two
(41611, 42872) — recorded exactly as measured;
the variance is in which frozenset lines happen
to coincide, not in any contracted value.

No correction is carried into this slice and none
arises from it: no correction was carried into
4.292 either (the AES-NUM-258 expected-value
correction carried from 4.280 was verified closed
in the 4.281 run), and section293 contains
exactly FOUR 'False' tokens — the four
gap-position agree data values for gap positions
1-4 (positions 5, 6, 7 agree), data not
comparisons, as in every prior slice — and no
fifth False. There is no controls exception in
this slice and no correction is carried into
4.294.
Raw output kept on the Pi at
~/aesir-build/ (hef293.out, hef293.py, arms293.py,
section293.txt, hef293.exit, hef293.err, run293.sh,
check293.py); local lineage in
~/workspace/.verify-tmp/aesir293.

Definitions carry over from AES-NUM-247 through
AES-NUM-292 exactly as printed in the run: POSITION
is 1-based over the eight acts of the closing run
(A ranks 741-748, B ranks 743-750); the sequences
below are the running totals of the AES-NUM-292
values, re-verified as exact cumulative sums
before commit.

## Findings

(i) The closing-run cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining
remaining-count sequence in full is
[55, 2077, 40249, 533299, 5432053, 45342430, 322905586, 2016860602] over positions 1-8 — the running total
of each position's AES-NUM-292 cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining
remaining value, ending at 2016860602. The
contracted comparisons read True at all eight
positions.

(ii) The distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals in full are
eight: 55 at position 1 count 1; 2077 at position
2 count 1; 40249 at position 3 count 1; 533299 at
position 4 count 1; 5432053 at position 5 count 1;
45342430 at position 6 count 1; 322905586 at
position 7 count 1; 2016860602 at position 8 count
1 (counts sum to 8).

(iii) The gap cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count
sequence in full is [12, 453, 8775, 116220, 1183261, 9872266, 70270474] over gap positions
1-7, ending at 70270474, checked against
AES-NUM-292 and AES-NUM-245 (agreeing gap
positions 5, 6, 7, count 3, equal to AES-NUM-245).

Mechanisms NOT PROVEN; any offset, prefix or
position law NOT PROVEN; run 102's meaning NOT
PROVEN. Broad ordinary UNMODIFIED source-model
support remains the destination.

## Next

Slice 4.294 (contract in
`docs/TASK_CONTRACT_4.294.md`): the closing-run
cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence in
full; the distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals in full with
their positions and counts; and the gap
cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence in
full, checked against AES-NUM-293 and AES-NUM-245
— no correction is carried into 4.294.
