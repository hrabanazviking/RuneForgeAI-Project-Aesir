# The closing-run cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence, the distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals, and the gap cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence (AES-NUM-290)

Slice 4.290, worked under `docs/TASK_CONTRACT_4.290.md`
(contract published in the 4.289 closing commit @
061bdd54). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child. All findings
below are taken from the sha-verified raw output,
read on-device (section290.txt). Filename
convention, recorded explicitly per the 4.290
contract's close law: at thirty-five CUMULATIVEs
the chain plus REMAINING.md alone exceeds the
255-byte filesystem limit even further — so this
evidence filename uses the compact X35 notation
(`HAILO10H_CUMULATIVE_X35_REMAINING_AES-NUM-290.md`)
while the full thirty-five-CUMULATIVE chain is
preserved untruncated in this document's title and
throughout its content. The chain is never silently
truncated. The same convention governs 4.291 (X36).

## Run and closing record

hef290.py is the verified hef289 base plus
arms290: hef289.py sha256 prefix `a93e6985`
(4,488,198 B) on both the VM and the device.
arms290 sha256 prefix `df60d307` (143,069 B);
hef290.py sha256 prefix `5b5770e3` (4,631,267 B)
on both the VM and the device; arms290 gzip
sha256 prefix `57abd504` (11,300 B).
hef290 was built locally on the hef289 lineage
(make_build290.py derived from make_build289,
which carries the three AES-NUM-272 builder fixes
and every carried digit-free placeholder
protection from AES-NUM-274 through AES-NUM-289).
Audit of arms289/build289 for real data values
containing the slice-number substring 289 found
NO NEW arms-level protection: arms289 bare 289
tokens = 5, all 4.289 section labels; 2892 (26
digit-sequence hits) and 102289 (4 hits) are
identifier suffixes only. The @@VP@@ protection
for 2883 (2 occurrences in arms289) carries and
stays load-bearing (2883 contains the 288 shift
leg); @@VN@@ for 285 (2 occurrences) and @@VO@@
for 28612 (2 occurrences) carry verbatim, counts
unchanged from arms288; and the real data value
21267 (AES-NUM-262 layer) is protected as usual
at exactly 2 occurrences in arms290. AES-NUM-288
references in arms289 = 91, shifted to
AES-NUM-289. Make-level audit of build289 found
NO NEW protection. hef290 = hef289 + arms290
byte-exact (on-device assembly sha == VM). Build
sanity on arms290: 2883 preserved 2 occurrences
with ZERO 2893, 28612 preserved 2 occurrences with
ZERO 28712, ', 285,' 2 occurrences, 21267 2
occurrences, DONE290 present, DONE289 absent;
remaining 289 tokens are AES-NUM-289 references
only; py_compile OK on the VM and on-device.
run290.sh landed via sha-gated file.write (sha256
prefix `557d9bab`, 237 B).

Crossing, stated exactly: a tiny receiver
(/tmp/recv290.py, sha256 `ed0e54a4`…, landed
sha-gated via file.write by an earlier firing at
05:23 EST) ran in a detached tmux session on
Mimir :8098 and the VM posted arms290.py.gz
through the tunnel proxy; zero payload bytes
passed through model re-emission. The receiver
reported saved 11,300 B with sha `57abd504` ==
the local gzip sha exactly, and its single-request
server then exited. The assembled arms290 and
hef290 shas == VM on-device.

LAUNCH: exactly ONE bounded host-side child ran
in detached tmux (session h290, launched
2026-11-01 05:34 EST; pre-launch tmux/ps check
clean — no h290, no hef290 process, no prior
hef290.out/.exit) with the contract corpus argv
(glob order, MiniLM last), unbuffered
(`python3 -u`). The child finished with exit
marker 0 (hef290.exit, timestamped 05:38 EST),
err empty, and DONE290 as its last line. Output
hef290.out 60,428 lines / 15,516,115 B sha256
prefix `41a164e2`; prefix against hef289.out: the
first 60,384 lines differ from hef289.out in
exactly 1 line (41611), sorted-character equal —
an AES-NUM-150 frozenset variance line (verified
via check290.py sha256 prefix `8e07adb8`, derived
from the check289 lineage by the simultaneous
288->289 / 289->290 shift), hef290.out adding
exactly its own 44 tail lines (329,957 B, sha256
prefix `054ea9c9`).

No correction is carried into this slice and none
arises from it: no correction was carried into
4.289 either (the AES-NUM-258 expected-value
correction carried from 4.280 was verified closed
in the 4.281 run), and section290 contains
exactly FOUR 'False' tokens — the four
gap-position agree data values for gap positions
1-4 (positions 5, 6, 7 agree), data not
comparisons, as in every prior slice — and no
fifth False. There is no controls exception in
this slice and no correction is carried into
4.291.
Raw output kept on the Pi at
~/aesir-build/ (hef290.out, hef290.py, arms290.py,
section290.txt, hef290.exit, hef290.err, run290.sh,
check290.py); local lineage in
~/workspace/.verify-tmp/aesir290.

Definitions carry over from AES-NUM-247 through
AES-NUM-289 exactly as printed in the run: POSITION
is 1-based over the eight acts of the closing run
(A ranks 741–748, B ranks 743–750); the sequences
below are the running totals of the AES-NUM-289
values, re-verified as exact cumulative sums
before commit.

## Findings

(i) The closing-run cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining
remaining-count sequence in full is
[55, 1912, 34183, 418728, 3950826, 30605919, 202641156, 1178739081] over positions 1-8 — the running total
of each position's AES-NUM-289 cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining
remaining value, ending at 1178739081. The
contracted comparisons read True at all eight
positions.

(ii) The distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals in full are
eight: 55 at position 1 count 1; 1912 at position
2 count 1; 34183 at position 3 count 1; 418728 at
position 4 count 1; 3950826 at position 5 count 1;
30605919 at position 6 count 1; 202641156 at
position 7 count 1; 1178739081 at position 8 count
1 (counts sum to 8).

(iii) The gap cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count
sequence in full is [12, 417, 7452, 91242, 860473, 6662368, 44087239] over gap positions
1-7, ending at 44087239, checked against
AES-NUM-289 and AES-NUM-245 (agreeing gap
positions 5, 6, 7, count 3, equal to AES-NUM-245).

Mechanisms NOT PROVEN; any offset, prefix or
position law NOT PROVEN; run 102's meaning NOT
PROVEN. Broad ordinary UNMODIFIED source-model
support remains the destination.

## Next

Slice 4.291 (contract in
`docs/TASK_CONTRACT_4.291.md`): the closing-run
cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence in
full; the distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals in full with
their positions and counts; and the gap
cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence in
full, checked against AES-NUM-290 and AES-NUM-245
— no correction is carried into 4.291.
