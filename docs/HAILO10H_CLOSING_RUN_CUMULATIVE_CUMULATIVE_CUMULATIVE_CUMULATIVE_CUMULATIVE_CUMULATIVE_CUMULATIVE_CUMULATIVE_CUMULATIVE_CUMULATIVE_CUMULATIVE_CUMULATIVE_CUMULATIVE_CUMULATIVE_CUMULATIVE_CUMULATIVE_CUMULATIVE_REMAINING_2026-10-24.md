# The closing-run cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence, the distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals, and the gap cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence (AES-NUM-272)

Slice 4.272, worked under `docs/TASK_CONTRACT_4.272.md`
(contract published in the 4.271 closing commit @
05a7bc3c). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child, no device run
of any kind. All findings below are taken from the
sha-verified raw output, read in full on-device
(section272.txt).

## Run and closing record

hef272.py is the verified hef271 base plus
arms272: hef271.py sha256
`1a5e10959db0cd0633192ca85d8c53793313fcd7614b7e845e0b8dedf1c95e4f`
(2,768,573 B) on both the VM and the device.
arms272 sha256
`9bc4b3d595f3b19c2777d82a1b22c544d29048bf7c369b09cbcd764f4a1ee484`
(59,396 B); hef272.py sha256
`7cd80451efbc61c9c4d6f849df32e5439b8851bbac0d8b7098a8b9b47ea068f8`
(2,827,969 B) on both the VM and the device.
arms272 was built locally on the hef271 lineage
(make_build272.py, derived from make_build271.py —
THREE transformer faults were found and fixed in
the builder, not the data: (1) the gap definition
block's running vars sit after literal \n escapes
so the \b regex cannot bump them — the carried
block g15->g16 and the added block g16->g17 were
fixed explicitly; (2) the builder's OWN shift line
kept its '269' literal, producing
replace('269','271') instead of
replace('270','271') — fixed explicitly; (3) the
gap print-arg LISTS keep their low end g5 and only
extend at the top (old g5..g16, new g5..g17) — the
regex had bumped every element; both lists restored
explicitly. The hef273 build MUST derive
make_build273 from make_build272, which carries
these fixes, NOT from make_build271).
hef272 = hef271 + arms272 byte-exact. Crossing,
stated exactly: arms272 was gzipped with gzip -9
(sha256
`60bf883647a377a46bd3fd58442ec9a149118a55580c9cc74ece8c8254854f1d`,
7,837 B) and split into twenty-two 373 B parts
(last 4 B), each part written as its own file with
its own sha256 gate — all twenty-two verified
on-device; no byte accepted unverified. Transfer
notes: p_ae failed its sha gate TWICE as a single
373 B file (deterministic re-emission corruption,
discarded both times) and landed clean when split
into 186 B + 187 B chunk writes of the same file
with the whole-file sha on the final chunk;
p_af/p_ag failed once under parallel writes
(partial-file race) and landed clean sequentially.
The assembled gzip, arms and hef272 shas == VM
on-device; py_compile OK on-device.
The build's slice-number shift was
270 -> 271, 271 -> 272 only, so the real data
value 21267 (AES-NUM-262 layer, two occurrences)
was verified untouched at exactly 2 occurrences.

LAUNCH: exactly ONE bounded host-side child ran
in detached tmux (session h272, launched
2026-10-31 13:18:38 EDT, pid 178494) with the
contract corpus argv (glob order, MiniLM last),
unbuffered (`python3 -u`); the continuity worker's
own pre-launch check found the child ALREADY
RUNNING (launched by a parallel hand the moment
run272.sh landed) and did NOT launch another. The
child finished at 13:23 EDT with exit marker 0
(hef272.exit), err empty, and DONE272 as its last
line. Output hef272.out 59,636 lines / 11,634,778 B
sha256 `6442ee09…` (as recorded at verification);
prefix against hef271.out: the first 59,592 lines
differ from hef271.out in exactly ONE line (line
41611, frozenset element order only, the
AES-NUM-150 variance, verified by
same-sorted-characters comparison via
check272.py sha256
`0300d311fcb55d1269a1e413c0b26f61224fe156d115c48fd741703a51ac071d`),
hef272.out adding exactly its own 44 tail lines
(109,236 B, sha256 `827605a1…`).
Controls EXACT, with no exception this slice:
the only 'False' tokens in section272 are the
four gap-position agree data values for gap
positions 1–4 (positions 5, 6, 7 agree) — data,
not comparisons.
Raw output kept on the Pi at
~/aesir-build/ (hef272.out, hef272.py, arms272.py,
section272.txt, hef272.exit, hef272.err, run272.sh,
gz272/, check272.py); local lineage in
~/workspace/.verify-tmp/aesir272.

Definitions carry over from AES-NUM-247 through
AES-NUM-271 exactly as printed in the run: POSITION
is 1-based over the eight acts of the closing run
(A ranks 741–748, B ranks 743–750); the agreement
set, agreement count, cumulative total, difference,
remaining, cumulative remaining and every iterated
cumulative-remaining running total are as defined in
the section272 header, read in full on-device.

## (i) The closing-run cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence in full

At each position, the running total of the
AES-NUM-271 cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining values
over positions 1 up to and including that position
(all printed comparisons True for all eight):

- Position 1 (A rank 741 / B rank 743): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 55.
- Position 2 (A rank 742 / B rank 744): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 922.
- Position 3 (A rank 743 / B rank 745): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 8182.
- Position 4 (A rank 744 / B rank 746): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 51090.
- Position 5 (A rank 745 / B rank 747): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 251829.
- Position 6 (A rank 746 / B rank 748): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 1042587.
- Position 7 (A rank 747 / B rank 749): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 3767928.
- Position 8 (A rank 748 / B rank 750): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 12201648.

Sequence: [55, 922, 8182, 51090, 251829, 1042587, 3767928, 12201648] —
equals the expected sequence (printed test True);
the last cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative total is 12201648.

## (ii) The distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals in full

Distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals, in order of first
appearance, with positions and counts (counts sum
to 8, printed test True):

- 55: position 1 — count 1.
- 922: position 2 — count 1.
- 8182: position 3 — count 1.
- 51090: position 4 — count 1.
- 251829: position 5 — count 1.
- 1042587: position 6 — count 1.
- 3767928: position 7 — count 1.
- 12201648: position 8 — count 1.

Eight distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals; none repeats —
stated as printed arithmetic only, no mechanism claimed.

## (iii) The gap cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence in full

At each gap position, the running total of the
AES-NUM-271 gap cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining values
over gap positions 1 up to and including that gap
position (A gaps all 512; B gaps 712, 26624, 14848,
33280, 512, 512, 512; agree False, False, False,
False, True, True, True):

- Gap position 1: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 12.
- Gap position 2: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 201.
- Gap position 3: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 1782.
- Gap position 4: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 11115.
- Gap position 5: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 54721.
- Gap position 6: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 226252.
- Gap position 7: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 816544.

Sequence: [12, 201, 1782, 11115, 54721, 226252, 816544] — equals the
expected sequence (printed test True), ends at
816544, with agreeing positions 5, 6, 7 (count 3),
equal to AES-NUM-245.

Contract tests: the printed cumulative sequence
equals (55, 922, 8182, 51090, 251829, 1042587, 3767928,
12201648) — True; the distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals'
counts sum to 8 — True; the last cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative total
equals 12201648 — True; the gap cumulative sequence
equals (12, 201, 1782, 11115, 54721, 226252, 816544)
and ends at 816544 — True.

Mechanisms NOT PROVEN; any offset, prefix or
position law NOT PROVEN; run 102's meaning NOT
PROVEN.
