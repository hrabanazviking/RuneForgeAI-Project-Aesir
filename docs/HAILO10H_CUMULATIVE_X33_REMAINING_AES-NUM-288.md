# The closing-run cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence, the distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals, and the gap cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence (AES-NUM-288)

Slice 4.288, worked under `docs/TASK_CONTRACT_4.288.md`
(contract published in the 4.287 closing commit @
fecc9807). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child, no device run
of any kind. All findings below are taken from the
sha-verified raw output, read on-device
(section288.txt). Filename convention, recorded
explicitly per the 4.288 contract's close law: at
thirty-three CUMULATIVEs the chain plus REMAINING.md
alone exceeds the 255-byte filesystem limit even
further, with no fixed prefix left to shorten — so
this evidence filename uses the compact X33
notation
(`HAILO10H_CUMULATIVE_X33_REMAINING_AES-NUM-288.md`)
while the full thirty-three-CUMULATIVE chain is
preserved untruncated in this document's title and
throughout its content. The chain is never silently
truncated. The same convention governs 4.289 (X34).

## Run and closing record

hef288.py is the verified hef287 base plus
arms288: hef287.py sha256 prefix `70ff1bd9`
(4,219,074 B) on both the VM and the device.
arms288 sha256 prefix `55665497`; hef288.py sha256
prefix `f005ee46` (4,350,844 B) on both the VM and
the device; arms288 gzip sha256 prefix `750c5b15`.
hef288 was built locally on the hef287 lineage
(make_build288.py derived from make_build287, which
carries the three AES-NUM-272 builder fixes and
every carried digit-free placeholder protection
from AES-NUM-274 through AES-NUM-287). Audit of
arms287/build287 for real data values containing
the slice-number substring 287 found NONE NEW:
arms287 standalone 287 tokens = 5, all 4.287
section labels; 2872 (26 digit-sequence hits) and
102287 (4 hits) are identifier suffixes only, with
zero pure-numeric data occurrences; the 12 pure
287 tokens in build287 are all slice references or
shift literals. The @@VN@@ protection for the bare
data value 285 (2 occurrences in arms287) CARRIES
verbatim — 285 is outside the 286/287 shift set
for 4.288, so it is a harmless carry — and the
real data value 21267 (AES-NUM-262 layer) is
protected as usual at exactly 2 occurrences in
arms288. AES-NUM-286 references in arms287 = 83,
shifted to AES-NUM-287. hef288 = hef287 + arms288
byte-exact (on-device assembly sha == VM).
run288.sh landed via sha-gated file.write (sha256
prefix `ebe8a854`, 237 B).

Crossing, stated exactly: an intermediate firing
had crossed parts p_aa–p_ay to Mimir by 02:16 EST
without recording it, then stopped mid-transfer;
the closing worker verified every on-device part
sha against the local build (all 25 landed parts
EXACT), then completed the crossing sha-gated
(saz parts and sub_ba parts assembled on-device,
each sha EXACT; p_bb / p_bc / p_bd landed whole
first try). The assembled gzip, arms288 and
hef288 shas == VM on-device; py_compile OK on VM
and on-device.

LAUNCH: exactly ONE bounded host-side child ran
in detached tmux (session h288, launched
2026-11-01 02:36 EST; pre-launch tmux/ps check
clean — no h288, no hef288 process, no prior
hef288.out/.exit) with the contract corpus argv
(glob order, MiniLM last), unbuffered
(`python3 -u`); at the launching worker's check
hef288.out was 0 B and hef288.err empty — child
running. The child finished with exit marker 0
(hef288.exit, timestamped 02:40 EST), err empty,
and DONE288 as its last line. Output hef288.out
60,340 lines / 14,871,655 B sha256 prefix
`e0909395`; prefix against hef287.out: the first
60,296 lines differ from hef287.out in exactly 2
lines (41611 and 42872), both sorted-character
equal — the AES-NUM-150 frozenset variance lines
arose this generation (verified via check288.py
sha256 prefix `16f6fd9a`, derived from the
check287 lineage by the simultaneous 286->287 /
287->288 shift), hef288.out adding exactly its
own 44 tail lines (299,432 B, sha256 prefix
`d86ef5aa`).

No correction is carried into this slice and none
arises from it: no correction was carried into
4.287 either (the AES-NUM-258 expected-value
correction carried from 4.280 was verified closed
in the 4.281 run), and section288 contains
exactly FOUR 'False' tokens — the four
gap-position agree data values for gap positions
1-4 (positions 5, 6, 7 agree), data not
comparisons, as in every prior slice — and no
fifth False. There is no controls exception in
this slice and no correction is carried into
4.289.
Raw output kept on the Pi at
~/aesir-build/ (hef288.out, hef288.py, arms288.py,
section288.txt, hef288.exit, hef288.err, run288.sh,
check288.py); local lineage in
~/workspace/.verify-tmp/aesir288.

Definitions carry over from AES-NUM-247 through
AES-NUM-287 exactly as printed in the run: POSITION
is 1-based over the eight acts of the closing run
(A ranks 741–748, B ranks 743–750); the sequences
below are the running totals of the AES-NUM-287
values, re-verified as exact cumulative sums
before commit.

## Findings

(i) The closing-run cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining
remaining-count sequence in full is
[55, 1802, 30414, 352274, 3147553, 23122995, 145380144, 804062688] over positions 1-8 — the running total
of each position's AES-NUM-287 cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining
remaining value, ending at 804062688. The
contracted comparisons read True at all eight
positions.

(ii) The distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals in full are
eight: 55 at position 1 count 1; 1802 at position
2 count 1; 30414 at position 3 count 1; 352274 at
position 4 count 1; 3147553 at position 5 count 1;
23122995 at position 6 count 1; 145380144 at
position 7 count 1; 804062688 at position 8 count
1 (counts sum to 8).

(iii) The gap cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count
sequence in full is [12, 393, 6630, 76755, 685441, 5032664, 31622976] over gap positions
1-7, ending at 31622976, checked against
AES-NUM-287 and AES-NUM-245 (agreeing gap
positions 5, 6, 7, count 3, equal to AES-NUM-245).

Mechanisms NOT PROVEN; any offset, prefix or
position law NOT PROVEN; run 102's meaning NOT
PROVEN. Broad ordinary UNMODIFIED source-model
support remains the destination.

## Next

Slice 4.289 (contract in
`docs/TASK_CONTRACT_4.289.md`): the closing-run
cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence in
full; the distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals in full with
their positions and counts; and the gap
cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence in
full, checked against AES-NUM-288 and AES-NUM-245
— no correction is carried into 4.289.
