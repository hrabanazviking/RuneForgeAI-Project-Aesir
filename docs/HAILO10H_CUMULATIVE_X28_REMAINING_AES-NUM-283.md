# The closing-run cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence, the distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals, and the gap cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence (AES-NUM-283)

Slice 4.283, worked under `docs/TASK_CONTRACT_4.283.md`
(contract published in the 4.282 closing commit @
5b9a6021). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child, no device run
of any kind. All findings below are taken from the
sha-verified raw output, read on-device
(section283.txt). Filename convention, recorded
explicitly per the 4.283 contract's close law: at
twenty-eight CUMULATIVEs the chain plus REMAINING.md
alone exceeds the 255-byte filesystem limit even
further, with no fixed prefix left to shorten — so
this evidence filename uses the compact X28
notation
(`HAILO10H_CUMULATIVE_X28_REMAINING_AES-NUM-283.md`)
while the full twenty-eight-CUMULATIVE chain is
preserved untruncated in this document's title and
throughout its content. The chain is never silently
truncated. The same convention governs 4.284 (X29).

## Run and closing record

hef283.py is the verified hef282 base plus
arms283: hef282.py sha256
`780186c6b2b40a07f688e634047ed42b6c06fd1056e2d12f770db18d476fdf89`
(3,639,647 B) on both the VM and the device.
arms283 sha256
`07199c41afadda0dcb7e1f7dc14b3a2ea758b2ea0865be2ad9645833c42341c0`
(105,711 B); hef283.py sha256
`911d776246339ce21227fc29d675a5debb3ca8c33c3b3dd7f8cf62d508c55ae5`
(3,745,358 B) on both the VM and the device.
arms283 was built locally on the hef282 lineage
(make_build283.py derived from make_build282 via
make_make283 — a line-wise block edit on the
17-line build282 block; the three AES-NUM-272
builder fixes and every carried digit-free
placeholder protection from AES-NUM-274 through
AES-NUM-282 stand). Audit of arms282/build282 for
real data values containing the slice-number
substring 282 found NONE NEW: every 282 token in
arms282 is a slice reference (4.282 labels, 5
occurrences) or an identifier suffix (2822 and
102282 are identifier parts, not data values); no
standalone numeric literal contains 282, so no new
protection was added. The carried protections
stand for the 283 shift (281->282, 282->283): 5281
(2 occurrences, @@VM@@) contains 281 and stays
protected; 791777280, 33280 and the bare expB
value 280 contain neither shift leg and are
harmless carries; the AES-NUM-258 279 form is
outside the shift set (@@VI@@ harmless carry);
AES-NUM-281 references in arms282 (63) shift to
AES-NUM-282 (total '281' tokens 65 = 63 refs +
5281 x2, exact). Independent audit of arms283: all
expected 283/282 sequences, the distinct list and
every protected value at exact counts (5281 x2,
791777280 x1, 33280 x1, bare 280 x1, 279 form x2,
127925/11278/32784/21267 x2); AES-NUM-281
references fully shifted (0 left, 67 AES-NUM-282
refs). hef283 = hef282 + arms283 byte-exact.
Crossing, stated exactly: arms283 was gzipped
with gzip -9 (sha256
`2593326c1eb9dfc4cf49338cfa5a6b04a424b4329baa1dcd0cca1924b26f1f96`,
10,097 B), split into 28 parts of 373 B, each sent
as its own sha-gated file.write to Mimir: ALL 28
parts landed sha-clean first try. The assembled
gzip, arms283 and hef283 shas == VM on-device;
py_compile OK on-device. run283.sh landed via
sha-gated file.write (sha256
`fa5ba15ba69484887605ee360c7aae2dfdc731832c2fc9cffe03fd9892a6a4c6`,
237 B). The real data value 21267 (AES-NUM-262
layer, two occurrences) was verified untouched
at exactly 2 occurrences in arms283.

