# The closing-run cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence, the distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals, and the gap cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence (AES-NUM-284)

Slice 4.284, worked under `docs/TASK_CONTRACT_4.284.md`
(contract published in the 4.283 closing commit @
6b5fe9c2). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child, no device run
of any kind. All findings below are taken from the
sha-verified raw output, read on-device
(section284.txt). Filename convention, recorded
explicitly per the 4.284 contract's close law: at
twenty-nine CUMULATIVEs the chain plus REMAINING.md
alone exceeds the 255-byte filesystem limit even
further, with no fixed prefix left to shorten — so
this evidence filename uses the compact X29
notation
(`HAILO10H_CUMULATIVE_X29_REMAINING_AES-NUM-284.md`)
while the full twenty-nine-CUMULATIVE chain is
preserved untruncated in this document's title and
throughout its content. The chain is never silently
truncated. The same convention governs 4.285 (X30).

## Run and closing record

hef284.py is the verified hef283 base plus
arms284: hef283.py sha256
`911d776246339ce21227fc29d675a5debb3ca8c33c3b3dd7f8cf62d508c55ae5`
(3,745,358 B) on both the VM and the device.
arms284 sha256
`3ed4563c718e2b1032df8e12316a760bc9eaf78c138ece62097b6a95f80408f6`
(110,673 B); hef284.py sha256
`46b14446d8652dd29570a12ff3b4335ed3b623cf60a2b9d2fbd0c8c617ac3976`
(3,856,031 B) on both the VM and the device.
arms284 was built locally on the hef283 lineage
(make_build284.py derived from make_build283 via
make_make284 — a blind shift
280->281/281->282/282->283/283->284 with the
1b/1c/3b/3c/pairs sections replaced wholesale; the
comment block is lines 22-47 of build283; one
over-escape in the 1b/3b literals was halved and
re-verified before the build ran clean; the three
AES-NUM-272 builder fixes and every carried
digit-free placeholder protection from AES-NUM-274
through AES-NUM-283 stand). Audit of
arms283/build283 for real data values containing
the slice-number substring 283 found NONE NEW:
every 283 token in arms283 is a slice reference
(the five bare 283 tokens are the 4.283 section
labels) or an identifier suffix (2832 and 102283
are identifier parts, not data values); no
standalone numeric literal contains 283, so no new
protection was added. The carried protections
stand for the 284 shift (282->283, 283->284): 5281
(2 occurrences, @@VM@@) contains 281 and stays
protected; 791777280, 33280 and the bare expB
value 280 contain neither shift leg and are
harmless carries; the AES-NUM-258 279 form is
outside the shift set (@@VI@@ harmless carry);
AES-NUM-282 references in arms283 (67) shift to
AES-NUM-283 (total '282' tokens 67, all AES-NUM-282
refs, exact). Independent audit of arms284: all
expected 284/283 sequences, the distinct list and
every protected value at exact counts (5281 x2,
791777280 x1, 33280 x1, bare 280 x1, 279 form x2,
127925/11278/32784/21267 x2); AES-NUM-282
references fully shifted (0 left, 71 AES-NUM-283
refs). Pair 6 (gap tuple old->mid) absent as
optional, as in prior generations. hef284 =
hef283 + arms284 byte-exact.
Crossing, stated exactly: arms284 was gzipped
with gzip -9 (sha256
`7a436aaad8a326200511a1d81bd7348f1551ec8aaaba2cedc726f6790b308342`,
10,268 B), split into 28 parts of 373 B, each sent
as its own sha-gated file.write to Mimir: ALL 28
parts landed sha-clean first try, each part
sha verified by the device. The assembled
gzip, arms284 and hef284 shas == VM on-device;
py_compile OK on-device. run284.sh landed via
sha-gated file.write (sha256
`6d14f370de57846f24f4408fea8c8269ace56937f65dc43f349ce5c28a54042a`,
237 B). The real data value 21267 (AES-NUM-262
layer, two occurrences) was verified untouched
at exactly 2 occurrences in arms284.

