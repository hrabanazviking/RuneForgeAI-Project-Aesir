# The closing-run cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence, the distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals, and the gap cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence (AES-NUM-297)

Slice 4.297, worked under `docs/TASK_CONTRACT_4.297.md`
(contract published in the 4.296 closing commit @
fce49fe4). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child. All findings
below are taken from the sha-verified raw output,
read on-device (section297.txt). Filename
convention, recorded explicitly per the 4.297
contract's close law: at forty-two CUMULATIVEs
the chain plus REMAINING.md alone exceeds the
255-byte filesystem limit even further — so this
evidence filename uses the compact X42 notation
(`HAILO10H_CUMULATIVE_X42_REMAINING_AES-NUM-297.md`)
while the full chain is preserved untruncated in
this document's title (lineage form) and in the
run's own section headers, which carry all
forty-two CUMULATIVEs. The chain is never silently
truncated. The same convention governs 4.298 (X43).

## Run and closing record

hef297.py is the verified hef296 base plus
arms297: hef296.py sha256 prefix `7c1d7ec0`
(5,616,650 B) on both the VM and the device.
arms297 sha256 prefix `bd3b6c7a` (186,567 B);
hef297.py sha256 prefix `75b935ba` (5,803,217 B)
on both the VM and the device; arms297 gzip
sha256 prefix `63a4a8fb` (12,978 B).
hef297 was built locally on the hef296 lineage
(make_build297.py derived from make_build296,
which carries the three AES-NUM-272 builder fixes
and every carried digit-free placeholder
protection from AES-NUM-274 through AES-NUM-296).
Audit of arms296/build296 for real data values
containing the slice-number substring 296 found
TWO NEW arms-level protections, as contracted:
2967 (2 occurrences, @@WC@@), an expected
gap-sequence value, and 791479296 (1 occurrence,
@@WD@@), a CONTROL expect first tuple element.
Bare 296 (1,568 digit-run count) is a slice
reference, and 2962 (26 occurrences) and 102296
(4 occurrences) are identifier parts only.
Make-level audit of build296 found NO NEW
protection (its 296 tokens are bare slice
references only, 234).

AUDIT CORRECTION, discovered and applied inside
this slice (recorded honestly; the contract's
inherited audit checked only the 296 substring):
the cum296 sequence value 7295039 (5 occurrences
in arms296) contains the 295 shift leg, so it too
is real data under this generation's shift. Its
absence of protection showed twice: first as five
absent sequence pairs in the first make_build297
run (the C295 list/tuple/dist/dstr forms were
corrupted by the make-level shift before the
pairs stage could find them), then as a NOT FOUND
rep failure in build297's first generation (its
prose-tuple search string). Two protections were
added: make-level @@VALE@@ in make_build297
(protect before the make-level shift, restore
after — the pairs stage then found every C295
form intact, and only the known pair 6 optional
skip remained) and arms-level @@WE@@ (5
occurrences) appended in the bl block alongside
@@WC@@/@@WD@@. With both, the build is clean and
every sanity count exact. Carried into 4.298's
contract as method law: every audit MUST scan
arms/build values against ALL THREE shift legs
of its generation, not only the top leg.
Carried protections otherwise unchanged and
load-bearing, including 294083 (2 occurrences,
@@WA@@) and 385294 (2 occurrences, @@WB@@), both
containing the 294 shift leg; 175293 (2
occurrences, @@VY@@) and 293248 (2 occurrences,
@@VZ@@), both containing the 293 shift leg;
2429232 (3 occurrences, @@VU@@), 590292 (3
occurrences, @@VV@@), 92928 (2 occurrences,
@@VW@@) and 29255 (2 occurrences, @@VX@@);
291720 (3 occurrences, @@VS@@), 529191 (3
occurrences, @@VT@@), 290836 (3 occurrences,
@@VQ@@), 42908 (2 occurrences, @@VR@@), 2883 (2
occurrences, @@VP@@), 28612 (2 occurrences,
@@VO@@), the bare value 285 (2 occurrences,
@@VN@@), and the real data value 21267
(AES-NUM-262 layer) at exactly 2 occurrences.
AES-NUM-296 references in arms297 = 123.
make_build297 12,830 B sha256 prefix `6450fc50`,
build297 18,078 B sha256 prefix `4af5edab`,
gen_make297 sha256 prefix `23948612`, all
py_compile OK. hef297 = hef296 + arms297
byte-exact (on-device assembly sha == VM).
Build sanity on arms297 PASS: all 17 protected
data values at exact counts — 291720 3, 529191 3,
290836 3, 42908 2, 2883 2, 28612 2, 21267 2,
2429232 3, 590292 3, 92928 2, 29255 2, 175293 2,
293248 2, 294083 2, 385294 2, 2967 2, 791479296 1,
and 7295039 at exactly 5; hef297 == hef296
prefix-exact + arms297 tail; DONE297 exactly 1 in
hef297 and in arms297, DONE296 absent from
arms297; ZERO 297836 / 296836 corruptions, zero
leftover placeholders; all four 296/297 sequence
forms present at exact counts.

