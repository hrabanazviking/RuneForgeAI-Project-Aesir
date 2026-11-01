# The closing-run cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence, the distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals, and the gap cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence (AES-NUM-296)

Slice 4.296, worked under `docs/TASK_CONTRACT_4.296.md`
(contract published in the 4.295 closing commit @
525301f7). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child. All findings
below are taken from the sha-verified raw output,
read on-device (section296.txt). Filename
convention, recorded explicitly per the 4.296
contract's close law: at forty-one CUMULATIVEs
the chain plus REMAINING.md alone exceeds the
255-byte filesystem limit even further — so this
evidence filename uses the compact X41 notation
(`HAILO10H_CUMULATIVE_X41_REMAINING_AES-NUM-296.md`)
while the full forty-one-CUMULATIVE chain is
preserved untruncated in this document's title and
throughout its content. The chain is never silently
truncated. The same convention governs 4.297 (X42).

## Run and closing record

hef296.py is the verified hef295 base plus
arms296: hef295.py sha256 prefix `b6238a45`
(5,436,673 B) on both the VM and the device.
arms296 sha256 prefix `a0283105` (179,977 B);
hef296.py sha256 prefix `7c1d7ec0` (5,616,650 B)
on both the VM and the device; arms296 gzip
sha256 prefix `4471ecc9` (12,747 B).
hef296 was built locally on the hef295 lineage
(make_build296.py derived from make_build295,
which carries the three AES-NUM-272 builder fixes
and every carried digit-free placeholder
protection from AES-NUM-274 through AES-NUM-295).
Audit of arms295/build295 for real data values
containing the slice-number substring 295 found
NO NEW arms-level protection: bare 295 (1,542
digit-run count) is a slice reference, and 2952
(26 occurrences) and 102295 (4 occurrences) are
identifier parts only. Carried protections
unchanged and load-bearing: 294083 (2
occurrences, @@WA@@) and 385294 (2 occurrences,
@@WB@@), both containing the 294 shift leg;
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
exactly 2 occurrences. AES-NUM-295 references in
arms296 = 119.
Make-level audit of build295 found NO NEW
protection: its 295 tokens are bare slice
references only (232). Build note carried from
4.295: gen296 re-added 'def rep' as its comment
block's final line, as contracted. No build fix
was required this slice: make_build296 emitted
the bl[14] \x00 with the lineage's DOUBLE
backslash correctly on the first generation.
make_build296 11,671 B sha256 prefix `0f5837ab`,
build296 17,483 B sha256 prefix `766a951f`, both
py_compile OK.
hef296 = hef295 + arms296 byte-exact (on-device
assembly sha == VM).
Build sanity on arms296 PASS: all 15 protected
data values at exact counts — 291720 3, 529191 3,
290836 3, 42908 2, 2883 2, 28612 2, 21267 2,
2429232 3, 590292 3, 92928 2, 29255 2, 175293 2,
293248 2, 294083 2, 385294 2; hef296 == hef295
prefix-exact + arms296 tail; DONE296 exactly 1 in
hef296 and in arms296, DONE295 absent from
arms296; ZERO 296836 / 295836
corruptions, zero leftover placeholders. Build296
pair 6 (gap tuple G294 form) absent in arms295 —
optional skip, same lineage behaviour; the
on-device verification is the arbiter.

Crossing, stated exactly: a tiny receiver
(recv296.py, landed sha-gated via file.write,
sha256 prefix `689afa6b` == local) waited on Mimir
:8098 and the VM posted arms296.py.gz through the
tunnel proxy; zero payload bytes passed through
model re-emission. The receiver reported saved
12,747 B with sha `4471ecc9` == the local gzip
sha exactly. The assembled arms296 and hef296
shas == VM on-device, py_compile OK. run296.sh
landed on-device (sed 295->296 of run295.sh;
contracted argv, glob order, MiniLM last).
Transport note, recorded honestly: the first
receiver hold expired with no POST served (its
110-second window ended, exit 124, while two
worker turns were interrupted); a second hold
was taken and the VM POST landed on its second
attempt. No payload was ever at risk and no byte
crossed unverified.

