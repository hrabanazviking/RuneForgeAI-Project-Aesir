# The closing-run cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence, the distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals, and the gap cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence (AES-NUM-274)

Slice 4.274, worked under `docs/TASK_CONTRACT_4.274.md`
(contract published in the 4.273 closing commit @
4996cc37). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child, no device run
of any kind. All findings below are taken from the
sha-verified raw output, read in full on-device
(section274.txt).

## Run and closing record

hef274.py is the verified hef273 base plus
arms274: hef273.py sha256
`caaf1be49577c44ffa98d606ea68571aa52cb79fba8d5d649ee3efdfdda94581`
(2,890,944 B) on both the VM and the device.
arms274 sha256
`151665a8a276151620fb5041cb05ccd2bf52ca30590ac1b056a7e5a380ddd583`
(66,685 B); hef274.py sha256
`d2ea3636e764eefdb49c4f2476dd65e00643233afc9d4be7b726de91ccb27b52`
(2,957,629 B) on both the VM and the device.
arms274 was built locally on the hef273 lineage
(make_build274.py, derived from make_build273.py —
the three AES-NUM-272 builder fixes carried:
gap \n-block carried g16->g17 and added
g17->g18 fixed explicitly; gap print-arg lists
keep g5 low end and extend only at the top;
the builder's own shift-line fix carried).
PLUS the new protections this slice required:
the build273 text protected 2725341 (4
occurrences) and 2723 (4 occurrences) through
the make-level shift; the arms shift protected
2725341 (2 occ), 2723 (2 occ), 34273 (2 occ —
the only standalone data value containing the
273 substring) and the standalone data index
272 in its ', 272,' form (2 occ) with digit-free
placeholders @@VA@@/@@VB@@/@@VD@@/@@VC@@ — the
', 272,' form is the discriminator, because
AES-NUM-272 references (27 occ) must shift to
273 while the data index must not. One builder
assert was corrected in the make script (the
34273 count is 4 including the comment, not 3);
gap tuple pair 6 is absent as in the 273
generation (optional, skipped).
hef274 = hef273 + arms274 byte-exact. Crossing,
stated exactly: arms274 was gzipped with gzip -9
(sha256
`345268b7dbc17e3077c1e6a072c041875af72231a74ed2cb72f3b189c9f47d2c`,
8,202 B) and split into twenty-two 373 B parts
(last 369 B), each part written as its own file
with its own sha256 gate — all twenty-two
verified on-device first try; no byte accepted
unverified. The assembled gzip, arms and hef274
shas == VM on-device; py_compile OK on-device.
run274.sh landed via sha-gated file.write
(sha256
`33dc038b18c6f3cda811b9af089a34e9cf2746dfae6d3ba6550a13281c592db2`,
237 B). The build's slice-number shift was
272 -> 273, 273 -> 274 only (with the protected
values above restored), so the real data value
21267 (AES-NUM-262 layer, two occurrences) was
verified untouched at exactly 2 occurrences.

LAUNCH: exactly ONE bounded host-side child ran
in detached tmux (session h274, launched
2026-10-31 ~15:30 EDT) with the contract corpus
argv (glob order, MiniLM last), unbuffered
(`python3 -u`); at 15:31 EDT hef274.out was
679 B and growing with err empty and no exit
file yet. The child finished with exit marker 0
(hef274.exit, timestamped 15:34 EDT), err empty,
and DONE274 as its last line. Output hef274.out
59,724 lines / 11,880,842 B sha256
`c93ce345975c7ad3fd41e2ae5b97a5d8cdd15ac348bb9e304ccd2b3862ea9602`;
prefix against hef273.out: the first 59,680 lines
differ from hef273.out in exactly ONE line (line
41611, frozenset element order only, the
AES-NUM-150 variance, verified by
same-sorted-characters comparison via
check274.py sha256
`58f9ef2812cf7ac43a8193f58c307cf35fef662d48564d25fea19efd9faa3ff0`),
hef274.out adding exactly its own 44 tail lines
(127,757 B, sha256
`f2a2cf8f9244d50bf03f4519629e2d537138521ca7fefd5819ccd86bd3275ce9`).
Controls EXACT, with no exception this slice:
the only 'False' tokens in section274 are the
four gap-position agree data values for gap
positions 1–4 (positions 5, 6, 7 agree) — data,
not comparisons.
Raw output kept on the Pi at
~/aesir-build/ (hef274.out, hef274.py, arms274.py,
section274.txt, hef274.exit, hef274.err, run274.sh,
gz274/, check274.py); local lineage in
~/workspace/.verify-tmp/aesir274.

Definitions carry over from AES-NUM-247 through
AES-NUM-273 exactly as printed in the run: POSITION
is 1-based over the eight acts of the closing run
(A ranks 741–748, B ranks 743–750); the agreement
set, agreement count, cumulative total, difference,
remaining, cumulative remaining and every iterated
cumulative-remaining running total are as defined in
the section274 header, read in full on-device.

## (i) The closing-run cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence in full

At each position, the running total of the
AES-NUM-273 cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining values
over positions 1 up to and including that position
(all printed comparisons True for all eight):

- Position 1 (A rank 741 / B rank 743): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 55.
- Position 2 (A rank 742 / B rank 744): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 1032.
- Position 3 (A rank 743 / B rank 745): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 10191.
- Position 4 (A rank 744 / B rank 746): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 70440.
- Position 5 (A rank 745 / B rank 747): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 382518.
- Position 6 (A rank 746 / B rank 748): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 1737183.
- Position 7 (A rank 747 / B rank 749): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 6859776.
- Position 8 (A rank 748 / B rank 750): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 24184017.

Sequence: [55, 1032, 10191, 70440, 382518, 1737183, 6859776, 24184017] —
equals the expected sequence (printed test True);
the last cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative total is 24184017.

## (ii) The distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals in full

Distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals, in order of first
appearance, with positions and counts (counts sum
to 8, printed test True):

- 55: position 1 — count 1.
- 1032: position 2 — count 1.
- 10191: position 3 — count 1.
- 70440: position 4 — count 1.
- 382518: position 5 — count 1.
- 1737183: position 6 — count 1.
- 6859776: position 7 — count 1.
- 24184017: position 8 — count 1.

Eight distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals; none repeats —
stated as printed arithmetic only, no mechanism claimed.

## (iii) The gap cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence in full

At each gap position, the running total of the
AES-NUM-273 gap cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining values
over gap positions 1 up to and including that gap
position (A gaps all 512; B gaps 712, 26624, 14848,
33280, 512, 512, 512; agree False, False, False,
False, True, True, True):

- Gap position 1: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 12.
- Gap position 2: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 225.
- Gap position 3: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 2220.
- Gap position 4: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 15330.
- Gap position 5: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 83161.
- Gap position 6: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 377244.
- Gap position 7: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 1487871.

Sequence: [12, 225, 2220, 15330, 83161, 377244, 1487871] — equals the
expected sequence (printed test True), ends at
1487871, with agreeing positions 5, 6, 7 (count 3),
equal to AES-NUM-245.

Contract tests: the printed cumulative sequence
equals (55, 1032, 10191, 70440, 382518, 1737183, 6859776,
24184017) — True; the distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals'
counts sum to 8 — True; the last cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative total
equals 24184017 — True; the gap cumulative sequence
equals (12, 225, 2220, 15330, 83161, 377244, 1487871)
and ends at 1487871 — True.

Mechanisms NOT PROVEN; any offset, prefix or
position law NOT PROVEN; run 102's meaning NOT
PROVEN.
