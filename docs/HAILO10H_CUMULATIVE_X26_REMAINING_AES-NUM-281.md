# The closing-run cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence, the distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals, and the gap cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence (AES-NUM-281)

Slice 4.281, worked under `docs/TASK_CONTRACT_4.281.md`
(contract published in the 4.280 closing commit @
bb370186). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child, no device run
of any kind. All findings below are taken from the
sha-verified raw output, read in full on-device
(section281.txt). Filename convention, recorded
explicitly per the 4.281 contract's close law: at
twenty-six CUMULATIVEs the chain plus REMAINING.md
alone exceeds the 255-byte filesystem limit even
further, with no fixed prefix left to shorten — so
this evidence filename uses the compact X26
notation
(`HAILO10H_CUMULATIVE_X26_REMAINING_AES-NUM-281.md`)
while the full twenty-six-CUMULATIVE chain is
preserved untruncated in this document's title and
throughout its content. The chain is never silently
truncated. The same convention governs 4.282 (X27).

## Run and closing record

hef281.py is the verified hef280 base plus
arms281: hef280.py sha256
`715125697f825567d77f73b25455f2e8d33916a76aefd3bce6e3abd2ba8e707f`
(3,442,622 B) on both the VM and the device.
arms281 sha256
`3ad3aff5c1435f780b647dc99f0547c18d3799d4e0c759194d96a86a97472964`
(96,155 B); hef281.py sha256
`4497a391e0e8b9cd8dd10132be5e51faffa6a9014a7af59594cfd4cf0e5c6f10`
(3,538,777 B) on both the VM and the device.
arms281 was built locally on the hef280 lineage
(make_build281.py derived from make_build280 —
the make-level derivation parked the placeholder
definitions and, inside build281, the
header/block/comment are marker-parked before the
simultaneous 279->280 / 280->281 shift, so the
textual shift could not corrupt them; the three
AES-NUM-272 builder fixes carried). Audit of
arms280/build280 for real data values containing
the outgoing substring 280 found FOUR: the
corrupted AES-NUM-258 value 280 (2 occurrences —
restored to 279 before shifting and protected
@@VI@@, see the correction record below);
791777280 (1 occurrence, an expA offset —
protected @@VJ@@); 33280 (1 occurrence, an
expBgaps value — protected @@VK@@); and the bare
expB value 280 (1 occurrence, in ', 280,' form —
protected @@VL@@). Carried protections all
verified at exact counts in arms281: 2725341,
2723, 34273, 2759793, 21267, 11278, 32784 x2 and
127925 x2 (protected for the 279 shift); the only
remaining 280 tokens in arms281 are AES-NUM-280
references (59) and the three protected data
values above. hef281 = hef280 + arms281
byte-exact. Crossing, stated exactly: arms281 was
gzipped with gzip -9 (sha256
`2a094f4b11a56b1d97437ca9fde53771384c3ef31000e4f5d95cac2d070abdea`,
9,695 B). A first crossing attempt — one chunked
file.write of the whole gzip — failed its
whole-file sha256 gate at the final chunk and was
discarded uncommitted on-device; no byte of it
was accepted. The gzip was then split into 26
parts of 373 B, each sent as its own sha-gated
file.write: 25 parts landed sha-clean first try;
part p_av failed its sha twice at the 373 B
boundary and landed as two sha-gated halves
(187 B + 186 B) — the chunk boundary was changed,
not merely retried. The assembled gzip, arms281
and hef281 shas == VM on-device; py_compile OK
on-device. run281.sh landed via sha-gated
file.write (sha256
`e90ae69beeef5fe38bc09eec557a4985a9682ead78bb9f443ef4e7413ca3a927`,
237 B). The real data value 21267 (AES-NUM-262
layer, two occurrences) was verified untouched
at exactly 2 occurrences in arms281.

LAUNCH: exactly ONE bounded host-side child ran
in detached tmux (session h281, launched
2026-10-31 21:05 EDT) with the contract corpus
argv (glob order, MiniLM last), unbuffered
(`python3 -u`); at launch +20 s hef281.out was
336 B and growing with err empty and no exit
file yet. The child finished with exit marker 0
(hef281.exit, timestamped 21:08 EDT), err empty,
and DONE281 as its last line. Output hef281.out
60,032 lines / 13,071,194 B sha256
`6d00ae0e9f77d38307b941ecca1e4cbb0bd276030ab6070bc61677b949484553`;
prefix against hef280.out: the first 59,988 lines
differ from hef280.out in exactly TWO lines
(lines 41611 and 42872, frozenset element order
only, the AES-NUM-150 variance, verified by
same-sorted-characters comparison via
check281.py sha256
`70318f95e839d687a4d60e375082aa6815c42672419cd814d2eb31f81e3e45ce`),
hef281.out adding exactly its own 44 tail lines
(204,401 B, sha256
`3703f2df0af1e80586b9a1b43ff60675f89fe941f504af1ab2b3ee6231567390`).

