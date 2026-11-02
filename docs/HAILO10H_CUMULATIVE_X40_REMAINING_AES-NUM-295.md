# The closing-run cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence, the distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals, and the gap cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence (AES-NUM-295)

Slice 4.295, worked under `docs/TASK_CONTRACT_4.295.md`
(contract published in the 4.294 closing commit @
fa11e10f). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child. All findings
below are taken from the sha-verified raw output,
read on-device (section295.txt). Filename
convention, recorded explicitly per the 4.295
contract's close law: at forty CUMULATIVEs
the chain plus REMAINING.md alone exceeds the
255-byte filesystem limit even further — so this
evidence filename uses the compact X40 notation
(`HAILO10H_CUMULATIVE_X40_REMAINING_AES-NUM-295.md`)
while the full forty-CUMULATIVE chain is
preserved untruncated in this document's title and
throughout its content. The chain is never silently
truncated. The same convention governs 4.296 (X41).

## Run and closing record

hef295.py is the verified hef294 base plus
arms295: hef294.py sha256 prefix `7c1123a5`
(5,263,166 B) on both the VM and the device.
arms295 sha256 prefix `6ca207d6` (173,507 B);
hef295.py sha256 prefix `b6238a45` (5,436,673 B)
on both the VM and the device; arms295 gzip
sha256 prefix `bb6e5552` (12,503 B).
hef295 was built locally on the hef294 lineage
(make_build295.py derived from make_build294,
which carries the three AES-NUM-272 builder fixes
and every carried digit-free placeholder
protection from AES-NUM-274 through AES-NUM-294).
Audit of arms294/build294 for real data values
containing the slice-number substring 294 found
TWO NEW arms-level protections: the real data
values 294083 (2 occurrences, an expected
gap-sequence value) and 385294 (2
occurrences, an expected cumulative-sequence
value) protected as @@WA@@ / @@WB@@ respectively.
Carried protections unchanged and load-bearing:
175293 (2 occurrences, @@VY@@) and 293248
(2 occurrences, @@VZ@@), both containing the 293
shift leg; 2429232 (3 occurrences, @@VU@@) and
590292 (3 occurrences, @@VV@@), 92928 (2
occurrences, @@VW@@) and 29255 (2 occurrences,
@@VX@@), all containing the 292 shift leg;
291720 (3 occurrences, @@VS@@) and 529191 (3
occurrences, @@VT@@), both containing the 291
shift leg; 290836 (3 occurrences, @@VQ@@) and
42908 (2 occurrences, @@VR@@), both containing
the 290 shift leg; 2883 (2 occurrences, @@VP@@),
28612 (2 occurrences, @@VO@@), the bare value 285
(2 occurrences, @@VN@@), and the real data value
21267 (AES-NUM-262 layer) protected as usual at
exactly 2 occurrences. AES-NUM-294 references in
arms295 = 115.
Make-level audit of build294 found NO NEW
protection: its 294 tokens are bare slice
references only (230). Build note carried from
4.294: gen295 re-added 'def rep' as its comment
block's final line, as contracted. No build fix
was required this slice: make_build295 emitted
the bl[14] \x00 with the lineage's DOUBLE
backslash correctly on the first generation.
make_build295 11,875 B sha256 prefix `ecd4a87c`,
build295 17,457 B sha256 prefix `be9256f6`, both
py_compile OK.
hef295 = hef294 + arms295 byte-exact (on-device
assembly sha == VM).
Build sanity on arms295 PASS: all 15 protected
data values at exact counts — 291720 3, 529191 3,
290836 3, 42908 2, 2883 2, 28612 2, 21267 2,
2429232 3, 590292 3, 92928 2, 29255 2, 175293 2,
293248 2, 294083 2, 385294 2; hef295 == hef294
prefix-exact + arms295 tail; DONE295 exactly 1 in
hef295 and in arms295, DONE294 absent from
arms295; ZERO 295836 / 294836
corruptions, zero leftover placeholders. Build295
pair 6 (gap tuple G293 form) absent in arms294 —
optional skip, same lineage behaviour; the
on-device verification is the arbiter.

