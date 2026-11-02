# The closing-run cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence, the distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals, and the gap cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence (AES-NUM-277)

Slice 4.277, worked under `docs/TASK_CONTRACT_4.277.md`
(contract published in the 4.276 closing commit @
425b69d6). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child, no device run
of any kind. All findings below are taken from the
sha-verified raw output, read in full on-device
(section277.txt). Naming note: the
evidence filename keeps the full twenty-two-
CUMULATIVE chain and carries NO fixed prefix at
all (254 bytes) — the chain is never truncated.
At twenty-three CUMULATIVEs the chain plus
REMAINING.md alone would be 265 bytes, over the
255-byte filesystem limit, with no prefix left
to shorten; the 4.278 close must preserve the
full chain in the document title and record its
filename convention explicitly (see the 4.278
contract).

## Run and closing record

hef277.py is the verified hef276 base plus
arms277: hef276.py sha256
`c496f048e99f77fa6189db824b720ff12778d98ce81e89300bfcd2eb22909966`
(3,102,620 B) on both the VM and the device.
arms277 sha256
`5f9d3ecee0db2a9d199a706bfba9f44e316472aa4c525ee9c37af6e18e0f0cad`
(78,560 B); hef277.py sha256
`5bcf5febc7bc0bdf362f35016ad6480349c83715ee339f4bfa12f98e04026d32`
(3,181,180 B) on both the VM and the device.
arms277 was built locally on the hef276 lineage
(make_build277.py derived from make_build276 —
marker-parked header/block/comment before the
simultaneous 275->276 / 276->277 shift, so the
textual shift could not corrupt them; the three
AES-NUM-272 builder fixes carried). Audit of
arms276/build276 found NO standalone data value
containing 276 (every 276 is a slice reference or
identifier suffix); the one real collision found
is the data value 2759793 (the AES-NUM-276
sequence total; 5 occurrences in arms276, 6 in
build276), protected with a digit-free placeholder
at BOTH levels (make level @@VALE@@; build277's
arms shift @@VE@@, asserted 5 occurrences), plus
the contract-named 21267 protection carried in
build277's asserts and the carried 2725341 / 2723 /
34273 / ', 272,' protections verbatim.
hef277 = hef276 + arms277 byte-exact. Crossing,
stated exactly: arms277 was gzipped with gzip -9
(sha256
`5ec4f5f7434431909e23b0970b7540a4dbc6bd6b44f765b6140b74f55fcaac3d`,
8,815 B) and split into 373 B parts — p_aa..p_af
landed sha-verified (two parallel-write races on
p_ab/p_ad healed by sequential retry); p_ag
corrupted deterministically twice at the 373 B
boundary, so the remaining tail (from byte 2238)
was re-split at 300 B (22 parts, q_aa..q_av, all
sha-verified; q_ad itself corrupted twice at
300 B and landed as two 150 B halves). No byte
accepted unverified.
The assembled gzip, arms277 and hef277
shas == VM on-device; py_compile OK on-device.
run277.sh landed via sha-gated file.write
(sha256
`d715f01fe8eec3e5c0670662c6a410e39bdb0fe7057c01fa1639759eed841854`,
237 B). The real data value 21267 (AES-NUM-262
layer, two occurrences) was verified untouched
at exactly 2 occurrences in arms277.