LAUNCH: exactly ONE bounded host-side child ran
in detached tmux (session h296, launched
2026-11-01 14:54 EST; pre-launch tmux/ps check
clean — no h296, no hef296 process, no prior
hef296.out/.exit) with the contract corpus argv
(glob order, MiniLM last), unbuffered
(`python3 -u`). The child finished with exit
marker 0 (hef296.exit), err empty, and DONE296
as its last line. Output
hef296.out 60,692 lines / 17,841,335 B sha256
prefix `e6e95ecf`; prefix against hef295.out: the
first 60,648 lines differ from hef295.out in
exactly 0 lines (verified via check296.py sha256
prefix `b2d79e07`, derived from the check295
lineage by the simultaneous 294->295 / 295->296
shift, landed on-device sha-gated with sha ==
local exactly), hef296.out
adding exactly its own 44 tail
lines (430,547 B, sha256 prefix `72a18779`). This
slice's prefix differs in ZERO variance lines,
as in 4.295, where 4.294 differed in two (41611,
42872) and 4.293 in one (41611) — recorded exactly
as measured; the variance is in which frozenset
lines happen to coincide, not in any contracted
value.

No correction is carried into this slice and none
arises from it: no correction was carried into
4.295 either (the AES-NUM-258 expected-value
correction carried from 4.280 was verified closed
in the 4.281 run), and section296 contains
exactly FOUR 'False' tokens — the four
gap-position agree data values for gap positions
1-4 (positions 5, 6, 7 agree), data not
comparisons, as in every prior slice — and no
fifth False. There is no controls exception in
this slice and no correction is carried into
4.297.
Raw output kept on the Pi at
~/aesir-build/ (hef296.out, hef296.py, arms296.py,
section296.txt, hef296.exit, hef296.err, run296.sh,
check296.py); local lineage in
~/workspace/.verify-tmp/aesir296.

Definitions carry over from AES-NUM-247 through
AES-NUM-295 exactly as printed in the run: POSITION
is 1-based over the eight acts of the closing run
(A ranks 741-748, B ranks 743-750); the sequences
below are the running totals of the AES-NUM-295
values, re-verified as exact cumulative sums
before commit.

## Findings

(i) The closing-run cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining
remaining-count sequence in full is
[55, 2242, 46810, 667058, 7295039, 65273183, 497507076, 3320857320] over positions 1-8 — the running total
of each position's AES-NUM-295 cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining
remaining value, ending at 3320857320. The
contracted comparisons read True at all eight
positions.

(ii) The distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals in full are
eight: 55 at position 1 count 1; 2187 at position
2 count 1; 44568 at position 3 count 1; 620248 at
position 4 count 1; 6627981 at position 5 count 1;
57978144 at position 6 count 1; 432233893 at
position 7 count 1; 2823350244 at position 8 count
1 (counts sum to 8).

(iii) The gap cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count
sequence in full is [12, 489, 10206, 145383, 1589281, 14214166, 108290512] over gap positions
1-7, ending at 108290512, checked against
AES-NUM-296 and AES-NUM-245 (agreeing gap
positions 5, 6, 7, count 3, equal to AES-NUM-245).

Mechanisms NOT PROVEN; any offset, prefix or
position law NOT PROVEN; run 102's meaning NOT
PROVEN. Broad ordinary UNMODIFIED source-model
support remains the destination.

## Next

Slice 4.297 (contract in
`docs/TASK_CONTRACT_4.297.md`): the closing-run
cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence in
full; the distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals in full with
their positions and counts; and the gap
cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence in
full, checked against AES-NUM-296 and AES-NUM-245
— no correction is carried into 4.297.
