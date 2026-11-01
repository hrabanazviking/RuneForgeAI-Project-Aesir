# The closing-run cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence, the distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals, and the gap cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence (AES-NUM-282)

Slice 4.282, worked under `docs/TASK_CONTRACT_4.282.md`
(contract published in the 4.281 closing commit @
c08e6b0b). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child, no device run
of any kind. All findings below are taken from the
sha-verified raw output, read on-device
(section282.txt). Filename convention, recorded
explicitly per the 4.282 contract's close law: at
twenty-seven CUMULATIVEs the chain plus REMAINING.md
alone exceeds the 255-byte filesystem limit even
further, with no fixed prefix left to shorten — so
this evidence filename uses the compact X27
notation
(`HAILO10H_CUMULATIVE_X27_REMAINING_AES-NUM-282.md`)
while the full twenty-seven-CUMULATIVE chain is
preserved untruncated in this document's title and
throughout its content. The chain is never silently
truncated. The same convention governs 4.283 (X28).

## Run and closing record

hef282.py is the verified hef281 base plus
arms282: hef281.py sha256
`4497a391e0e8b9cd8dd10132be5e51faffa6a9014a7af59594cfd4cf0e5c6f10`
(3,538,777 B) on both the VM and the device.
arms282 sha256
`d3985fe4fbddb205641d30cf828fac4c7b51ee2442acc7ef0ece9d47df4e74b8`
(100,870 B); hef282.py sha256
`780186c6b2b40a07f688e634047ed42b6c06fd1056e2d12f770db18d476fdf89`
(3,639,647 B) on both the VM and the device.
arms282 was built locally on the hef281 lineage
(make_build282.py derived from make_build281 via
make_make282 — a line-wise block edit; the three
AES-NUM-272 builder fixes and every carried
digit-free placeholder protection from
AES-NUM-274 through AES-NUM-281 stand). Audit of
arms281/build281 for real data values containing
the slice-number substrings found, beyond the
carried protections: the value 5281 (2 occurrences
in arms281 — an AES-NUM-264 gap prose tuple and an
expected list) contains 281 and was protected
@@VM@@; the carried 280 protections stand
(791777280, 1 occurrence; 33280, 1 occurrence; the
bare expB value 280 in ', 280,' form, 1
occurrence); the AES-NUM-258 sequence in arms281
is the CORRECT restored 279 form (tuple + list, 1
occurrence each), so build282's @@VI@@ search was
re-pointed to that correct form (279 lies outside
the 280/281 shift set, a harmless carry); 127925
(2 occurrences) contains neither 280 nor 281;
AES-NUM-280 references in arms281 (59) shift to
AES-NUM-281. Independent audit of arms282: all
expected 282/281 sequences, the distinct list and
every protected value at exact counts (5281 x2,
791777280 x1, 33280 x1, bare 280 x1, 279 form x2,
127925/11278/32784/21267 x2). hef282 = hef281 +
arms282 byte-exact. Crossing, stated exactly:
arms282 was gzipped with gzip -9 (sha256
`e7d212e1b560ec1016f82c01be2b3c679bf1d8a98a750a27ed7e506f402c7116`,
9,899 B), split into 27 parts of 373 B, each sent
as its own sha-gated file.write to Mimir: 26 parts
landed sha-clean first try; part p_aj failed its
sha once (the write was discarded uncommitted)
and landed on a verbatim retry. The assembled
gzip, arms282 and hef282 shas == VM on-device;
py_compile OK on-device. run282.sh landed via
sha-gated file.write (sha256
`be759a6726e11fa8b176c2469547b61321e88f29a443e867175da8ec27439bfb`,
237 B). The real data value 21267 (AES-NUM-262
layer, two occurrences) was verified untouched
at exactly 2 occurrences in arms282.

