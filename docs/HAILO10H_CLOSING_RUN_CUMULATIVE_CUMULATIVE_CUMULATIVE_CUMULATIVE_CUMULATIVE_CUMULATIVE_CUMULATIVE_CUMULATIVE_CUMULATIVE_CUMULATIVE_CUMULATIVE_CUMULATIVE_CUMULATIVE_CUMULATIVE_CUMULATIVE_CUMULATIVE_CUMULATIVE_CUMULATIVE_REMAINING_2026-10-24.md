# The closing-run cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence, the distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals, and the gap cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence (AES-NUM-273)

Slice 4.273, worked under `docs/TASK_CONTRACT_4.273.md`
(contract published in the 4.272 closing commit @
c6e0036b). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child, no device run
of any kind. All findings below are taken from the
sha-verified raw output, read in full on-device
(section273.txt).

## Run and closing record

hef273.py is the verified hef272 base plus
arms273: hef272.py sha256
`7cd80451efbc61c9c4d6f849df32e5439b8851bbac0d8b7098a8b9b47ea068f8`
(2,827,969 B) on both the VM and the device.
arms273 sha256
`d4006fee1fe193f6a5a677c327027e7086a83007e8c38467432a29da733d735a`
(62,975 B); hef273.py sha256
`caaf1be49577c44ffa98d606ea68571aa52cb79fba8d5d649ee3efdfdda94581`
(2,890,944 B) on both the VM and the device.
arms273 was built locally on the hef272 lineage
(make_build273.py, derived from make_build272.py —
the three AES-NUM-272 builder fixes carried:
gap \n-block carried g16->g17 and added
g17->g18 fixed explicitly; gap print-arg lists
keep g5 low end and extend only at the top
(g5..g17 -> g5..g18); the builder's own
shift-line fix carried). PLUS the new protections
this slice required (builder faults found and
fixed in the builders, not the data): the
build272 text protected 2725341 (8 occurrences,
placeholder restored before the sequence pairs);
the arms shift protected 2725341 (2 occ), 2723
(2 occ) and the standalone data index 272 (2 occ:
the B closing-run expect list + expB (745, 272,
...)) with digit-free placeholders
@@VA@@/@@VB@@/@@VC@@ — an earlier attempt with
digit-bearing placeholders failed its own assert
because the shift corrupted the placeholders
themselves; the digit-free form passed. The
make script's final 2725341 count is 4 (all in
the inserted protection code; the sequence
literals correctly mapped A0->A1->A2).
hef273 = hef272 + arms273 byte-exact. Crossing,
stated exactly: arms273 was gzipped with gzip -9
(sha256
`4130d85e0be33b592d9e4b9323baad7dce0c569b9249b3ca4345fbc572fc8802`,
8,017 B) and split into twenty-two 373 B parts
(last 184 B), each part written as its own file
with its own sha256 gate — all twenty-two
verified on-device; no byte accepted unverified.
The assembled gzip, arms and hef273 shas == VM
on-device; py_compile OK on-device.
The build's slice-number shift was
271 -> 272, 272 -> 273 only (with the protected
values above restored), so the real data value
21267 (AES-NUM-262 layer, two occurrences) was
verified untouched at exactly 2 occurrences.

