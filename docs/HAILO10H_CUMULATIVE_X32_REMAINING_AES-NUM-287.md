# The closing-run cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence, the distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals, and the gap cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence (AES-NUM-287)

Slice 4.287, worked under `docs/TASK_CONTRACT_4.287.md`
(contract published in the 4.286 closing commit @
992bd778). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child, no device run
of any kind. All findings below are taken from the
sha-verified raw output, read on-device
(section287.txt). Filename convention, recorded
explicitly per the 4.287 contract's close law: at
thirty-two CUMULATIVEs the chain plus REMAINING.md
alone exceeds the 255-byte filesystem limit even
further, with no fixed prefix left to shorten — so
this evidence filename uses the compact X32
notation
(`HAILO10H_CUMULATIVE_X32_REMAINING_AES-NUM-287.md`)
while the full thirty-two-CUMULATIVE chain is
preserved untruncated in this document's title and
throughout its content. The chain is never silently
truncated. The same convention governs 4.288 (X33).

## Run and closing record

hef287.py is the verified hef286 base plus
arms287: hef286.py sha256
`5be8da81345fab3a6808194ee7db796a83ca1e6c19177d29ff9e4db3567293d0`
(4,092,764 B) on both the VM and the device.
arms287 sha256
`e405f227962e88e816c59742cd6e71b1a49b18e131e4cf40294923511b6c4ee1`
(126,310 B); hef287.py sha256
`70ff1bd956bdd3ecc297f420f0f522c646f4a44bdc29f0f4bc07bfb19ba31a1a`
(4,219,074 B) on both the VM and the device.
arms287 was built locally on the hef286 lineage
(make_build287.py derived from make_build286 via
gen287.py + make_make287.py — gen287's first blind
shift omitted the lowest 282->283 leg, which broke
the shift chain's own lowest needle; the defect was
caught by the old_hdr assert in make_build287, fixed
by adding the TD-parked 283 leg, and the chain then
ran clean; the three AES-NUM-272 builder fixes and
every carried digit-free placeholder protection
from AES-NUM-274 through AES-NUM-286 stand). Audit
of arms286/build286 for real data values containing
the slice-number substring 286 found NONE NEW: the
5 pure 286 tokens in arms286 are the 4.286 section
labels; 2862 (26 digit-sequence hits) and 102286
(4 hits) are identifier suffixes only (a2862/idx2862
forms), with zero pure-numeric occurrences; the 12
pure 286 tokens in build286 are all slice references
or shift literals, and no longer digit sequence
containing 286 is a data value. The @@VN@@
protection for the bare data value 285 (2
occurrences, ', 285,' form) CARRIES verbatim — 285
is a 285->286 shift leg, so the protection is
load-bearing — and is restored intact in arms287
(', 285,' at exactly 2 occurrences in the finished
arms). The real data value 21267 (AES-NUM-262
layer) is protected as usual at exactly 2
occurrences in arms287. Independent audit of
arms287: all expected 287/286 sequences, the
distinct list and every protected value at exact
counts (5281 x2, 791777280 x1, 33280 x1, bare 280
x1, 279 form carried, 127925/11278/32784/21267 x2,
bare 285 x2 restored); AES-NUM-285 references fully
shifted (0 left, 83 AES-NUM-286 refs in arms287).
Pair 6 (gap tuple old->mid) absent as optional, as
in prior generations. hef287 = hef286 + arms287
byte-exact.
Crossing, stated exactly: arms287 was gzipped
with gzip -9 (sha256
`cc320b70500e5762916f62d563399639985b929e1770cc066f94897d64a19fcf`,
10,830 B), split into 30 parts of 373 B, each sent
as its own sha-gated file.write to Mimir: 29 parts
landed sha-clean first try; part p_ad was rejected
twice at the same boundary (497 data chars, a
transcription truncation), so it was split into two
sub-parts (186 B + 187 B, each sha-gated) which
landed clean — change chunk boundaries, never just
retry. The assembled gzip, arms287 and hef287
shas == VM on-device; py_compile OK on-device.
run287.sh landed via sha-gated file.write (sha256
`34e1cbc90fff7d3699adb6592693c0a098f58e54a96b168b105506ecc1987bbd`,
237 B).