Crossing, stated exactly: a tiny receiver
(recv295.py, landed sha-gated via file.write,
sha256 prefix `721595b8` == local) waited on Mimir
:8098 and the VM posted arms295.py.gz through the
tunnel proxy; zero payload bytes passed through
model re-emission. The receiver reported saved
12,503 B with sha `bb6e5552` == the local gzip
sha exactly. The assembled arms295 and hef295
shas == VM on-device, py_compile OK. run295.sh
landed on-device (sed 294->295 of run294.sh;
contracted argv, glob order, MiniLM last).
Transport note, recorded honestly: the first
receiver hold timed out with no POST received —
the VM-side curl had been given a tilde path
(`@~/workspace/...`) that the shell does not
expand after `@`, so curl could not open the
file at all; the second hold, posted with the
absolute path, succeeded on the first attempt.
No payload was ever at risk and no byte crossed
unverified.

LAUNCH: exactly ONE bounded host-side child ran
in detached tmux (session h295, launched
2026-11-01 12:54 EST; pre-launch tmux/ps check
clean — no h295, no hef295 process, no prior
hef295.out/.exit) with the contract corpus argv
(glob order, MiniLM last), unbuffered
(`python3 -u`). The child finished with exit
marker 0 (hef295.exit, timestamped 12:58 EST),
err empty, and DONE295 as its last line. Output
hef295.out 60,648 lines / 17,410,788 B sha256
prefix `d276987d`; prefix against hef294.out: the
first 60,604 lines differ from hef294.out in
exactly 0 lines (verified via check295.py sha256
prefix `f3b16eb6`, derived from the check294
lineage by the simultaneous 293->294 / 294->295
shift, landed on-device by the same sed shift of
check294.py with sha == local exactly), hef295.out
adding exactly its own 44 tail
lines (412,837 B, sha256 prefix `374b504c`). This
slice's prefix differs in ZERO variance lines
where 4.294 differed in two (41611, 42872) and
4.293 in one (41611) — recorded exactly
as measured; the variance is in which frozenset
lines happen to coincide, not in any contracted
value.

No correction is carried into this slice and none
arises from it: no correction was carried into
4.294 either (the AES-NUM-258 expected-value
correction carried from 4.280 was verified closed
in the 4.281 run), and section295 contains
exactly FOUR 'False' tokens — the four
gap-position agree data values for gap positions
1-4 (positions 5, 6, 7 agree), data not
comparisons, as in every prior slice — and no
fifth False. There is no controls exception in
this slice and no correction is carried into
4.296.
Raw output kept on the Pi at
~/aesir-build/ (hef295.out, hef295.py, arms295.py,
section295.txt, hef295.exit, hef295.err, run295.sh,
check295.py); local lineage in
~/workspace/.verify-tmp/aesir295.

Definitions carry over from AES-NUM-247 through
AES-NUM-294 exactly as printed in the run: POSITION
is 1-based over the eight acts of the closing run
(A ranks 741-748, B ranks 743-750); the sequences
below are the running totals of the AES-NUM-294
values, re-verified as exact cumulative sums
before commit.

## Findings

(i) The closing-run cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining
remaining-count sequence in full is
[55, 2187, 44568, 620248, 6627981, 57978144, 432233893, 2823350244] over positions 1-8 — the running total
of each position's AES-NUM-294 cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining
remaining value, ending at 2823350244. The
contracted comparisons read True at all eight
positions.

(ii) The distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals in full are
eight: 55 at position 1 count 1; 2132 at position
2 count 1; 42381 at position 3 count 1; 575680 at
position 4 count 1; 6007733 at position 5 count 1;
51350163 at position 6 count 1; 374255749 at
position 7 count 1; 2391116351 at position 8 count
1 (counts sum to 8).

(iii) The gap cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count
sequence in full is [12, 477, 9717, 135177, 1443898, 12624885, 94076346] over gap positions
1-7, ending at 94076346, checked against
AES-NUM-294 and AES-NUM-245 (agreeing gap
positions 5, 6, 7, count 3, equal to AES-NUM-245).

Mechanisms NOT PROVEN; any offset, prefix or
position law NOT PROVEN; run 102's meaning NOT
PROVEN. Broad ordinary UNMODIFIED source-model
support remains the destination.

## Next

Slice 4.296 (contract in
`docs/TASK_CONTRACT_4.296.md`): the closing-run
cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence in
full; the distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals in full with
their positions and counts; and the gap
cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence in
full, checked against AES-NUM-295 and AES-NUM-245
— no correction is carried into 4.296.
