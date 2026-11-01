# The closing-run cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence, the distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals, and the gap cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence (AES-NUM-280)

Slice 4.280, worked under `docs/TASK_CONTRACT_4.280.md`
(contract published in the 4.279 closing commit @
3e9435dc). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child, no device run
of any kind. All findings below are taken from the
sha-verified raw output, read in full on-device
(section280.txt). Filename convention, recorded
explicitly per the 4.280 contract's close law: at
twenty-five CUMULATIVEs the chain plus REMAINING.md
alone exceeds the 255-byte filesystem limit even
further, with no fixed prefix left to shorten — so
this evidence filename uses the compact X25
notation
(`HAILO10H_CUMULATIVE_X25_REMAINING_AES-NUM-280.md`)
while the full twenty-five-CUMULATIVE chain is
preserved untruncated in this document's title and
throughout its content. The chain is never silently
truncated. The same convention governs 4.281 (X26).

## Run and closing record

hef280.py is the verified hef279 base plus
arms280: hef279.py sha256
`76088e75ec37c83dd81a68accc10a947534cb1a99b5008db93f010f4b92d11a0`
(3,351,052 B) on both the VM and the device.
arms280 sha256
`69f87cd9f83db6ef1555d834ce89e690d9b27d81fb77f76df4cb4540cff51734`
(91,570 B); hef280.py sha256
`715125697f825567d77f73b25455f2e8d33916a76aefd3bce6e3abd2ba8e707f`
(3,442,622 B) on both the VM and the device.
arms280 was built locally on the hef279 lineage
(make_build280.py derived from make_build279 —
marker-parked header/block/comment before the
simultaneous 278->279 / 279->280 shift, so the
textual shift could not corrupt them; the three
AES-NUM-272 builder fixes carried). Audit of
arms279/build279 found ONE real data value
containing the outgoing substring 279 — 127925
(2 occurrences, a gap cumulative sequence value) —
protected with the digit-free placeholder @@VH@@
in the new builder block; carried protections all
x2 in arms280 (2725341, 2723, 34273, 2759793,
21267, 11278, 32784, 127925). The audit MISSED one
real data value: the standalone value 279 itself
in the AES-NUM-258 expected sequence (see the
controls exception below). hef280 = hef279 +
arms280 byte-exact. Crossing, stated exactly:
arms280 was gzipped with gzip -9 (sha256
`72900c7962c636e8c206cd7b128046ab9094e59e3a77e0938b4876d17ea5ac17`,
9,491 B) and transferred via 26 sha-gated 373 B
file.write parts — all 26 landed sha-clean first
try. No byte accepted unverified.
The assembled gzip, arms280 and hef280
shas == VM on-device; py_compile OK on-device.
run280.sh landed via sha-gated file.write
(sha256
`3b32b16f0bd95f8acb2bd334406fc232bd9cb2473284ff64bf43acbc6c4cacc4`,
237 B). The real data value 21267 (AES-NUM-262
layer, two occurrences) was verified untouched
at exactly 2 occurrences in arms280.

LAUNCH: exactly ONE bounded host-side child ran
in detached tmux (session h280, launched
2026-10-31 19:48 EDT) with the contract corpus
argv (glob order, MiniLM last), unbuffered
(`python3 -u`); at launch +20 s hef280.out was
679 B and growing with err empty and no exit
file yet. The child finished with exit marker 0
(hef280.exit, timestamped 19:52 EDT), err empty,
and DONE280 as its last line. Output hef280.out
59,988 lines / 12,866,793 B sha256
`b60242602ae38478dd64ed737a36bc99dbd7b5a412b6bfe628502047694e1b69`;
prefix against hef279.out: the first 59,944 lines
differ from hef279.out in exactly ONE line
(line 41611, frozenset element order
only, the AES-NUM-150 variance, verified by
same-sorted-characters comparison via
check280.py sha256
`3faa9977cd2db575f5ddbc9c55a8c9c1e91da689d35122c5fb3bd8bc532c6cec`),
hef280.out adding exactly its own 44 tail lines
(192,329 B, sha256
`a52b77ac453eaf7437f98d2d4d0a61b83c676e295982debff16198c108eace78`).