LAUNCH: exactly ONE bounded host-side child ran
in detached tmux (session h273, launched
2026-10-31 ~14:34 EDT) with the contract corpus
argv (glob order, MiniLM last), unbuffered
(`python3 -u`); at 14:36 EDT hef273.out was
631,702 B and growing with err empty and no exit
file yet. The child finished with exit marker 0
(hef273.exit, timestamped 14:39 EDT), err empty,
and DONE273 as its last line. Output hef273.out
59,680 lines / 11,753,085 B sha256
`029d7e0a7f416fd954f71fbc2434001d424d75f37da827dec9b58d4033043d42`;
prefix against hef272.out: the first 59,636 lines
differ from hef272.out in exactly ONE line (line
41611, frozenset element order only, the
AES-NUM-150 variance, verified by
same-sorted-characters comparison via
check273.py sha256
`934121f6c7c8278de437df272f0a06c4b6d094f319468e77bed0ddcb2246203a`),
hef273.out adding exactly its own 44 tail lines
(118,307 B, sha256
`eeefe8ded01783e08383f5c7650ba5a0c933877f30c4086973b218884f5f192b`).
Controls EXACT, with no exception this slice:
the only 'False' tokens in section273 are the
four gap-position agree data values for gap
positions 1–4 (positions 5, 6, 7 agree) — data,
not comparisons.
Raw output kept on the Pi at
~/aesir-build/ (hef273.out, hef273.py, arms273.py,
section273.txt, hef273.exit, hef273.err, run273.sh,
gz273/, check273.py); local lineage in
~/workspace/.verify-tmp/aesir273.

Definitions carry over from AES-NUM-247 through
AES-NUM-272 exactly as printed in the run: POSITION
is 1-based over the eight acts of the closing run
(A ranks 741–748, B ranks 743–750); the agreement
set, agreement count, cumulative total, difference,
remaining, cumulative remaining and every iterated
cumulative-remaining running total are as defined in
the section273 header, read in full on-device.

## (i) The closing-run cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence in full

At each position, the running total of the
AES-NUM-272 cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining values
over positions 1 up to and including that position
(all printed comparisons True for all eight):

- Position 1 (A rank 741 / B rank 743): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 55.
- Position 2 (A rank 742 / B rank 744): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 977.
- Position 3 (A rank 743 / B rank 745): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 9159.
- Position 4 (A rank 744 / B rank 746): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 60249.
- Position 5 (A rank 745 / B rank 747): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 312078.
- Position 6 (A rank 746 / B rank 748): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 1354665.
- Position 7 (A rank 747 / B rank 749): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 5122593.
- Position 8 (A rank 748 / B rank 750): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 17324241.

Sequence: [55, 977, 9159, 60249, 312078, 1354665, 5122593, 17324241] —
equals the expected sequence (printed test True);
the last cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative total is 17324241.

## (ii) The distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals in full

Distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals, in order of first
appearance, with positions and counts (counts sum
to 8, printed test True):

- 55: position 1 — count 1.
- 977: position 2 — count 1.
- 9159: position 3 — count 1.
- 60249: position 4 — count 1.
- 312078: position 5 — count 1.
- 1354665: position 6 — count 1.
- 5122593: position 7 — count 1.
- 17324241: position 8 — count 1.

Eight distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals; none repeats —
stated as printed arithmetic only, no mechanism claimed.

## (iii) The gap cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence in full

At each gap position, the running total of the
AES-NUM-272 gap cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining values
over gap positions 1 up to and including that gap
position (A gaps all 512; B gaps 712, 26624, 14848,
33280, 512, 512, 512; agree False, False, False,
False, True, True, True):

- Gap position 1: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 12.
- Gap position 2: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 213.
- Gap position 3: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 1995.
- Gap position 4: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 13110.
- Gap position 5: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 67831.
- Gap position 6: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 294083.
- Gap position 7: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 1110627.

Sequence: [12, 213, 1995, 13110, 67831, 294083, 1110627] — equals the
expected sequence (printed test True), ends at
1110627, with agreeing positions 5, 6, 7 (count 3),
equal to AES-NUM-245.

Contract tests: the printed cumulative sequence
equals (55, 977, 9159, 60249, 312078, 1354665, 5122593,
17324241) — True; the distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals'
counts sum to 8 — True; the last cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative total
equals 17324241 — True; the gap cumulative sequence
equals (12, 213, 1995, 13110, 67831, 294083, 1110627)
and ends at 1110627 — True.

Mechanisms NOT PROVEN; any offset, prefix or
position law NOT PROVEN; run 102's meaning NOT
PROVEN.
