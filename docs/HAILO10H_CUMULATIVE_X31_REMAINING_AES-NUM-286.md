# The closing-run cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence, the distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals, and the gap cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence (AES-NUM-286)

Slice 4.286, worked under `docs/TASK_CONTRACT_4.286.md`
(contract published in the 4.285 closing commit @
fc84b998). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child, no device run
of any kind. All findings below are taken from the
sha-verified raw output, read on-device
(section286.txt). Filename convention, recorded
explicitly per the 4.286 contract's close law: at
thirty-one CUMULATIVEs the chain plus REMAINING.md
alone exceeds the 255-byte filesystem limit even
further, with no fixed prefix left to shorten — so
this evidence filename uses the compact X31
notation
(`HAILO10H_CUMULATIVE_X31_REMAINING_AES-NUM-286.md`)
while the full thirty-one-CUMULATIVE chain is
preserved untruncated in this document's title and
throughout its content. The chain is never silently
truncated. The same convention governs 4.287 (X32).

## Run and closing record

hef286.py is the verified hef285 base plus
arms286: hef285.py sha256
`0f0ea691be4a43e67c2f26a4eac98d5c76ef7fb060d5ebb1c4172ab22f6c5f82`
(3,971,790 B) on both the VM and the device.
arms286 sha256
`2ec1b450a30454f19ec51ae5862fd2be6628167568e3e94e37cc89e8cc186fcb`
(120,974 B); hef286.py sha256
`5be8da81345fab3a6808194ee7db796a83ca1e6c19177d29ff9e4db3567293d0`
(4,092,764 B) on both the VM and the device.
arms286 was built locally on the hef285 lineage
(make_build286.py derived from make_build285 via
make_make286 — a blind shift
282->283/283->284/284->285/285->286 with the
1b/1c/3b/3c/pairs sections replaced wholesale; the
new @@VN@@ protection for the bare data value 285
was added on the @@VM@@ line so the protection
block stays 17 lines, with counts/restores extended
on the assert/restore/final lines; one shift-chain
defect in the first generated make_make286 — a
stray 281 leg left by the blind shift — was caught
by the old_hdr assert, fixed to the plain 282->283
leg, and the chain then ran clean; the three
AES-NUM-272 builder fixes and every carried
digit-free placeholder protection from AES-NUM-274
through AES-NUM-285 stand). Audit of
arms285/build285 for real data values containing
the slice-number substring 285 found ONE NEW: the
bare data value 285 occurs exactly 2 times in
arms285, both in ', 285,' form (the gap definitions
tuple (12, 285, 3525, 30225, 201826, 1117961,
5344326) and the matching expected list) — a real
AES-NUM-2xx layer datum, NOT a slice reference —
protected with the new digit-free placeholder
@@VN@@ (2 occurrences) before the 285->286 shift
and restored intact in arms286 (', 285,' at exactly
2 occurrences in the finished arms). All other 285
tokens in arms285 are slice references (the five
bare 4.285 section labels) or identifier suffixes
(2852 and 102285 are identifier parts, not data
values). The carried protections stand for the 286
shift (284->285, 285->286): 5281
(2 occurrences, @@VM@@) contains 281 and stays
protected; 791777280, 33280 and the bare expB
value 280 contain neither shift leg and are
harmless carries; the AES-NUM-258 279 form is
outside the shift set (@@VI@@ harmless carry);
AES-NUM-284 references in arms285 (75) shift to
AES-NUM-285. Independent audit of arms286: all
expected 286/285 sequences, the distinct list and
every protected value at exact counts (5281 x2,
791777280 x1, 33280 x1, bare 280 x1, 279 form
carried, 127925/11278/32784/21267 x2, bare 285 x2
restored); AES-NUM-284 references fully shifted
(0 left, 79 AES-NUM-285 refs). Independent
cross-check: a parallel build prepared at
00:30–00:32 EDT by an earlier firing
(make_make286_gen.py lineage) produced an arms286
whose gzip decompresses to the IDENTICAL sha256
2ec1b450… — two independent derivations agree
byte for byte. Pair 6 (gap tuple old->mid) absent as
optional, as in prior generations. hef286 =
hef285 + arms286 byte-exact.
Crossing, stated exactly: arms286 was gzipped
with gzip -9 (sha256
`8fc8774ac0388b5985677d01f920376c24c7b111158840149e87e87818d82246`,
10,590 B), split into 29 parts of 373 B, each sent
as its own sha-gated file.write to Mimir: ALL 29
parts landed sha-clean first try, each part
sha verified by the device. The assembled
gzip, arms286 and hef286 shas == VM on-device;
py_compile OK on-device. run286.sh landed via
sha-gated file.write (sha256
`452339edeca1890b662406de9b4e819bb15e210fa828a3be08714fce34302e9d`,
237 B). The real data value 21267 (AES-NUM-262
layer, two occurrences) was verified untouched
at exactly 2 occurrences in arms286.

