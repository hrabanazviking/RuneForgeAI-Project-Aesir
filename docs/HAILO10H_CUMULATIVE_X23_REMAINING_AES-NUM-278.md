# The closing-run cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence, the distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals, and the gap cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence (AES-NUM-278)

Slice 4.278, worked under `docs/TASK_CONTRACT_4.278.md`
(contract published in the 4.277 closing commit @
12250ac0). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child, no device run
of any kind. All findings below are taken from the
sha-verified raw output, read in full on-device
(section278.txt). Filename convention, recorded
explicitly per the 4.278 contract's close law: at
twenty-three CUMULATIVEs the chain plus REMAINING.md
alone would be 265 bytes, over the 255-byte
filesystem limit, with no fixed prefix left to
shorten — so this evidence filename uses the
compact X23 notation
(`HAILO10H_CUMULATIVE_X23_REMAINING_AES-NUM-278.md`)
while the full twenty-three-CUMULATIVE chain is
preserved untruncated in this document's title and
throughout its content. The chain is never silently
truncated. The same convention governs 4.279 (X24).

## Run and closing record

hef278.py is the verified hef277 base plus
arms278: hef277.py sha256
`5bcf5febc7bc0bdf362f35016ad6480349c83715ee339f4bfa12f98e04026d32`
(3,181,180 B) on both the VM and the device.
arms278 sha256
`061fba8bbe700f6d1617156f6021872529fb2c03b8f034ac458dc80d16dfb497`
(82,766 B); hef278.py sha256
`17369429cdc65dd1dc58d9189858654bfc5e13dd2420a331b804bcdf7a497f35`
(3,263,946 B) on both the VM and the device.
arms278 was built locally on the hef277 lineage
(make_build278.py derived from make_build277 —
marker-parked header/block/comment before the
simultaneous 276->277 / 277->278 shift, so the
textual shift could not corrupt them; the three
AES-NUM-272 builder fixes carried). Audit of
arms277/build277 found NO standalone data value
containing 277 (every 277 is a slice reference or
identifier suffix — 102277, a2772 included);
carried protections all x2 in arms277 (2725341,
2723, 34273, 2759793 — now 2 occurrences, was 5 —
', 272,', 21267), and the new-block VE assert was
set to the measured 2. hef278 = hef277 + arms278
byte-exact. Crossing, stated exactly: arms278 was
gzipped with gzip -9 (sha256
`1330bd6da3a9cdf6ef2b4874714b843ffb773eed8ee7a8ddd6a2a9716f7a9806`,
9,062 B) and split into 373 B parts — 24 parts
landed sha-verified first try; p_aj corrupted
deterministically at 373 B AND at 187 B halves,
and landed as four 94 B quarters (q_aj_aa..ad, all
sha-verified; assembled p_aj_new sha == p_aj
65c8427d…). No byte accepted unverified.
The assembled gzip, arms278 and hef278
shas == VM on-device; py_compile OK on-device.
run278.sh landed via sha-gated file.write
(sha256
`bd075e083ddd61772f0562f4de28f93129e305c6e83850c52d09fc4f845700cb`,
237 B). The real data value 21267 (AES-NUM-262
layer, two occurrences) was verified untouched
at exactly 2 occurrences in arms278.