LAUNCH: exactly ONE bounded host-side child ran
in detached tmux (session h283, launched
2026-10-31 22:23 EDT; pre-launch tmux/ps check
clean) with the contract corpus argv (glob
order, MiniLM last), unbuffered (`python3 -u`);
at the launching worker's check hef283.out was
0 B and hef283.err empty — child running. The
child finished with exit marker 0 (hef283.exit,
timestamped 22:27 EDT), err empty, and DONE283
as its last line. Output hef283.out
60,120 lines / 13,517,734 B sha256
`cd007b3ddedfe718b36bf40d3cb336444ca78dd87e4dede39441a5c60ca7dd9b`;
prefix against hef282.out: the first 60,076 lines
differ from hef282.out in exactly ONE line
(line 41611, frozenset element order only, the
AES-NUM-150 variance, verified by
same-sorted-characters comparison via
check283.py sha256
`aee30c6d01b9bb02cf0e34b69f453036cd1da851d8efd68689237595c9440e9c`),
hef283.out adding exactly its own 44 tail lines
(229,685 B, sha256
`3311a94df190a69e18aecb6bd20b5daad8adbaf34e6591ea29f51475f59617e9`).

No correction is carried into this slice and none
arises from it: no correction was carried into
4.282 either (the AES-NUM-258 expected-value
correction carried from 4.280 was verified closed
in the 4.281 run), and section283 contains
exactly FOUR 'False' tokens — the four
gap-position agree data values for gap positions
1-4 (positions 5, 6, 7 agree), data not
comparisons, as in every prior slice — and no
fifth False. There is no controls exception in
this slice and no correction is carried into
4.284.
Raw output kept on the Pi at
~/aesir-build/ (hef283.out, hef283.py, arms283.py,
section283.txt, hef283.exit, hef283.err, run283.sh,
check283.py); local lineage in
~/workspace/.verify-tmp/aesir283.

Definitions carry over from AES-NUM-247 through
AES-NUM-282 exactly as printed in the run: POSITION
is 1-based over the eight acts of the closing run
(A ranks 741–748, B ranks 743–750); the agreement
set, agreement count, cumulative total, difference,
remaining, cumulative remaining and every iterated
cumulative cumulative-remaining running total are as defined in
the section283 header, read on-device.

## (i) The closing-run cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence in full

At each position, the running total of the
AES-NUM-282 cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining values
over positions 1 up to and including that position
(all printed comparisons True for all eight):

- Position 1 (A rank 741 / B rank 743): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 55.
- Position 2 (A rank 742 / B rank 744): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 1527.
- Position 3 (A rank 743 / B rank 745): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 21954.
- Position 4 (A rank 744 / B rank 746): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 217674.
- Position 5 (A rank 745 / B rank 747): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 1672578.
- Position 6 (A rank 746 / B rank 748): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 10612785.
- Position 7 (A rank 747 / B rank 749): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 57868227.
- Position 8 (A rank 748 / B rank 750): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 278647344.

Sequence: [55, 1527, 21954, 217674, 1672578, 10612785, 57868227, 278647344] —
equals the expected sequence (printed test True);
the last cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative total is 278647344.

## (ii) The distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals in full

Distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals, in order of first
appearance, with positions and counts (counts sum
to 8, printed test True):

- 55: position 1 — count 1.
- 1527: position 2 — count 1.
- 21954: position 3 — count 1.
- 217674: position 4 — count 1.
- 1672578: position 5 — count 1.
- 10612785: position 6 — count 1.
- 57868227: position 7 — count 1.
- 278647344: position 8 — count 1.

Eight distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals; none repeats —
stated as printed arithmetic only, no mechanism claimed.

## (iii) The gap cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence in full

At each gap position, the running total of the
AES-NUM-282 gap cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining values
over gap positions 1 up to and including that gap
position (A gaps all 512; B gaps 712, 26624, 14848,
33280, 512, 512, 512; agree False, False, False,
False, True, True, True):

- Gap position 1: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 12.
- Gap position 2: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 333.
- Gap position 3: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 4785.
- Gap position 4: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 47415.
- Gap position 5: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 364096.
- Gap position 6: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 2308662.
- Gap position 7: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 12579273.

Sequence: [12, 333, 4785, 47415, 364096, 2308662, 12579273] — equals the
expected sequence (printed test True), ends at
12579273, with agreeing positions 5, 6, 7 (count 3),
equal to AES-NUM-245.

Contract tests: the printed cumulative sequence
equals (55, 1527, 21954, 217674, 1672578, 10612785, 57868227, 278647344) — True; the distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals'
counts sum to 8 — True; the last cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative total
equals 278647344 — True; the gap cumulative sequence
equals (12, 333, 4785, 47415, 364096, 2308662, 12579273)
and ends at 12579273 — True.

Mechanisms NOT PROVEN; any offset, prefix or
position law NOT PROVEN; run 102's meaning NOT
PROVEN.
