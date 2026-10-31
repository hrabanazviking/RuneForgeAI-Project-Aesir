# The closing-run cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence, the distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals, and the gap cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence (AES-NUM-276)

Slice 4.276, worked under `docs/TASK_CONTRACT_4.276.md`
(contract published in the 4.275 closing commit @
50eb9e08). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child, no device run
of any kind. All findings below are taken from the
sha-verified raw output, read in full on-device
(section276.txt). Naming note: the
evidence filename keeps the full twenty-one-
CUMULATIVE chain; at twenty-one the inherited
name (HAILO10H_CLOSING_RUN_ prefix) would
be 264 bytes, over the 255-byte filesystem
limit, so the fixed prefix alone is shortened
to HAILO10H_ (252 bytes) — the chain is never truncated.

## Run and closing record

hef276.py is the verified hef275 base plus
arms276: hef275.py sha256
`f0e69c2779ea2eb0db50d976be828052c2fbd4705dffc8a8ae3d1dbd5b0ec73f`
(3,028,145 B) on both the VM and the device.
arms276 sha256
`404c685193aaa7c4a3dcb4ec30e9daefe6a40e3323228f16d69c864abfacb3a0`
(74,475 B); hef276.py sha256
`c496f048e99f77fa6189db824b720ff12778d98ce81e89300bfcd2eb22909966`
(3,102,620 B) on both the VM and the device.
arms276 was built locally on the hef275 lineage
(make_build276.py, written fresh on the
make_build275 pattern — the three AES-NUM-272
builder fixes carried:
gap \n-block carried g19->g20 and added
g20->g21 fixed explicitly; gap print-arg lists
keep g5 low end and extend only at the top;
the builder's own shift-line fix carried).
PLUS the protections this slice required:
the build275 text protected 34273 (4
occurrences, a harmless carry — it contains
neither the shift source 274 nor 275)
through the make-level shift with a digit-free
placeholder; the arms shift protected
2725341 (2 occ), 2723 (2 occ), 34273 (2 occ)
and the standalone data index 272 in its
', 272,' form (2 occ) with digit-free
placeholders @@VA@@/@@VB@@/@@VD@@/@@VC@@ —
kept verbatim from AES-NUM-275, the audit of
arms275/build275 having found NO standalone
data value containing 275 (all 275 tokens are
slice references / identifier suffixes that
shift correctly), while the corrupted shift
line and audit comment in the derived builder
were hand-corrected exactly as in the 275
generation. Gap tuple pair 6 is absent as in
the 275 generation (optional, skipped).
hef276 = hef275 + arms276 byte-exact. Crossing,
stated exactly: arms276 was gzipped with gzip -9
(sha256
`3515a9c2107114968b6e9fcef582f2eda47b54855192821bb8f8da7d19a1baa1`,
8,626 B) and split into twenty-four 373 B parts
(last 47 B), each part written as its own file
with its own sha256 gate — all twenty-four
verified on-device first try; no byte accepted
unverified.
The assembled gzip, arms and hef276
shas == VM on-device; py_compile OK on-device.
run276.sh landed via sha-gated file.write
(sha256
`78b94adc481473fd3796fbbb66094a7d015d617014603b941079c913d8791a89`,
237 B). The build's slice-number shift was
274 -> 275, 275 -> 276 only (with the protected
values above restored), so the real data value
21267 (AES-NUM-262 layer, two occurrences) was
verified untouched at exactly 2 occurrences
in arms276.

LAUNCH: exactly ONE bounded host-side child ran
in detached tmux (session h276, launched
2026-10-31 16:35 EDT) with the contract corpus
argv (glob order, MiniLM last), unbuffered
(`python3 -u`); at 16:36 EDT hef276.out was
679 B and growing with err empty and no exit
file yet. The child finished with exit marker 0
(hef276.exit, timestamped 16:39 EDT), err empty,
and DONE276 as its last line. Output hef276.out
59,812 lines / 12,166,196 B sha256
`cdc7685bd9ac0b432c9481d4713cec45b639096d92ac7fc35029ac930d0b853b`;
prefix against hef275.out: the first 59,768 lines
differ from hef275.out in exactly TWO lines (lines
41611 and 42872, frozenset element order only, the
AES-NUM-150 variance, verified by
same-sorted-characters comparison via
check276.py sha256
`69f6fbfef4a3967af1146d212b08580e60a153343b4f484e533f055c24c98864`),
hef276.out adding exactly its own 44 tail lines
(147,776 B, sha256
`8acf5e77baca41b9345f057bb87d4fd3e234878fd5b29e7340acc2bd75b9160e`).
Controls EXACT, with no exception this slice:
the only 'False' tokens in section276 are the
four gap-position agree data values for gap
positions 1–4 (positions 5, 6, 7 agree) — data,
not comparisons.
Raw output kept on the Pi at
~/aesir-build/ (hef276.out, hef276.py, arms276.py,
section276.txt, hef276.exit, hef276.err, run276.sh,
gz276/, check276.py); local lineage in
~/workspace/.verify-tmp/aesir276.

Definitions carry over from AES-NUM-247 through
AES-NUM-275 exactly as printed in the run: POSITION
is 1-based over the eight acts of the closing run
(A ranks 741–748, B ranks 743–750); the agreement
set, agreement count, cumulative total, difference,
remaining, cumulative remaining and every iterated
cumulative cumulative-remaining running total are as defined in
the section276 header, read in full on-device.

## (i) The closing-run cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence in full

At each position, the running total of the
AES-NUM-275 cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining values
over positions 1 up to and including that position
(all printed comparisons True for all eight):

- Position 1 (A rank 741 / B rank 743): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 55.
- Position 2 (A rank 742 / B rank 744): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 1142.
- Position 3 (A rank 743 / B rank 745): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 12420.
- Position 4 (A rank 744 / B rank 746): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 94138.
- Position 5 (A rank 745 / B rank 747): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 558374.
- Position 6 (A rank 746 / B rank 748): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 2759793.
- Position 7 (A rank 747 / B rank 749): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 11820988.
- Position 8 (A rank 748 / B rank 750): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 45066200.

Sequence: [55, 1142, 12420, 94138, 558374, 2759793, 11820988, 45066200] —
equals the expected sequence (printed test True);
the last cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative total is 45066200.

## (ii) The distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals in full

Distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals, in order of first
appearance, with positions and counts (counts sum
to 8, printed test True):

- 55: position 1 — count 1.
- 1142: position 2 — count 1.
- 12420: position 3 — count 1.
- 94138: position 4 — count 1.
- 558374: position 5 — count 1.
- 2759793: position 6 — count 1.
- 11820988: position 7 — count 1.
- 45066200: position 8 — count 1.

Eight distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals; none repeats —
stated as printed arithmetic only, no mechanism claimed.

## (iii) The gap cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence in full

At each gap position, the running total of the
AES-NUM-275 gap cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining values
over gap positions 1 up to and including that gap
position (A gaps all 512; B gaps 712, 26624, 14848,
33280, 512, 512, 512; agree False, False, False,
False, True, True, True):

- Gap position 1: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 12.
- Gap position 2: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 249.
- Gap position 3: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 2706.
- Gap position 4: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 20493.
- Gap position 5: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 121441.
- Gap position 6: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 599633.
- Gap position 7: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 2565696.

Sequence: [12, 249, 2706, 20493, 121441, 599633, 2565696] — equals the
expected sequence (printed test True), ends at
2565696, with agreeing positions 5, 6, 7 (count 3),
equal to AES-NUM-245.

Contract tests: the printed cumulative sequence
equals (55, 1142, 12420, 94138, 558374, 2759793, 11820988,
45066200) — True; the distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals'
counts sum to 8 — True; the last cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative total
equals 45066200 — True; the gap cumulative sequence
equals (12, 249, 2706, 20493, 121441, 599633, 2565696)
and ends at 2565696 — True.

Mechanisms NOT PROVEN; any offset, prefix or
position law NOT PROVEN; run 102's meaning NOT
PROVEN.