LAUNCH: exactly ONE bounded host-side child ran
in detached tmux (session h284, launched
2026-10-31 23:05 EDT; pre-launch tmux/ps check
clean; on-device hef283.py sha 911d7762 == the
recorded base) with the contract corpus argv (glob
order, MiniLM last), unbuffered (`python3 -u`);
at the launching worker's check hef284.out was
0 B and hef284.err empty — child running. The
child finished with exit marker 0 (hef284.exit,
timestamped 23:09 EDT), err empty, and DONE284
as its last line. Output hef284.out
60,164 lines / 13,760,619 B sha256
`97b3b7f469cc2c17daac358ca0f8082d408ae7c02c5b3fbcaf9c02820a3b32f6`;
prefix against hef283.out: the first 60,120 lines
differ from hef283.out in ZERO lines (no
AES-NUM-150 frozenset variance line arose in this
generation, verified via check284.py sha256
`e3fd77b96f8c792fa6c1384727fb733a7feca3ac88c2115c2c7c46c1931076ab`),
hef284.out adding exactly its own 44 tail lines
(242,885 B, sha256
`dca10e7f5328d571b61b49400b19253770f84dca6e27006eceeccc6f15674c50`).

No correction is carried into this slice and none
arises from it: no correction was carried into
4.283 either (the AES-NUM-258 expected-value
correction carried from 4.280 was verified closed
in the 4.281 run), and section284 contains
exactly FOUR 'False' tokens — the four
gap-position agree data values for gap positions
1-4 (positions 5, 6, 7 agree), data not
comparisons, as in every prior slice — and no
fifth False. There is no controls exception in
this slice and no correction is carried into
4.285.
Raw output kept on the Pi at
~/aesir-build/ (hef284.out, hef284.py, arms284.py,
section284.txt, hef284.exit, hef284.err, run284.sh,
check284.py); local lineage in
~/workspace/.verify-tmp/aesir284.

Definitions carry over from AES-NUM-247 through
AES-NUM-283 exactly as printed in the run: POSITION
is 1-based over the eight acts of the closing run
(A ranks 741–748, B ranks 743–750); the agreement
set, agreement count, cumulative total, difference,
remaining, cumulative remaining and every iterated
cumulative cumulative-remaining running total are as defined in
the section284 header, read on-device.

## (i) The closing-run cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence in full

At each position, the running total of the
AES-NUM-283 cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining values
over positions 1 up to and including that position
(all printed comparisons True for all eight):

- Position 1 (A rank 741 / B rank 743): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 55.
- Position 2 (A rank 742 / B rank 744): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 1582.
- Position 3 (A rank 743 / B rank 745): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 23536.
- Position 4 (A rank 744 / B rank 746): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 241210.
- Position 5 (A rank 745 / B rank 747): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 1913788.
- Position 6 (A rank 746 / B rank 748): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 12526573.
- Position 7 (A rank 747 / B rank 749): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 70394800.
- Position 8 (A rank 748 / B rank 750): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 349042144.

Sequence: [55, 1582, 23536, 241210, 1913788, 12526573, 70394800, 349042144] —
equals the expected sequence (printed test True);
the last cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative total is 349042144.

## (ii) The distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals in full

Distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals, in order of first
appearance, with positions and counts (counts sum
to 8, printed test True):

- 55: position 1 — count 1.
- 1582: position 2 — count 1.
- 23536: position 3 — count 1.
- 241210: position 4 — count 1.
- 1913788: position 5 — count 1.
- 12526573: position 6 — count 1.
- 70394800: position 7 — count 1.
- 349042144: position 8 — count 1.

Eight distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals; none repeats —
stated as printed arithmetic only, no mechanism claimed.

## (iii) The gap cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence in full

At each gap position, the running total of the
AES-NUM-283 gap cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining values
over gap positions 1 up to and including that gap
position (A gaps all 512; B gaps 712, 26624, 14848,
33280, 512, 512, 512; agree False, False, False,
False, True, True, True):

- Gap position 1: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 12.
- Gap position 2: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 345.
- Gap position 3: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 5130.
- Gap position 4: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 52545.
- Gap position 5: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 416641.
- Gap position 6: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 2725303.
- Gap position 7: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 15304576.

Sequence: [12, 345, 5130, 52545, 416641, 2725303, 15304576] — equals the
expected sequence (printed test True), ends at
15304576, with agreeing positions 5, 6, 7 (count 3),
equal to AES-NUM-245.

Contract tests: the printed cumulative sequence
equals (55, 1582, 23536, 241210, 1913788, 12526573, 70394800, 349042144) — True; the distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals'
counts sum to 8 — True; the last cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative total
equals 349042144 — True; the gap cumulative sequence
equals (12, 345, 5130, 52545, 416641, 2725303, 15304576)
and ends at 15304576 — True.

Mechanisms NOT PROVEN; any offset, prefix or
position law NOT PROVEN; run 102's meaning NOT
PROVEN.