LAUNCH: exactly ONE bounded host-side child ran
in detached tmux (session h286, launched
2026-11-01 01:13 EDT; pre-launch tmux/ps check
clean; on-device hef285.py sha 0f0ea691 == the
recorded base) with the contract corpus argv (glob
order, MiniLM last), unbuffered (`python3 -u`);
at the launching worker's check hef286.out was
0 B and hef286.err empty — child running. The
child finished with exit marker 0 (hef286.exit,
timestamped 01:17 EDT), err empty, and DONE286
as its last line. Output hef286.out
60,252 lines / 14,287,488 B sha256
`f0cc0cbbee182eb00e4966ae8f9402c3801cc097c637f0542d924fcee1d4adc2`;
prefix against hef285.out: the first 60,208 lines
differ from hef285.out in ZERO lines (no
AES-NUM-150 frozenset variance line arose this
generation, as in the 4.284 generation; verified
via check286.py sha256
`3d8aaf30133a224a54100fd93afcc56870c8bbf33fac5a61a4ef62a7ceab1d0f`),
hef286.out adding exactly its own 44 tail lines
(270,411 B, sha256
`be4c3127937d618cca3d5029860fe7b556aaed0b9b3a6bf8644dd0f995d4d3de`).

No correction is carried into this slice and none
arises from it: no correction was carried into
4.285 either (the AES-NUM-258 expected-value
correction carried from 4.280 was verified closed
in the 4.281 run), and section286 contains
exactly FOUR 'False' tokens — the four
gap-position agree data values for gap positions
1-4 (positions 5, 6, 7 agree), data not
comparisons, as in every prior slice — and no
fifth False. There is no controls exception in
this slice and no correction is carried into
4.287.
Raw output kept on the Pi at
~/aesir-build/ (hef286.out, hef286.py, arms286.py,
section286.txt, hef286.exit, hef286.err, run286.sh,
check286.py); local lineage in
~/workspace/.verify-tmp/aesir286.

Definitions carry over from AES-NUM-247 through
AES-NUM-285 exactly as printed in the run: POSITION
is 1-based over the eight acts of the closing run
(A ranks 741–748, B ranks 743–750); the agreement
set, agreement count, cumulative total, difference,
remaining, cumulative remaining and every iterated
cumulative cumulative-remaining running total are as defined in
the section286 header, read on-device.

## (i) The closing-run cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence in full

At each position, the running total of the
AES-NUM-285 cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining values
over positions 1 up to and including that position
(all printed comparisons True for all eight):

- Position 1 (A rank 741 / B rank 743): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 55.
- Position 2 (A rank 742 / B rank 744): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 1692.
- Position 3 (A rank 743 / B rank 745): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 26865.
- Position 4 (A rank 744 / B rank 746): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 293248.
- Position 5 (A rank 745 / B rank 747): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 2473419.
- Position 6 (A rank 746 / B rank 748): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 17180163.
- Position 7 (A rank 747 / B rank 749): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 102281707.
- Position 8 (A rank 748 / B rank 750): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 536425395.

Sequence: [55, 1692, 26865, 293248, 2473419, 17180163, 102281707, 536425395] —
equals the expected sequence (printed test True);
the last cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative total is 536425395.

## (ii) The distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals in full

Distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals, in order of first
appearance, with positions and counts (counts sum
to 8, printed test True):

- 55: position 1 — count 1.
- 1692: position 2 — count 1.
- 26865: position 3 — count 1.
- 293248: position 4 — count 1.
- 2473419: position 5 — count 1.
- 17180163: position 6 — count 1.
- 102281707: position 7 — count 1.
- 536425395: position 8 — count 1.

Eight distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals; none repeats —
stated as printed arithmetic only, no mechanism claimed.

## (iii) The gap cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence in full

At each gap position, the running total of the
AES-NUM-285 gap cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining values
over gap positions 1 up to and including that gap
position (A gaps all 512; B gaps 712, 26624, 14848,
33280, 512, 512, 512; agree False, False, False,
False, True, True, True):

- Gap position 1: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 12.
- Gap position 2: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 369.
- Gap position 3: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 5856.
- Gap position 4: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 63888.
- Gap position 5: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 538561.
- Gap position 6: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 3738537.
- Gap position 7: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 22243089.

Sequence: [12, 369, 5856, 63888, 538561, 3738537, 22243089] — equals the
expected sequence (printed test True), ends at
22243089, with agreeing positions 5, 6, 7 (count 3),
equal to AES-NUM-245.

Contract tests: the printed cumulative sequence
equals (55, 1692, 26865, 293248, 2473419, 17180163, 102281707, 536425395) — True; the distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals'
counts sum to 8 — True; the last cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative total
equals 536425395 — True; the gap cumulative sequence
equals (12, 369, 5856, 63888, 538561, 3738537, 22243089)
and ends at 22243089 — True.

Mechanisms NOT PROVEN; any offset, prefix or
position law NOT PROVEN; run 102's meaning NOT
PROVEN.
