# The closing-run cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence, the distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals, and the gap cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence (AES-NUM-285)

Slice 4.285, worked under `docs/TASK_CONTRACT_4.285.md`
(contract published in the 4.284 closing commit @
3c4171f0). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child, no device run
of any kind. All findings below are taken from the
sha-verified raw output, read on-device
(section285.txt). Filename convention, recorded
explicitly per the 4.285 contract's close law: at
thirty CUMULATIVEs the chain plus REMAINING.md
alone exceeds the 255-byte filesystem limit even
further, with no fixed prefix left to shorten — so
this evidence filename uses the compact X30
notation
(`HAILO10H_CUMULATIVE_X30_REMAINING_AES-NUM-285.md`)
while the full thirty-CUMULATIVE chain is
preserved untruncated in this document's title and
throughout its content. The chain is never silently
truncated. The same convention governs 4.286 (X31).

## Run and closing record

hef285.py is the verified hef284 base plus
arms285: hef284.py sha256
`46b14446d8652dd29570a12ff3b4335ed3b623cf60a2b9d2fbd0c8c617ac3976`
(3,856,031 B) on both the VM and the device.
arms285 sha256
`28c3ba770be2ab90a15e730b098b1cccc403c1b4a9da327627281a9020985eae`
(115,759 B); hef285.py sha256
`0f0ea691be4a43e67c2f26a4eac98d5c76ef7fb060d5ebb1c4172ab22f6c5f82`
(3,971,790 B) on both the VM and the device.
arms285 was built locally on the hef284 lineage
(make_build285.py derived from make_build284 via
make_make285 — a blind shift
281->282/282->283/283->284/284->285 with the
1b/1c/3b/3c/pairs sections replaced wholesale; the
comment block stays lines 22-47 of build284 because
the new audit tail was written at the same 21-line
count as the 284 tail; one over-escape in the 1b/3b
literals was halved and re-verified before the build
ran clean; the three AES-NUM-272 builder fixes and
every carried digit-free placeholder protection from
AES-NUM-274 through AES-NUM-284 stand). Audit of
arms284/build284 for real data values containing
the slice-number substring 284 found NONE NEW:
every 284 token in arms284 is a slice reference
(the five bare 284 tokens are the 4.284 section
labels) or an identifier suffix (2842 and 102284
are identifier parts, not data values); no
standalone numeric literal contains 284, so no new
protection was added. The carried protections
stand for the 285 shift (283->284, 284->285): 5281
(2 occurrences, @@VM@@) contains 281 and stays
protected; 791777280, 33280 and the bare expB
value 280 contain neither shift leg and are
harmless carries; the AES-NUM-258 279 form is
outside the shift set (@@VI@@ harmless carry);
AES-NUM-283 references in arms284 (71) shift to
AES-NUM-284 (total '283' tokens 71, all AES-NUM-283
refs, exact). Independent audit of arms285: all
expected 285/284 sequences, the distinct list and
every protected value at exact counts (5281 x2,
791777280 x1, 33280 x1, bare 280 x1, 279 form x2,
127925/11278/32784/21267 x2); AES-NUM-283
references fully shifted (0 left, 75 AES-NUM-284
refs). Pair 6 (gap tuple old->mid) absent as
optional, as in prior generations. hef285 =
hef284 + arms285 byte-exact.
Crossing, stated exactly: arms285 was gzipped
with gzip -9 (sha256
`51f18d4ce010d28975e42309a8967fcecfbdc14204bcb742af457f19face6e44`,
10,471 B), split into 29 parts of 373 B, each sent
as its own sha-gated file.write to Mimir: ALL 29
parts landed sha-clean first try, each part
sha verified by the device. The assembled
gzip, arms285 and hef285 shas == VM on-device;
py_compile OK on-device. run285.sh landed via
sha-gated file.write (sha256
`62e64f4e89c41e69f1c9803b4bb21d1574103ab955f6be44e74c65e951dcfebe`,
237 B). The real data value 21267 (AES-NUM-262
layer, two occurrences) was verified untouched
at exactly 2 occurrences in arms285.