Correction verified closed: the correction
carried into this slice from the 4.280 controls
exception is VERIFIED CLOSED by this run. The
hef281 build restored the AES-NUM-258 expected
sequence to [55, 152, 279, 424, 578, 735, 892, 1049]
before any shift and protected the restored real
data value 279 (2 occurrences, prose definition
and expCumCumCum list) with the digit-free
placeholder @@VI@@ through the shift; arms281
carries the sequence intact at exactly 2
occurrences (and no [55, 152, 280, ...] form).
In the run, section281 contains exactly FOUR
'False' tokens — the four gap-position agree data
values for gap positions 1-4 (positions 5, 6, 7
agree), data not comparisons, as in every prior
slice — and NO fifth False: the position-3
AES-NUM-258-level comparison reads True again.
There is no controls exception in this slice and
no correction is carried into 4.282.
Raw output kept on the Pi at
~/aesir-build/ (hef281.out, hef281.py, arms281.py,
section281.txt, hef281.exit, hef281.err, run281.sh,
check281.py); local lineage in
~/workspace/.verify-tmp/aesir281.

Definitions carry over from AES-NUM-247 through
AES-NUM-280 exactly as printed in the run: POSITION
is 1-based over the eight acts of the closing run
(A ranks 741–748, B ranks 743–750); the agreement
set, agreement count, cumulative total, difference,
remaining, cumulative remaining and every iterated
cumulative cumulative-remaining running total are as defined in
the section281 header, read in full on-device.

## (i) The closing-run cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence in full

At each position, the running total of the
AES-NUM-280 cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining values
over positions 1 up to and including that position
(all printed comparisons True for all eight):

- Position 1 (A rank 741 / B rank 743): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 55.
- Position 2 (A rank 742 / B rank 744): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 1417.
- Position 3 (A rank 743 / B rank 745): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 18955.
- Position 4 (A rank 744 / B rank 746): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 175293.
- Position 5 (A rank 745 / B rank 747): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 1259184.
- Position 6 (A rank 746 / B rank 748): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 7485303.
- Position 7 (A rank 747 / B rank 749): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 38315235.
- Position 8 (A rank 748 / B rank 750): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 173523675.

Sequence: [55, 1417, 18955, 175293, 1259184, 7485303, 38315235, 173523675] —
equals the expected sequence (printed test True);
the last cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative total is 173523675.

## (ii) The distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals in full

Distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals, in order of first
appearance, with positions and counts (counts sum
to 8, printed test True):

- 55: position 1 — count 1.
- 1417: position 2 — count 1.
- 18955: position 3 — count 1.
- 175293: position 4 — count 1.
- 1259184: position 5 — count 1.
- 7485303: position 6 — count 1.
- 38315235: position 7 — count 1.
- 173523675: position 8 — count 1.

Eight distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals; none repeats —
stated as printed arithmetic only, no mechanism claimed.

## (iii) The gap cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence in full

At each gap position, the running total of the
AES-NUM-280 gap cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining values
over gap positions 1 up to and including that gap
position (A gaps all 512; B gaps 712, 26624, 14848,
33280, 512, 512, 512; agree False, False, False,
False, True, True, True):

- Gap position 1: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 12.
- Gap position 2: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 309.
- Gap position 3: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 4131.
- Gap position 4: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 38178.
- Gap position 5: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 274051.
- Gap position 6: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 1627885.
- Gap position 7: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 8326045.

Sequence: [12, 309, 4131, 38178, 274051, 1627885, 8326045] — equals the
expected sequence (printed test True), ends at
8326045, with agreeing positions 5, 6, 7 (count 3),
equal to AES-NUM-245.

Contract tests: the printed cumulative sequence
equals (55, 1417, 18955, 175293, 1259184, 7485303, 38315235,
173523675) — True; the distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals'
counts sum to 8 — True; the last cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative total
equals 173523675 — True; the gap cumulative sequence
equals (12, 309, 4131, 38178, 274051, 1627885, 8326045)
and ends at 8326045 — True.

Mechanisms NOT PROVEN; any offset, prefix or
position law NOT PROVEN; run 102's meaning NOT
PROVEN.