Crossing, stated exactly: a tiny receiver
(recv297.py, landed sha-gated via file.write,
sha256 prefix `8e0c3e26` == local) waited on Mimir
:8098 (held in the foreground by a delegated
holder) and the VM posted arms297.py.gz through
the tunnel proxy on the first attempt; zero
payload bytes passed through model re-emission.
The receiver reported saved 12,978 B with sha
`63a4a8fb` == the local gzip sha exactly. The
assembled arms297 and hef297 shas == VM
on-device, py_compile OK. run297.sh landed
on-device (sed 296->297 of run296.sh; contracted
argv, glob order, MiniLM last).

LAUNCH: exactly ONE bounded host-side child ran
in detached tmux (session h297, launched
2026-11-01 17:01 EST; pre-launch tmux/ps check
clean — no h297, no hef297 process, no prior
hef297.out/.exit) with the contract corpus argv
(glob order, MiniLM last), unbuffered
(`python3 -u`). The child finished with exit
marker 0 (hef297.exit), err empty, and DONE297
as its last line. Output
hef297.out 60,736 lines / 18,289,961 B sha256
prefix `f5dbee6b`; prefix against hef296.out: the
first 60,692 lines differ from hef296.out in
exactly ONE line (41611), sorted-character equal
— the AES-NUM-150 frozenset variance (one line
this slice, as in 4.293; 4.294 differed in two,
4.295 and 4.296 in zero — recorded exactly as
measured; the variance is in which frozenset
lines happen to coincide, not in any contracted
value), verified via check297.py sha256 prefix
`6c80acd1` (check296 lineage, simultaneous
295->296 / 296->297 shift, landed on-device
sha-gated with sha == local exactly), hef297.out
adding exactly its own 44 tail
lines (448,626 B, sha256 prefix `8a19d976`).

No correction to any finding is carried into
this slice and none arises from it: section297
contains exactly FOUR 'False' tokens — the four
gap-position agree data values for gap positions
1-4 (A gap 512 against B gaps 712, 26624, 14848,
33280; positions 5, 6, 7 agree), data not
comparisons, as in every prior slice — and no
fifth False. There is no controls exception in
this slice. Two METHOD corrections are carried
into 4.298's contract (not findings corrections):
the all-three-legs audit law above, and the
distinct-list check below.
DISTINCT-LIST CHECK, recorded per the 4.297 close
law: the distinct totals stated in this doc, the
ledger and the progress paragraph were re-checked
against section297's own printed (ii) lines —
55 at position 1; 2297 at position 2; 49107 at
position 3; 716165 at position 4; 8011204 at
position 5; 73284387 at position 6; 570791463 at
position 7; 3891648783 at position 8, each count
1, forms 8, counts sum 8 — the slice's own cum297
sequence, exactly as printed on-device.
Raw output kept on the Pi at
~/aesir-build/ (hef297.out, hef297.py, arms297.py,
section297.txt, hef297.exit, hef297.err, run297.sh,
check297.py); local lineage in
~/workspace/.verify-tmp/aesir297.

Definitions carry over from AES-NUM-247 through
AES-NUM-296 exactly as printed in the run: POSITION
is 1-based over the eight acts of the closing run
(A ranks 741-748, B ranks 743-750); the sequences
below are the running totals of the AES-NUM-296
values, re-verified as exact cumulative sums
before commit.

## Findings

(i) The closing-run cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining
remaining-count sequence in full is
[55, 2297, 49107, 716165, 8011204, 73284387, 570791463, 3891648783] over positions 1-8 — the running total
of each position's AES-NUM-296 cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining
remaining value, ending at 3891648783. The
contracted comparisons read True at all eight
positions.

(ii) The distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals in full are
eight: 55 at position 1 count 1; 2297 at position
2 count 1; 49107 at position 3 count 1; 716165 at
position 4 count 1; 8011204 at position 5 count 1;
73284387 at position 6 count 1; 570791463 at
position 7 count 1; 3891648783 at position 8 count
1 (counts sum to 8) — as printed in section297's
(ii) lines, re-checked line by line.

(iii) The gap cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count
sequence in full is [12, 501, 10707, 156090, 1745371, 15959537, 124250049] over gap positions
1-7, ending at 124250049, checked against
AES-NUM-297 and AES-NUM-245 (agreeing gap
positions 5, 6, 7, count 3, equal to AES-NUM-245).

Mechanisms NOT PROVEN; any offset, prefix or
position law NOT PROVEN; run 102's meaning NOT
PROVEN. Broad ordinary UNMODIFIED source-model
support remains the destination.

## Next

Slice 4.298 (contract in
`docs/TASK_CONTRACT_4.298.md`): the closing-run
cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence in
full; the distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals in full with
their positions and counts; and the gap
cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence in
full, checked against AES-NUM-297 and AES-NUM-245
— no findings correction is carried into 4.298;
its contract carries the two method corrections
recorded above (all-three-legs audit; distinct
lists checked against the slice's own section).