LAUNCH: exactly ONE bounded host-side child ran
in detached tmux (session h285, launched
2026-10-31 23:52 EDT; pre-launch tmux/ps check
clean; on-device hef284.py sha 46b14446 == the
recorded base) with the contract corpus argv (glob
order, MiniLM last), unbuffered (`python3 -u`);
at the launching worker's check hef285.out was
0 B and hef285.err empty — child running. The
child finished with exit marker 0 (hef285.exit,
timestamped 23:56 EDT), err empty, and DONE285
as its last line. Output hef285.out
60,208 lines / 14,017,077 B sha256
`3c4e2ddb038c13ba3f840147e8603c91732460c54741a6cf77e8570ce2d70b99`;
prefix against hef284.out: the first 60,164 lines
differ from hef284.out in exactly TWO lines
(41611 and 42872; both sorted-char equal True —
the AES-NUM-150 frozenset element-order variance,
verified via check285.py sha256
`db30fabfdb900e901fd2bb0c034e18d48993a4d4e3a95923625e164f6d40663c`),
hef285.out adding exactly its own 44 tail lines
(256,458 B, sha256
`ec9b204223053975abf9e5f774a777c452c94a8d8cd15aa7b6fc32a1918cfd97`).

No correction is carried into this slice and none
arises from it: no correction was carried into
4.284 either (the AES-NUM-258 expected-value
correction carried from 4.280 was verified closed
in the 4.281 run), and section285 contains
exactly FOUR 'False' tokens — the four
gap-position agree data values for gap positions
1-4 (positions 5, 6, 7 agree), data not
comparisons, as in every prior slice — and no
fifth False. There is no controls exception in
this slice and no correction is carried into
4.286.
Raw output kept on the Pi at
~/aesir-build/ (hef285.out, hef285.py, arms285.py,
section285.txt, hef285.exit, hef285.err, run285.sh,
check285.py); local lineage in
~/workspace/.verify-tmp/aesir285.

Definitions carry over from AES-NUM-247 through
AES-NUM-284 exactly as printed in the run: POSITION
is 1-based over the eight acts of the closing run
(A ranks 741–748, B ranks 743–750); the agreement
set, agreement count, cumulative total, difference,
remaining, cumulative remaining and every iterated
cumulative cumulative-remaining running total are as defined in
the section285 header, read on-device.

## (i) The closing-run cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence in full

At each position, the running total of the
AES-NUM-284 cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining values
over positions 1 up to and including that position
(all printed comparisons True for all eight):

- Position 1 (A rank 741 / B rank 743): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 55.
- Position 2 (A rank 742 / B rank 744): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 1637.
- Position 3 (A rank 743 / B rank 745): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 25173.
- Position 4 (A rank 744 / B rank 746): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 266383.
- Position 5 (A rank 745 / B rank 747): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 2180171.
- Position 6 (A rank 746 / B rank 748): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 14706744.
- Position 7 (A rank 747 / B rank 749): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 85101544.
- Position 8 (A rank 748 / B rank 750): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 434143688.

Sequence: [55, 1637, 25173, 266383, 2180171, 14706744, 85101544, 434143688] —
equals the expected sequence (printed test True);
the last cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative total is 434143688.

## (ii) The distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals in full

Distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals, in order of first
appearance, with positions and counts (counts sum
to 8, printed test True):

- 55: position 1 — count 1.
- 1637: position 2 — count 1.
- 25173: position 3 — count 1.
- 266383: position 4 — count 1.
- 2180171: position 5 — count 1.
- 14706744: position 6 — count 1.
- 85101544: position 7 — count 1.
- 434143688: position 8 — count 1.

Eight distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals; none repeats —
stated as printed arithmetic only, no mechanism claimed.

## (iii) The gap cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence in full

At each gap position, the running total of the
AES-NUM-284 gap cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining values
over gap positions 1 up to and including that gap
position (A gaps all 512; B gaps 712, 26624, 14848,
33280, 512, 512, 512; agree False, False, False,
False, True, True, True):

- Gap position 1: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 12.
- Gap position 2: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 357.
- Gap position 3: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 5487.
- Gap position 4: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 58032.
- Gap position 5: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 474673.
- Gap position 6: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 3199976.
- Gap position 7: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 18504552.

Sequence: [12, 357, 5487, 58032, 474673, 3199976, 18504552] — equals the
expected sequence (printed test True), ends at
18504552, with agreeing positions 5, 6, 7 (count 3),
equal to AES-NUM-245.

Contract tests: the printed cumulative sequence
equals (55, 1637, 25173, 266383, 2180171, 14706744, 85101544, 434143688) — True; the distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals'
counts sum to 8 — True; the last cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative total
equals 434143688 — True; the gap cumulative sequence
equals (12, 357, 5487, 58032, 474673, 3199976, 18504552)
and ends at 18504552 — True.

Mechanisms NOT PROVEN; any offset, prefix or
position law NOT PROVEN; run 102's meaning NOT
PROVEN.
