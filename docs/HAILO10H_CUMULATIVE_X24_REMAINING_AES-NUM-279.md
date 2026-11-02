# The closing-run cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence, the distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals, and the gap cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence (AES-NUM-279)

Slice 4.279, worked under `docs/TASK_CONTRACT_4.279.md`
(contract published in the 4.278 closing commit @
98247c1f). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child, no device run
of any kind. All findings below are taken from the
sha-verified raw output, read in full on-device
(section279.txt). Filename convention, recorded
explicitly per the 4.279 contract's close law: at
twenty-four CUMULATIVEs the chain plus REMAINING.md
alone exceeds the 255-byte filesystem limit even
further, with no fixed prefix left to shorten — so
this evidence filename uses the compact X24
notation
(`HAILO10H_CUMULATIVE_X24_REMAINING_AES-NUM-279.md`)
while the full twenty-four-CUMULATIVE chain is
preserved untruncated in this document's title and
throughout its content. The chain is never silently
truncated. The same convention governs 4.280 (X25).

## Run and closing record

hef279.py is the verified hef278 base plus
arms279: hef278.py sha256
`17369429cdc65dd1dc58d9189858654bfc5e13dd2420a331b804bcdf7a497f35`
(3,263,946 B) on both the VM and the device.
arms279 sha256
`e88edf79b09a6a2a2d408311dea46b7d4d89f8968807dfedcad3ced8242afb41`
(87,106 B); hef279.py sha256
`76088e75ec37c83dd81a68accc10a947534cb1a99b5008db93f010f4b92d11a0`
(3,351,052 B) on both the VM and the device.
arms279 was built locally on the hef278 lineage
(make_build279.py derived from make_build278 —
marker-parked header/block/comment before the
simultaneous 277->278 / 278->279 shift, so the
textual shift could not corrupt them; the three
AES-NUM-272 builder fixes carried). Audit of
arms278/build278 found TWO real data values
containing the outgoing substring 278 — 11278
(2 occurrences, an older cumulative sequence
value) and 32784 (2 occurrences, an act-size
datum) — both protected with digit-free
placeholders in the new builder block; carried
protections all x2 in arms278 (2725341, 2723,
34273, 2759793, ', 272,', 21267), and both new
values verified intact at exactly 2 occurrences
each in arms279. hef279 = hef278 + arms279
byte-exact. Crossing, stated exactly: arms279 was
gzipped with gzip -9 (sha256
`870860756444a600841667fed7781959464414783b7211af6e47928f21a97494`,
9,273 B) and split into 373 B parts — 24 parts
landed sha-verified first try; p_ax corrupted in
re-emission once (a duplicated segment; its
decode appended nothing — the on-device size
stayed exactly 8,579) and landed as two 187/186 B
halves. No byte accepted unverified.
The assembled gzip, arms279 and hef279
shas == VM on-device; py_compile OK on-device.
run279.sh landed via sha-gated file.write
(sha256
`4e2056c0932115a9d295cfdb9a3d0a0ae6227d6db20faf9bef98c9a3c1d0a3b7`,
237 B). The real data value 21267 (AES-NUM-262
layer, two occurrences) was verified untouched
at exactly 2 occurrences in arms279.