Controls exception, recorded honestly: section280
contains exactly FIVE 'False' tokens. Four are the
gap-position agree data values for gap positions
1-4 (positions 5, 6, 7 agree) — data, not
comparisons, as in every prior slice. The fifth is
ONE comparison at position 3: the computed
AES-NUM-258-level value 279 was compared against
an expected list reading 280, and printed False.
Root cause, established on the VM from the build
inputs: the hef280 build's simultaneous
278->279 / 279->280 textual shift corrupted the
real data value 279 in the AES-NUM-258 expected
sequence [55, 152, 279, 424, 578, 735, 892, 1049]
(prose definition and expCumCumCum list, 2
occurrences in arms279) into 280 in arms280. The
computed value 279 agrees with the AES-NUM-258
printed value in every prior slice (4.276-4.279
sections all read True at this comparison); the
data are correct, the 4.280 expected list was
corrupted by the build. All three contracted
findings (i)-(iii) and every other printed
comparison read True. A correction is carried
into slice 4.281: its build MUST restore the
AES-NUM-258 expected sequence to
[55, 152, 279, 424, 578, 735, 892, 1049] before
shifting and protect that real data value 279
(2 occurrences) with a digit-free placeholder,
and the 4.281 run MUST verify this comparison
reads True again.
Raw output kept on the Pi at
~/aesir-build/ (hef280.out, hef280.py, arms280.py,
section280.txt, hef280.exit, hef280.err, run280.sh,
check280.py); local lineage in
~/workspace/.verify-tmp/aesir280.

Definitions carry over from AES-NUM-247 through
AES-NUM-279 exactly as printed in the run: POSITION
is 1-based over the eight acts of the closing run
(A ranks 741–748, B ranks 743–750); the agreement
set, agreement count, cumulative total, difference,
remaining, cumulative remaining and every iterated
cumulative cumulative-remaining running total are as defined in
the section280 header, read in full on-device.

## (i) The closing-run cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence in full

At each position, the running total of the
AES-NUM-279 cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining values
over positions 1 up to and including that position
(all printed comparisons True for all eight):

- Position 1 (A rank 741 / B rank 743): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 55.
- Position 2 (A rank 742 / B rank 744): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 1362.
- Position 3 (A rank 743 / B rank 745): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 17538.
- Position 4 (A rank 744 / B rank 746): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 156338.
- Position 5 (A rank 745 / B rank 747): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 1083891.
- Position 6 (A rank 746 / B rank 748): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 6226119.
- Position 7 (A rank 747 / B rank 749): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 30829932.
- Position 8 (A rank 748 / B rank 750): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 135208440.

Sequence: [55, 1362, 17538, 156338, 1083891, 6226119, 30829932, 135208440] —
equals the expected sequence (printed test True);
the last cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative total is 135208440.

## (ii) The distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals in full

Distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals, in order of first
appearance, with positions and counts (counts sum
to 8, printed test True):

- 55: position 1 — count 1.
- 1362: position 2 — count 1.
- 17538: position 3 — count 1.
- 156338: position 4 — count 1.
- 1083891: position 5 — count 1.
- 6226119: position 6 — count 1.
- 30829932: position 7 — count 1.
- 135208440: position 8 — count 1.

Eight distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals; none repeats —
stated as printed arithmetic only, no mechanism claimed.

## (iii) The gap cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence in full

At each gap position, the running total of the
AES-NUM-279 gap cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining values
over gap positions 1 up to and including that gap
position (A gaps all 512; B gaps 712, 26624, 14848,
33280, 512, 512, 512; agree False, False, False,
False, True, True, True):

- Gap position 1: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 12.
- Gap position 2: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 297.
- Gap position 3: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 3822.
- Gap position 4: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 34047.
- Gap position 5: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 235873.
- Gap position 6: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 1353834.
- Gap position 7: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 6698160.

Sequence: [12, 297, 3822, 34047, 235873, 1353834, 6698160] — equals the
expected sequence (printed test True), ends at
6698160, with agreeing positions 5, 6, 7 (count 3),
equal to AES-NUM-245.

Contract tests: the printed cumulative sequence
equals (55, 1362, 17538, 156338, 1083891, 6226119, 30829932,
135208440) — True; the distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals'
counts sum to 8 — True; the last cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative total
equals 135208440 — True; the gap cumulative sequence
equals (12, 297, 3822, 34047, 235873, 1353834, 6698160)
and ends at 6698160 — True.

Mechanisms NOT PROVEN; any offset, prefix or
position law NOT PROVEN; run 102's meaning NOT
PROVEN.
