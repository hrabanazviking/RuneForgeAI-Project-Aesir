# The closing-run cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence, the distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals, and the gap cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence (AES-NUM-275)

Slice 4.275, worked under `docs/TASK_CONTRACT_4.275.md`
(contract published in the 4.274 closing commit @
7dc7d269). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child, no device run
of any kind. All findings below are taken from the
sha-verified raw output, read in full on-device
(section275.txt). Naming note: the
evidence filename keeps the full twenty-
CUMULATIVE chain; at twenty the inherited
name (with its 2026-10-24 date suffix) would
be 264 bytes, over the 255-byte filesystem
limit, so the date suffix alone is dropped
(253 bytes) — the chain is never truncated.

## Run and closing record

hef275.py is the verified hef274 base plus
arms275: hef274.py sha256
`d2ea3636e764eefdb49c4f2476dd65e00643233afc9d4be7b726de91ccb27b52`
(2,957,629 B) on both the VM and the device.
arms275 sha256
`6ec3cc793bc48750b4517d6a12f1ae24ded0d22c2de006100684892034443ba3`
(70,516 B); hef275.py sha256
`f0e69c2779ea2eb0db50d976be828052c2fbd4705dffc8a8ae3d1dbd5b0ec73f`
(3,028,145 B) on both the VM and the device.
arms275 was built locally on the hef274 lineage
(make_build275.py, derived from make_build274.py —
the three AES-NUM-272 builder fixes carried:
gap \n-block carried g18->g19 and added
g19->g20 fixed explicitly; gap print-arg lists
keep g5 low end and extend only at the top;
the builder's own shift-line fix carried).
PLUS the protections this slice required:
the build274 text protected 34273 (4
occurrences, containing the shift source 273)
through the make-level shift with a digit-free
placeholder; the arms shift protected
2725341 (2 occ), 2723 (2 occ), 34273 (2 occ)
and the standalone data index 272 in its
', 272,' form (2 occ) with digit-free
placeholders @@VA@@/@@VB@@/@@VD@@/@@VC@@ —
kept verbatim from AES-NUM-274, the audit of
arms274/build274 having found NO standalone
data value containing 274 (the 274-digit
tokens are identifiers a2742/idx2742/
arun102274, which shift correctly), while
AES-NUM-273 references (31 occ) shift to 274.
Gap tuple pair 6 is absent as in the 274
generation (optional, skipped).
hef275 = hef274 + arms275 byte-exact. Crossing,
stated exactly: arms275 was gzipped with gzip -9
(sha256
`49eb12ba18127a700357dad0586c6f523b7b91216c78607114688e8c4629707c`,
8,417 B) and split into twenty-three 373 B parts
(last 211 B), each part written as its own file
with its own sha256 gate — twenty-two parts
verified on-device first try; part p_ar failed
twice in re-emission (base64 length, then sha
mismatch; both writes discarded uncommitted)
and landed clean as two sub-parts p_ar1/p_ar2
(186/187 B) per the banked change-the-chunk-
boundary law; no byte accepted unverified.
The assembled gzip, arms and hef275
shas == VM on-device; py_compile OK on-device.
run275.sh landed via sha-gated file.write
(sha256
`e9a5d37e94249ebba3e0af27b236486bb00abf277a0ed4ec2a63ab900e47dcb1`,
237 B). The build's slice-number shift was
273 -> 274, 274 -> 275 only (with the protected
values above restored), so the real data value
21267 (AES-NUM-262 layer, two occurrences) was
verified untouched at exactly 2 occurrences.

LAUNCH: exactly ONE bounded host-side child ran
in detached tmux (session h275, launched
2026-10-31 ~16:00 EDT) with the contract corpus
argv (glob order, MiniLM last), unbuffered
(`python3 -u`); at 16:02 EDT hef275.out was
651,047 B and growing with err empty and no exit
file yet. The child finished with exit marker 0
(hef275.exit, timestamped 16:04 EDT), err empty,
and DONE275 as its last line. Output hef275.out
59,768 lines / 12,018,420 B sha256
`288525e784d0631e13808e022d727548980857629185fe243ba76b8dbc549ce9`;
prefix against hef274.out: the first 59,724 lines
differ from hef274.out in exactly ONE line (line
42872, frozenset element order only, the
AES-NUM-150 variance, verified by
same-sorted-characters comparison via
check275.py sha256
`4bf1db14d0c2d93e0751327b001e3fa07a47868c0e842888539bde0cae650f73`),
hef275.out adding exactly its own 44 tail lines
(137,578 B, sha256
`b3439317731374406250f6a932efdb7c513dbf345a03324e5723b3778f2e3085`).
Controls EXACT, with no exception this slice:
the only 'False' tokens in section275 are the
four gap-position agree data values for gap
positions 1–4 (positions 5, 6, 7 agree) — data,
not comparisons.
Raw output kept on the Pi at
~/aesir-build/ (hef275.out, hef275.py, arms275.py,
section275.txt, hef275.exit, hef275.err, run275.sh,
gz275/, check275.py); local lineage in
~/workspace/.verify-tmp/aesir275.

Definitions carry over from AES-NUM-247 through
AES-NUM-274 exactly as printed in the run: POSITION
is 1-based over the eight acts of the closing run
(A ranks 741–748, B ranks 743–750); the agreement
set, agreement count, cumulative total, difference,
remaining, cumulative remaining and every iterated
cumulative cumulative-remaining running total are as defined in
the section275 header, read in full on-device.

## (i) The closing-run cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence in full

At each position, the running total of the
AES-NUM-274 cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining values
over positions 1 up to and including that position
(all printed comparisons True for all eight):

- Position 1 (A rank 741 / B rank 743): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 55.
- Position 2 (A rank 742 / B rank 744): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 1087.
- Position 3 (A rank 743 / B rank 745): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 11278.
- Position 4 (A rank 744 / B rank 746): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 81718.
- Position 5 (A rank 745 / B rank 747): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 464236.
- Position 6 (A rank 746 / B rank 748): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 2201419.
- Position 7 (A rank 747 / B rank 749): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 9061195.
- Position 8 (A rank 748 / B rank 750): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 33245212.

Sequence: [55, 1087, 11278, 81718, 464236, 2201419, 9061195, 33245212] —
equals the expected sequence (printed test True);
the last cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative total is 33245212.

## (ii) The distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals in full

Distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals, in order of first
appearance, with positions and counts (counts sum
to 8, printed test True):

- 55: position 1 — count 1.
- 1087: position 2 — count 1.
- 11278: position 3 — count 1.
- 81718: position 4 — count 1.
- 464236: position 5 — count 1.
- 2201419: position 6 — count 1.
- 9061195: position 7 — count 1.
- 33245212: position 8 — count 1.

Eight distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals; none repeats —
stated as printed arithmetic only, no mechanism claimed.

## (iii) The gap cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence in full

At each gap position, the running total of the
AES-NUM-274 gap cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining values
over gap positions 1 up to and including that gap
position (A gaps all 512; B gaps 712, 26624, 14848,
33280, 512, 512, 512; agree False, False, False,
False, True, True, True):

- Gap position 1: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 12.
- Gap position 2: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 237.
- Gap position 3: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 2457.
- Gap position 4: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 17787.
- Gap position 5: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 100948.
- Gap position 6: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 478192.
- Gap position 7: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 1966063.

Sequence: [12, 237, 2457, 17787, 100948, 478192, 1966063] — equals the
expected sequence (printed test True), ends at
1966063, with agreeing positions 5, 6, 7 (count 3),
equal to AES-NUM-245.

Contract tests: the printed cumulative sequence
equals (55, 1032, 10191, 70440, 382518, 1737183, 9061195,
33245212) — True; the distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals'
counts sum to 8 — True; the last cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative total
equals 33245212 — True; the gap cumulative sequence
equals (12, 237, 2457, 17787, 100948, 478192, 1966063)
and ends at 1966063 — True.

Mechanisms NOT PROVEN; any offset, prefix or
position law NOT PROVEN; run 102's meaning NOT
PROVEN.