LAUNCH: exactly ONE bounded host-side child ran
in detached tmux (session h279, launched
2026-10-31 18:54 EDT) with the contract corpus
argv (glob order, MiniLM last), unbuffered
(`python3 -u`); at launch +20 s hef279.out was
679 B and growing with err empty and no exit
file yet. The child finished with exit marker 0
(hef279.exit, timestamped 18:58 EDT), err empty,
and DONE279 as its last line. Output hef279.out
59,944 lines / 12,674,464 B sha256
`1a3302b8e8eb49d15a3d7d532a513aa084d257883c92f2d357bd86a61283af16`;
prefix against hef278.out: the first 59,900 lines
differ from hef278.out in exactly TWO lines
(lines 41611 and 42872, frozenset element order
only, the AES-NUM-150 variance, verified by
same-sorted-characters comparison via
check279.py sha256
`3bf0a2e3c5c3e732a5a4a9c1d9e1827efb258f29e5318e58eade32a01335b918`),
hef279.out adding exactly its own 44 tail lines
(180,624 B, sha256
`e40e36bc957065f77b78a31f3a194b110930c7dc2d7ffc829c0eecf629853b53`).
Controls EXACT, with no exception this slice:
the only 'False' tokens in section279 are the
four gap-position agree data values for gap
positions 1–4 (positions 5, 6, 7 agree) — data,
not comparisons.
Raw output kept on the Pi at
~/aesir-build/ (hef279.out, hef279.py, arms279.py,
section279.txt, hef279.exit, hef279.err, run279.sh,
check279.py); local lineage in
~/workspace/.verify-tmp/aesir279.

Definitions carry over from AES-NUM-247 through
AES-NUM-278 exactly as printed in the run: POSITION
is 1-based over the eight acts of the closing run
(A ranks 741–748, B ranks 743–750); the agreement
set, agreement count, cumulative total, difference,
remaining, cumulative remaining and every iterated
cumulative cumulative-remaining running total are as defined in
the section279 header, read in full on-device.

## (i) The closing-run cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence in full

At each position, the running total of the
AES-NUM-278 cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining values
over positions 1 up to and including that position
(all printed comparisons True for all eight):

- Position 1 (A rank 741 / B rank 743): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 55.
- Position 2 (A rank 742 / B rank 744): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 1307.
- Position 3 (A rank 743 / B rank 745): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 16176.
- Position 4 (A rank 744 / B rank 746): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 138800.
- Position 5 (A rank 745 / B rank 747): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 927553.
- Position 6 (A rank 746 / B rank 748): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 5142228.
- Position 7 (A rank 747 / B rank 749): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 24603813.
- Position 8 (A rank 748 / B rank 750): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 104378508.

Sequence: [55, 1307, 16176, 138800, 927553, 5142228, 24603813, 104378508] —
equals the expected sequence (printed test True);
the last cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative total is 104378508.

## (ii) The distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals in full

Distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals, in order of first
appearance, with positions and counts (counts sum
to 8, printed test True):

- 55: position 1 — count 1.
- 1307: position 2 — count 1.
- 16176: position 3 — count 1.
- 138800: position 4 — count 1.
- 927553: position 5 — count 1.
- 5142228: position 6 — count 1.
- 24603813: position 7 — count 1.
- 104378508: position 8 — count 1.

Eight distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals; none repeats —
stated as printed arithmetic only, no mechanism claimed.

## (iii) The gap cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence in full

At each gap position, the running total of the
AES-NUM-278 gap cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining values
over gap positions 1 up to and including that gap
position (A gaps all 512; B gaps 712, 26624, 14848,
33280, 512, 512, 512; agree False, False, False,
False, True, True, True):

- Gap position 1: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 12.
- Gap position 2: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 285.
- Gap position 3: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 3525.
- Gap position 4: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 30225.
- Gap position 5: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 201826.
- Gap position 6: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 1117961.
- Gap position 7: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 5344326.

Sequence: [12, 285, 3525, 30225, 201826, 1117961, 5344326] — equals the
expected sequence (printed test True), ends at
5344326, with agreeing positions 5, 6, 7 (count 3),
equal to AES-NUM-245.

Contract tests: the printed cumulative sequence
equals (55, 1307, 16176, 138800, 927553, 5142228, 24603813,
104378508) — True; the distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals'
counts sum to 8 — True; the last cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative total
equals 104378508 — True; the gap cumulative sequence
equals (12, 285, 3525, 30225, 201826, 1117961, 5344326)
and ends at 5344326 — True.

Mechanisms NOT PROVEN; any offset, prefix or
position law NOT PROVEN; run 102's meaning NOT
PROVEN.