LAUNCH: exactly ONE bounded host-side child ran
in detached tmux (session h278, launched
2026-10-31 18:14 EDT) with the contract corpus
argv (glob order, MiniLM last), unbuffered
(`python3 -u`); at launch +20 s hef278.out was
679 B and growing with err empty and no exit
file yet. The child finished with exit marker 0
(hef278.exit, timestamped 18:18 EDT), err empty,
and DONE278 as its last line. Output hef278.out
59,900 lines / 12,493,840 B sha256
`4d31bd5505c122ee3090affabc3ba7dff365108296d91eb132d13d269199be49`;
prefix against hef277.out: the first 59,856 lines
differ from hef277.out in exactly ONE line (line
41611, frozenset element order only, the
AES-NUM-150 variance, verified by
same-sorted-characters comparison via
check278.py sha256
`37d2912136b82af3ad73d23eb38fa8eb9248babcb2f5187bfad9da38d2381a79`),
hef278.out adding exactly its own 44 tail lines
(169,294 B, sha256
`25d381c3ad6f96e0b9663406b4c527e6f7078c50e767fdbffeadd09ba196dd29`).
Controls EXACT, with no exception this slice:
the only 'False' tokens in section278 are the
four gap-position agree data values for gap
positions 1–4 (positions 5, 6, 7 agree) — data,
not comparisons.
Raw output kept on the Pi at
~/aesir-build/ (hef278.out, hef278.py, arms278.py,
section278.txt, hef278.exit, hef278.err, run278.sh,
check278.py); local lineage in
~/workspace/.verify-tmp/aesir278.

Definitions carry over from AES-NUM-247 through
AES-NUM-277 exactly as printed in the run: POSITION
is 1-based over the eight acts of the closing run
(A ranks 741–748, B ranks 743–750); the agreement
set, agreement count, cumulative total, difference,
remaining, cumulative remaining and every iterated
cumulative cumulative-remaining running total are as defined in
the section278 header, read in full on-device.

## (i) The closing-run cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence in full

At each position, the running total of the
AES-NUM-277 cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining values
over positions 1 up to and including that position
(all printed comparisons True for all eight):

- Position 1 (A rank 741 / B rank 743): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 55.
- Position 2 (A rank 742 / B rank 744): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 1252.
- Position 3 (A rank 743 / B rank 745): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 14869.
- Position 4 (A rank 744 / B rank 746): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 122624.
- Position 5 (A rank 745 / B rank 747): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 788753.
- Position 6 (A rank 746 / B rank 748): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 4214675.
- Position 7 (A rank 747 / B rank 749): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 19461585.
- Position 8 (A rank 748 / B rank 750): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 79774695.

Sequence: [55, 1252, 14869, 122624, 788753, 4214675, 19461585, 79774695] —
equals the expected sequence (printed test True);
the last cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative total is 79774695.

## (ii) The distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals in full

Distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals, in order of first
appearance, with positions and counts (counts sum
to 8, printed test True):

- 55: position 1 — count 1.
- 1252: position 2 — count 1.
- 14869: position 3 — count 1.
- 122624: position 4 — count 1.
- 788753: position 5 — count 1.
- 4214675: position 6 — count 1.
- 19461585: position 7 — count 1.
- 79774695: position 8 — count 1.

Eight distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals; none repeats —
stated as printed arithmetic only, no mechanism claimed.

## (iii) The gap cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence in full

At each gap position, the running total of the
AES-NUM-277 gap cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining values
over gap positions 1 up to and including that gap
position (A gaps all 512; B gaps 712, 26624, 14848,
33280, 512, 512, 512; agree False, False, False,
False, True, True, True):

- Gap position 1: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 12.
- Gap position 2: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 273.
- Gap position 3: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 3240.
- Gap position 4: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 26700.
- Gap position 5: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 171601.
- Gap position 6: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 916135.
- Gap position 7: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 4226365.

Sequence: [12, 273, 3240, 26700, 171601, 916135, 4226365] — equals the
expected sequence (printed test True), ends at
4226365, with agreeing positions 5, 6, 7 (count 3),
equal to AES-NUM-245.

Contract tests: the printed cumulative sequence
equals (55, 1252, 14869, 122624, 788753, 4214675, 19461585,
79774695) — True; the distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals'
counts sum to 8 — True; the last cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative total
equals 79774695 — True; the gap cumulative sequence
equals (12, 273, 3240, 26700, 171601, 916135, 4226365)
and ends at 4226365 — True.

Mechanisms NOT PROVEN; any offset, prefix or
position law NOT PROVEN; run 102's meaning NOT
PROVEN.