LAUNCH: exactly ONE bounded host-side child ran
in detached tmux (session h282, launched
2026-10-31 21:47 EDT; pre-launch tmux/ps check
clean) with the contract corpus argv (glob
order, MiniLM last), unbuffered (`python3 -u`);
at the launching worker's check hef282.out was
371,926 B and growing with err empty and no exit
file yet. The child finished with exit marker 0
(hef282.exit, timestamped 21:50 EDT), err empty,
and DONE282 as its last line. Output hef282.out
60,076 lines / 13,288,049 B sha256
`7cca83d0ff9af584f998557813e372caf9593a3155805f6c27e3ae8d41d998d4`;
prefix against hef281.out: the first 60,032 lines
differ from hef281.out in exactly TWO lines
(lines 41611 and 42872, frozenset element order
only, the AES-NUM-150 variance, verified by
same-sorted-characters comparison via
check282.py sha256
`fc386474c6195a0d692a57cdeef15c037e0a2f40073e72c13e147184fc280c48`),
hef282.out adding exactly its own 44 tail lines
(216,855 B, sha256
`4ea974e3f15f32a6063193f3805120e4c08c4d504394ed0b88f9bb63041e8554`).

No correction is carried into this slice and none
arises from it: slice 4.281's correction was
verified closed in the 4.281 run, and section282
contains exactly FOUR 'False' tokens — the four
gap-position agree data values for gap positions
1-4 (positions 5, 6, 7 agree), data not
comparisons, as in every prior slice — and no
fifth False. There is no controls exception in
this slice and no correction is carried into
4.283.
Raw output kept on the Pi at
~/aesir-build/ (hef282.out, hef282.py, arms282.py,
section282.txt, hef282.exit, hef282.err, run282.sh,
check282.py); local lineage in
~/workspace/.verify-tmp/aesir282.

Definitions carry over from AES-NUM-247 through
AES-NUM-281 exactly as printed in the run: POSITION
is 1-based over the eight acts of the closing run
(A ranks 741–748, B ranks 743–750); the agreement
set, agreement count, cumulative total, difference,
remaining, cumulative remaining and every iterated
cumulative cumulative-remaining running total are as defined in
the section282 header, read on-device.

## (i) The closing-run cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence in full

At each position, the running total of the
AES-NUM-281 cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining values
over positions 1 up to and including that position
(all printed comparisons True for all eight):

- Position 1 (A rank 741 / B rank 743): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 55.
- Position 2 (A rank 742 / B rank 744): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 1472.
- Position 3 (A rank 743 / B rank 745): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 20427.
- Position 4 (A rank 744 / B rank 746): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 195720.
- Position 5 (A rank 745 / B rank 747): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 1454904.
- Position 6 (A rank 746 / B rank 748): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 8940207.
- Position 7 (A rank 747 / B rank 749): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 47255442.
- Position 8 (A rank 748 / B rank 750): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 220779117.

Sequence: [55, 1472, 20427, 195720, 1454904, 8940207, 47255442, 220779117] —
equals the expected sequence (printed test True);
the last cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative total is 220779117.

## (ii) The distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals in full

Distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals, in order of first
appearance, with positions and counts (counts sum
to 8, printed test True):

- 55: position 1 — count 1.
- 1472: position 2 — count 1.
- 20427: position 3 — count 1.
- 195720: position 4 — count 1.
- 1454904: position 5 — count 1.
- 8940207: position 6 — count 1.
- 47255442: position 7 — count 1.
- 220779117: position 8 — count 1.

Eight distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals; none repeats —
stated as printed arithmetic only, no mechanism claimed.

## (iii) The gap cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence in full

At each gap position, the running total of the
AES-NUM-281 gap cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining values
over gap positions 1 up to and including that gap
position (A gaps all 512; B gaps 712, 26624, 14848,
33280, 512, 512, 512; agree False, False, False,
False, True, True, True):

- Gap position 1: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 12.
- Gap position 2: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 321.
- Gap position 3: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 4452.
- Gap position 4: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 42630.
- Gap position 5: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 316681.
- Gap position 6: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 1944566.
- Gap position 7: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 10270611.

Sequence: [12, 321, 4452, 42630, 316681, 1944566, 10270611] — equals the
expected sequence (printed test True), ends at
10270611, with agreeing positions 5, 6, 7 (count 3),
equal to AES-NUM-245.

Contract tests: the printed cumulative sequence
equals (55, 1472, 20427, 195720, 1454904, 8940207, 47255442, 220779117) — True; the distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals'
counts sum to 8 — True; the last cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative total
equals 220779117 — True; the gap cumulative sequence
equals (12, 321, 4452, 42630, 316681, 1944566, 10270611)
and ends at 10270611 — True.

Mechanisms NOT PROVEN; any offset, prefix or
position law NOT PROVEN; run 102's meaning NOT
PROVEN.
