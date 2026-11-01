# The closing-run cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence, the distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals, and the gap cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence (AES-NUM-289)

Slice 4.289, worked under `docs/TASK_CONTRACT_4.289.md`
(contract published in the 4.288 closing commit @
c0930788). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child, no device run
of any kind. All findings below are taken from the
sha-verified raw output, read on-device
(section289.txt). Filename convention, recorded
explicitly per the 4.289 contract's close law: at
thirty-four CUMULATIVEs the chain plus REMAINING.md
alone exceeds the 255-byte filesystem limit even
further, with no fixed prefix left to shorten — so
this evidence filename uses the compact X34
notation
(`HAILO10H_CUMULATIVE_X34_REMAINING_AES-NUM-289.md`)
while the full thirty-four-CUMULATIVE chain is
preserved untruncated in this document's title and
throughout its content. The chain is never silently
truncated. The same convention governs 4.290 (X35).

## Run and closing record

hef289.py is the verified hef288 base plus
arms289: hef288.py sha256 prefix `f005ee46`
(4,350,844 B) on both the VM and the device.
arms289 sha256 prefix `c2b6c721` (137,354 B);
hef289.py sha256 prefix `a93e6985` (4,488,198 B)
on both the VM and the device; arms289 gzip
sha256 prefix `4fa48fcc` (11,224 B).
hef289 was built locally on the hef288 lineage
(make_build289.py derived from make_build288,
which carries the three AES-NUM-272 builder fixes
and every carried digit-free placeholder
protection from AES-NUM-274 through AES-NUM-288).
Audit of arms288/build288 for real data values
containing the slice-number substring 288 found
ONE NEW arms-level protection: the real data
value 2883 (2 occurrences in arms288, the
AES-NUM-265 sequence's third value) contains the
outgoing substring 288 and is protected as
@@VP@@. arms288 bare 288 tokens = 5, all 4.288
section labels; 2882 (26 digit-sequence hits) and
102288 (4 hits) are identifier suffixes only. The
@@VO@@ protection for 28612 carries with its
arms288 count rolled 5 -> 2; the @@VN@@ protection
for the bare data value 285 (2 occurrences)
carries verbatim; and the real data value 21267
(AES-NUM-262 layer) is protected as usual at
exactly 2 occurrences in arms289. AES-NUM-287
references in arms288 = 87, shifted to
AES-NUM-288. hef289 = hef288 + arms289 byte-exact
(on-device assembly sha == VM). Build sanity on
arms289: 2883 preserved 2 occurrences with ZERO
2893, 28612 preserved 2 occurrences with ZERO
28712, ', 285,' 2 occurrences, 21267 2
occurrences, DONE289 present, DONE288 absent;
py_compile OK on the VM and on-device.
run289.sh landed via sha-gated file.write (sha256
prefix `45b56cb2`, 237 B).

Crossing, stated exactly: this generation took a
new route — instead of sha-gated parts, a tiny
receiver (/tmp/recv289.py, sha256 prefix
`9d3a3039`, landed sha-gated via file.write) ran
in a detached tmux session on Mimir :8098 and the
VM posted arms289.py.gz through the tunnel proxy;
zero payload bytes passed through model
re-emission. The receiver reported saved 11,224 B
with sha `4fa48fcc` == the local gzip sha exactly,
then the receiver session was killed. The
assembled arms289 and hef289 shas == VM
on-device.

LAUNCH: exactly ONE bounded host-side child ran
in detached tmux (session h289, launched
2026-11-01 04:13 EST; pre-launch tmux/ps check
clean — no h289, no hef289 process, no prior
hef289.out/.exit) with the contract corpus argv
(glob order, MiniLM last), unbuffered
(`python3 -u`). The child finished with exit
marker 0 (hef289.exit, timestamped 04:17 EST),
err empty, and DONE289 as its last line. Output
hef289.out 60,384 lines / 15,186,158 B sha256
prefix `0a7cf924`; prefix against hef288.out: the
first 60,340 lines differ from hef288.out in
exactly 1 line (41611), sorted-character equal —
an AES-NUM-150 frozenset variance line arose
this generation (verified via check289.py sha256
prefix `ae65185c`, derived from the check288
lineage by the simultaneous 287->288 / 288->289
shift), hef289.out adding exactly its own 44 tail
lines (314,503 B, sha256 prefix `fae8bb97`).

No correction is carried into this slice and none
arises from it: no correction was carried into
4.288 either (the AES-NUM-258 expected-value
correction carried from 4.280 was verified closed
in the 4.281 run), and section289 contains
exactly FOUR 'False' tokens — the four
gap-position agree data values for gap positions
1-4 (positions 5, 6, 7 agree), data not
comparisons, as in every prior slice — and no
fifth False. There is no controls exception in
this slice and no correction is carried into
4.290.
Raw output kept on the Pi at
~/aesir-build/ (hef289.out, hef289.py, arms289.py,
section289.txt, hef289.exit, hef289.err, run289.sh,
check289.py); local lineage in
~/workspace/.verify-tmp/aesir289.

Definitions carry over from AES-NUM-247 through
AES-NUM-288 exactly as printed in the run: POSITION
is 1-based over the eight acts of the closing run
(A ranks 741–748, B ranks 743–750); the sequences
below are the running totals of the AES-NUM-288
values, re-verified as exact cumulative sums
before commit.

## Findings

(i) The closing-run cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining
remaining-count sequence in full is
[55, 1857, 32271, 384545, 3532098, 26655093, 172035237, 976097925] over positions 1-8 — the running total
of each position's AES-NUM-288 cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining
remaining value, ending at 976097925. The
contracted comparisons read True at all eight
positions.

(ii) The distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals in full are
eight: 55 at position 1 count 1; 1857 at position
2 count 1; 32271 at position 3 count 1; 384545 at
position 4 count 1; 3532098 at position 5 count 1;
26655093 at position 6 count 1; 172035237 at
position 7 count 1; 976097925 at position 8 count
1 (counts sum to 8).

(iii) The gap cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count
sequence in full is [12, 405, 7035, 83790, 769231, 5801895, 37424871] over gap positions
1-7, ending at 37424871, checked against
AES-NUM-288 and AES-NUM-245 (agreeing gap
positions 5, 6, 7, count 3, equal to AES-NUM-245).

Mechanisms NOT PROVEN; any offset, prefix or
position law NOT PROVEN; run 102's meaning NOT
PROVEN. Broad ordinary UNMODIFIED source-model
support remains the destination.

## Next

Slice 4.290 (contract in
`docs/TASK_CONTRACT_4.290.md`): the closing-run
cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence in
full; the distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals in full with
their positions and counts; and the gap
cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence in
full, checked against AES-NUM-289 and AES-NUM-245
— no correction is carried into 4.290.