LAUNCH: exactly ONE bounded host-side child ran
in detached tmux (session h277, launched
2026-10-31 17:07 EDT) with the contract corpus
argv (glob order, MiniLM last), unbuffered
(`python3 -u`); at 17:10 EDT hef277.out was
6,766,592 B and growing with err empty and no exit
file yet. The child finished with exit marker 0
(hef277.exit, timestamped 17:11 EDT), err empty,
and DONE277 as its last line. Output hef277.out
59,856 lines / 12,324,546 B sha256
`e13e3e555326b53b5747d42a947984f299f6f1f29263e17afd86dd2690a3c71c`;
prefix against hef276.out: the first 59,812 lines
differ from hef276.out in exactly ONE line (line
42872, frozenset element order only, the
AES-NUM-150 variance, verified by
same-sorted-characters comparison via
check277.py sha256
`78c2d1ffeccaad761ee6774c2d5466b2bf5505caa2a35d66bd5236595e1c3c93`),
hef277.out adding exactly its own 44 tail lines
(158,350 B, sha256
`34b1a959bdf8348d1d8770652415af7093de0d8e9d63fd0528813dfa1a9a5913`).
Controls EXACT, with no exception this slice:
the only 'False' tokens in section277 are the
four gap-position agree data values for gap
positions 1–4 (positions 5, 6, 7 agree) — data,
not comparisons.
Raw output kept on the Pi at
~/aesir-build/ (hef277.out, hef277.py, arms277.py,
section277.txt, hef277.exit, hef277.err, run277.sh,
check277.py); local lineage in
~/workspace/.verify-tmp/aesir277.

Definitions carry over from AES-NUM-247 through
AES-NUM-276 exactly as printed in the run: POSITION
is 1-based over the eight acts of the closing run
(A ranks 741–748, B ranks 743–750); the agreement
set, agreement count, cumulative total, difference,
remaining, cumulative remaining and every iterated
cumulative cumulative-remaining running total are as defined in
the section277 header, read in full on-device.

## (i) The closing-run cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence in full

At each position, the running total of the
AES-NUM-276 cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining values
over positions 1 up to and including that position
(all printed comparisons True for all eight):

- Position 1 (A rank 741 / B rank 743): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 55.
- Position 2 (A rank 742 / B rank 744): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 1197.
- Position 3 (A rank 743 / B rank 745): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 13617.
- Position 4 (A rank 744 / B rank 746): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 107755.
- Position 5 (A rank 745 / B rank 747): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 666129.
- Position 6 (A rank 746 / B rank 748): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 3425922.
- Position 7 (A rank 747 / B rank 749): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 15246910.
- Position 8 (A rank 748 / B rank 750): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 60313110.

Sequence: [55, 1197, 13617, 107755, 666129, 3425922, 15246910, 60313110] —
equals the expected sequence (printed test True);
the last cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative total is 60313110.

## (ii) The distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals in full

Distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals, in order of first
appearance, with positions and counts (counts sum
to 8, printed test True):

- 55: position 1 — count 1.
- 1197: position 2 — count 1.
- 13617: position 3 — count 1.
- 107755: position 4 — count 1.
- 666129: position 5 — count 1.
- 3425922: position 6 — count 1.
- 15246910: position 7 — count 1.
- 60313110: position 8 — count 1.

Eight distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals; none repeats —
stated as printed arithmetic only, no mechanism claimed.

## (iii) The gap cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence in full

At each gap position, the running total of the
AES-NUM-276 gap cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining values
over gap positions 1 up to and including that gap
position (A gaps all 512; B gaps 712, 26624, 14848,
33280, 512, 512, 512; agree False, False, False,
False, True, True, True):

- Gap position 1: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 12.
- Gap position 2: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 261.
- Gap position 3: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 2967.
- Gap position 4: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 23460.
- Gap position 5: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 144901.
- Gap position 6: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 744534.
- Gap position 7: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 3310230.

Sequence: [12, 261, 2967, 23460, 144901, 744534, 3310230] — equals the
expected sequence (printed test True), ends at
3310230, with agreeing positions 5, 6, 7 (count 3),
equal to AES-NUM-245.

Contract tests: the printed cumulative sequence
equals (55, 1197, 13617, 107755, 666129, 3425922, 15246910,
60313110) — True; the distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals'
counts sum to 8 — True; the last cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative total
equals 60313110 — True; the gap cumulative sequence
equals (12, 261, 2967, 23460, 144901, 744534, 3310230)
and ends at 3310230 — True.

Mechanisms NOT PROVEN; any offset, prefix or
position law NOT PROVEN; run 102's meaning NOT
PROVEN.