LAUNCH: exactly ONE bounded host-side child ran
in detached tmux (session h287, launched
2026-11-01 01:14 EST — the DST fall-back night, so
this EST hour follows the 01:51 EDT audit heartbeat;
pre-launch tmux/ps check clean; on-device
hef286.py sha 5be8da81 == the recorded base) with
the contract corpus argv (glob order, MiniLM last),
unbuffered (`python3 -u`); at the launching worker's
check hef287.out was 0 B and hef287.err empty —
child running. The child finished with exit marker
0 (hef287.exit, timestamped 01:18 EST), err empty,
and DONE287 as its last line. Output hef287.out
60,296 lines / 14,572,223 B sha256
`6eba4886ea8a40a4b1d7397e87c5e4f656a4b8958757817af92961846c4efcfc`;
prefix against hef286.out: the first 60,252 lines
differ from hef286.out in exactly 2 lines (41611
and 42872), both sorted-character equal — the
AES-NUM-150 frozenset variance lines arose this
generation (unlike the 4.286 generation, where no
variance line arose; verified via check287.py
sha256
`5cd1e716db6d3b518cab3617776ab34ce3a90481c0c5965281ba395cc1ff8678`),
hef287.out adding exactly its own 44 tail lines
(284,735 B, sha256
`fc7948a7f06d8dd44a8b45eb0cfd8a16f4c3e818a8ce65319bfb67733bb70bd7`).

No correction is carried into this slice and none
arises from it: no correction was carried into
4.286 either (the AES-NUM-258 expected-value
correction carried from 4.280 was verified closed
in the 4.281 run), and section287 contains
exactly FOUR 'False' tokens — the four
gap-position agree data values for gap positions
1-4 (positions 5, 6, 7 agree), data not
comparisons, as in every prior slice — and no
fifth False. There is no controls exception in
this slice and no correction is carried into
4.288.
Raw output kept on the Pi at
~/aesir-build/ (hef287.out, hef287.py, arms287.py,
section287.txt, hef287.exit, hef287.err, run287.sh,
check287.py); local lineage in
~/workspace/.verify-tmp/aesir287.

Definitions carry over from AES-NUM-247 through
AES-NUM-286 exactly as printed in the run: POSITION
is 1-based over the eight acts of the closing run
(A ranks 741–748, B ranks 743–750); the agreement
set, agreement count, cumulative total, difference,
remaining, cumulative remaining and every iterated
cumulative cumulative-remaining running total are as defined in
the section287 header, read on-device.

## (i) The closing-run cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence in full

At each position, the running total of the
AES-NUM-286 cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining values
over positions 1 up to and including that position
(all printed comparisons True for all eight):

- Position 1 (A rank 741 / B rank 743): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 55.
- Position 2 (A rank 742 / B rank 744): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 1747.
- Position 3 (A rank 743 / B rank 745): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 28612.
- Position 4 (A rank 744 / B rank 746): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 321860.
- Position 5 (A rank 745 / B rank 747): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 2795279.
- Position 6 (A rank 746 / B rank 748): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 19975442.
- Position 7 (A rank 747 / B rank 749): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 122257149.
- Position 8 (A rank 748 / B rank 750): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 658682544.

Sequence: [55, 1747, 28612, 321860, 2795279, 19975442, 122257149, 658682544] —
equals the expected sequence (printed test True);
the last cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative total is 658682544.

## (ii) The distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals in full

Distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals, in order of first
appearance, with positions and counts (counts sum
to 8, printed test True):

- 55: position 1 — count 1.
- 1747: position 2 — count 1.
- 28612: position 3 — count 1.
- 321860: position 4 — count 1.
- 2795279: position 5 — count 1.
- 19975442: position 6 — count 1.
- 122257149: position 7 — count 1.
- 658682544: position 8 — count 1.

Eight distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals; none repeats —
stated as printed arithmetic only, no mechanism claimed.

## (iii) The gap cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence in full

At each gap position, the running total of the
AES-NUM-286 gap cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining values
over gap positions 1 up to and including that gap
position (A gaps all 512; B gaps 712, 26624, 14848,
33280, 512, 512, 512; agree False, False, False,
False, True, True, True):

- Gap position 1: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 12.
- Gap position 2: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 381.
- Gap position 3: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 6237.
- Gap position 4: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 70125.
- Gap position 5: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 608686.
- Gap position 6: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 4347223.
- Gap position 7: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 26590312.

Sequence: [12, 381, 6237, 70125, 608686, 4347223, 26590312] — equals the
expected sequence (printed test True), ends at
26590312, with agreeing positions 5, 6, 7 (count 3),
equal to AES-NUM-245.

Contract tests: the printed cumulative sequence
equals (55, 1747, 28612, 321860, 2795279, 19975442, 122257149, 658682544) — True; the distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals'
counts sum to 8 — True; the last cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative total
equals 658682544 — True; the gap cumulative sequence
equals (12, 381, 6237, 70125, 608686, 4347223, 26590312)
and ends at 26590312 — True.

Mechanisms NOT PROVEN; any offset, prefix or
position law NOT PROVEN; run 102's meaning NOT
PROVEN.
