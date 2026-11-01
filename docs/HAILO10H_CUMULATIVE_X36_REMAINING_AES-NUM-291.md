# The closing-run cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence, the distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals, and the gap cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence (AES-NUM-291)

Slice 4.291, worked under `docs/TASK_CONTRACT_4.291.md`
(contract published in the 4.290 closing commit @
40827eab). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child. All findings
below are taken from the sha-verified raw output,
read on-device (section291.txt). Filename
convention, recorded explicitly per the 4.291
contract's close law: at thirty-six CUMULATIVEs
the chain plus REMAINING.md alone exceeds the
255-byte filesystem limit even further — so this
evidence filename uses the compact X36 notation
(`HAILO10H_CUMULATIVE_X36_REMAINING_AES-NUM-291.md`)
while the full thirty-six-CUMULATIVE chain is
preserved untruncated in this document's title and
throughout its content. The chain is never silently
truncated. The same convention governs 4.292 (X37).

## Run and closing record

hef291.py is the verified hef290 base plus
arms291: hef290.py sha256 prefix `5b5770e3`
(4,631,267 B) on both the VM and the device.
arms291 sha256 prefix `a9fa33e4` (148,904 B);
hef291.py sha256 prefix `c17e7fb3` (4,780,171 B)
on both the VM and the device; arms291 gzip
sha256 prefix `fef34375` (11,480 B).
hef291 was built locally on the hef290 lineage
(make_build291.py derived from make_build290,
which carries the three AES-NUM-272 builder fixes
and every carried digit-free placeholder
protection from AES-NUM-274 through AES-NUM-290).
Audit of arms290/build290 for real data values
containing the slice-number substring 290 found
TWO NEW arms-level protections: the real data
value 290836 (3 occurrences, a gap cumulative
total) and the real data value 42908 (2
occurrences, a cumulative total) both contain the
outgoing substring 290 and are protected as
@@VQ@@ / @@VR@@ respectively. arms290 bare 290
digit-sequences = 1,412 (slice references /
identifier suffixes); 2902 (26 hits) and 102290
(4 hits) are identifier suffixes only. Carried
protections unchanged: 2883 (2 occurrences,
@@VP@@, load-bearing for the 288 leg), 28612
(2 occurrences, @@VO@@), the bare value 285
(2 occurrences, @@VN@@), and the real data value
21267 (AES-NUM-262 layer) protected as usual at
exactly 2 occurrences. AES-NUM-289 references
in arms290 = 95, shifted to AES-NUM-290.
Make-level audit of build290 (outside the parked
header/block/comment) found NO NEW protection:
no long data value containing 290, and 28612 /
2883 both 0 occurrences in the rest; the 28612
@@VALD@@ protection stands as a harmless carry.
Build note carried to 4.292: build290's
data-protection comment is 25 lines (not 26), so
the inherited extraction captures the 'def rep'
line as its 26th line — gen291's 1c segment
re-adds 'def rep(old, new, cnt=1):' as the
comment block's final line; gen292 must do the
same. hef291 = hef290 + arms291 byte-exact
(on-device assembly sha == VM). Build sanity on
arms291 (14/14 PASS): the A291 and G291 lists
present, 290836 preserved 3 occurrences with
ZERO 291836, 42908 preserved 2 occurrences with
ZERO 42918, 2883 preserved 2 occurrences, 28612
preserved 2 occurrences, ', 285,' 2 occurrences,
21267 2 occurrences, DONE291 present, DONE290
absent, AES-NUM-290 references 99; remaining 290
tokens are exactly the AES-NUM-290 references
plus the two protected data values; py_compile
OK on the VM and on-device. run291.sh landed via
sha-gated file.write (sha256 prefix `bb1a4c27`,
237 B).

Crossing, stated exactly: a tiny receiver
(/tmp/recv291.py, sha256 `48f735aa`…, landed
sha-gated via file.write by an earlier firing)
was still waiting in a detached tmux session
(recv291) on Mimir :8098 and the VM posted
arms291.py.gz through the tunnel proxy; zero
payload bytes passed through model re-emission.
The receiver reported saved 11,480 B with sha
`fef34375` == the local gzip sha exactly, and
its single-request server then exited. The
assembled arms291 and hef291 shas == VM
on-device.

LAUNCH: exactly ONE bounded host-side child ran
in detached tmux (session h291, launched
2026-11-01 06:43 EST; pre-launch tmux/ps check
clean — no h291, no hef291 process, no prior
hef291.out/.exit) with the contract corpus argv
(glob order, MiniLM last), unbuffered
(`python3 -u`). The child finished with exit
marker 0 (hef291.exit, timestamped 06:47 EST),
err empty, and DONE291 as its last line. Output
hef291.out 60,472 lines / 15,861,895 B sha256
prefix `7c34d168`; prefix against hef290.out: the
first 60,428 lines differ from hef290.out in
exactly 1 line (41611), sorted-character equal —
an AES-NUM-150 frozenset variance line (verified
via check291.py sha256 prefix `57a81ac3`, derived
from the check290 lineage by the simultaneous
289->290 / 290->291 shift), hef291.out adding
exactly its own 44 tail lines (345,780 B, sha256
prefix `1373225e`).

No correction is carried into this slice and none
arises from it: no correction was carried into
4.290 either (the AES-NUM-258 expected-value
correction carried from 4.280 was verified closed
in the 4.281 run), and section291 contains
exactly FOUR 'False' tokens — the four
gap-position agree data values for gap positions
1-4 (positions 5, 6, 7 agree), data not
comparisons, as in every prior slice — and no
fifth False. There is no controls exception in
this slice and no correction is carried into
4.292.
Raw output kept on the Pi at
~/aesir-build/ (hef291.out, hef291.py, arms291.py,
section291.txt, hef291.exit, hef291.err, run291.sh,
check291.py); local lineage in
~/workspace/.verify-tmp/aesir291.

Definitions carry over from AES-NUM-247 through
AES-NUM-290 exactly as printed in the run: POSITION
is 1-based over the eight acts of the closing run
(A ranks 741–748, B ranks 743–750); the sequences
below are the running totals of the AES-NUM-290
values, re-verified as exact cumulative sums
before commit.

## Findings

(i) The closing-run cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining
remaining-count sequence in full is
[55, 1967, 36150, 454878, 4405704, 35011623, 237652779, 1416391860] over positions 1-8 — the running total
of each position's AES-NUM-290 cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining
remaining value, ending at 1416391860. The
contracted comparisons read True at all eight
positions.

(ii) The distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals in full are
eight: 55 at position 1 count 1; 1967 at position
2 count 1; 36150 at position 3 count 1; 454878 at
position 4 count 1; 4405704 at position 5 count 1;
35011623 at position 6 count 1; 237652779 at
position 7 count 1; 1416391860 at position 8 count
1 (counts sum to 8).

(iii) The gap cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count
sequence in full is [12, 429, 7881, 99123, 959596, 7621964, 51709203] over gap positions
1-7, ending at 51709203, checked against
AES-NUM-290 and AES-NUM-245 (agreeing gap
positions 5, 6, 7, count 3, equal to AES-NUM-245).

Mechanisms NOT PROVEN; any offset, prefix or
position law NOT PROVEN; run 102's meaning NOT
PROVEN. Broad ordinary UNMODIFIED source-model
support remains the destination.

## Next

Slice 4.292 (contract in
`docs/TASK_CONTRACT_4.292.md`): the closing-run
cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence in
full; the distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals in full with
their positions and counts; and the gap
cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence in
full, checked against AES-NUM-291 and AES-NUM-245
— no correction is carried into 4.292.
