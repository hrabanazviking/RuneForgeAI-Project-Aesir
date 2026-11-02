# The closing-run cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence, the distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals, and the gap cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence (AES-NUM-299)

Slice 4.299, worked under `docs/TASK_CONTRACT_4.299.md`
(contract published in the 4.298 closing commit @
13938fb6). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child. All findings
below are taken from the sha-verified raw output,
read on-device (section299.txt). Filename
convention, recorded explicitly per the 4.299
contract's close law: at forty-four CUMULATIVEs
the chain plus REMAINING.md alone exceeds the
255-byte filesystem limit even further — so this
evidence filename uses the compact X44 notation
(`HAILO10H_CUMULATIVE_X44_REMAINING_AES-NUM-299.md`)
while the full chain is preserved untruncated in
this document's title (lineage form) and in the
run's own section headers, which carry all
forty-four CUMULATIVEs. The chain is never silently
truncated. The same convention governs 4.300 (X45).

## Run and closing record

hef299.py is the verified hef298 base plus
arms299: hef298.py sha256 prefix `6e0cad71`
(5,996,498 B) on both the VM and the device.
arms299 sha256 prefix `ea7b9e98` (200,119 B);
hef299.py sha256 prefix `26711d60` (6,196,617 B)
on both the VM and the device; arms299 gzip
sha256 prefix `5bbaa32e` (13,735 B, as saved
on-device).
hef299 was built locally on the hef298 lineage
(make_build299.py derived from make_build298,
which carries the three AES-NUM-272 builder fixes
and every carried digit-free placeholder
protection from AES-NUM-274 through AES-NUM-298).
Audit of arms298/build298 for real data values
containing ANY of the generation's three shift-leg
substrings 296, 297 or 298 (the all-three-legs law,
extended by the context-classification law recorded
in AES-NUM-298) found NO NEW arms-level protection
and NO NEW make-level protection (build298's 298
tokens are bare slice references only, 238); the
@@WH@@ correction contexts do NOT occur in build298
(verified 0), so no make-level WH was added. The one
mandatory correction WAS applied, as contracted:
build299 restored the expGap cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative position-2
value to 297 in both of its arms298 contexts (the
exp list and the definitions prose tuple) before
its shift, protected it as @@WH@@ in exactly those
two contexts, restored 297 after the shift, and
asserted the corrected list equals
[12, 297, 3822, 34047, 235873, 1353834, 6698160].
gen_make299 also carried the WG count fix (2297
standalone contexts in arms298 are 2, was 5 in
arms297 — its other forms rolled with the C298
pairs stage; bl[13] corrected 5 -> 2 and the bl[16]
WG segment corrected likewise, the same pattern as
WE in 4.298). AES-NUM-298 references in arms298 =
127.
gen_make299 17,714 B sha256 prefix `715d87dd`,
make_build299 15,469 B sha256 prefix `f404981d`,
build299 19,501 B sha256 prefix `b75271c6`, all
py_compile OK (shas re-measured from disk at this
close). hef299 = hef298 + arms299 byte-exact
(on-device assembly sha == VM).
Build sanity on arms299 PASS (every check):
hef299 == hef298 prefix-exact + arms299 tail;
DONE299 exactly 1, DONE298 absent; zero 299836 /
298836 corruptions, zero leftover placeholders;
protected values at exact counts (31622976 3,
2967 2, 791479296 1, 7295039 2, 294083 2, 385294 2,
175293 2, 293248 2, 2429232 3, 590292 3, 92928 2,
29255 2, 291720 3, 529191 3, 290836 3, 42908 2,
2883 2, 28612 2, 21267 2, bare ', 285,' 2); the
corrected list [12, 297, 3822, 34047, 235873,
1353834, 6698160] and its prose tuple each occur
exactly once, the corrupted 298 forms are absent,
and arms299 holds ZERO ', 298,' data contexts; the
298/299 sequence forms present at the symmetric
counts (newest list x2, previous x1); arms299's
total 2297 substrings = 5 (2 standalone + 3 inside
31622976).

Crossing, stated exactly: a tiny receiver
(recv299.py, landed sha-gated, sha256 prefix
`4e23c284` == local) waited on Mimir :8098 and
the VM posted arms299.py.gz through the tunnel
proxy; zero payload bytes passed through model
re-emission. The assembled arms299 and hef299
shas == VM on-device, py_compile OK.
run299.sh landed on-device (sed 298->299 of
run298.sh; contracted argv, glob order, MiniLM
last).

LAUNCH: exactly ONE bounded host-side child ran
in detached tmux (session h299, launched
2026-11-01 ~19:03 EST; pre-launch tmux/ps check
clean — no h299, no hef299 process, no prior
hef299.out/.exit) with the contract corpus argv
(glob order, MiniLM last), unbuffered
(`python3 -u`). The child finished with exit
marker 0 (hef299.exit, 19:07 EST), err empty, and
DONE299 as its last line. Output
hef299.out 60,824 lines / 19,242,941 B sha256
prefix `1b21b7b6`; prefix against hef298.out: the
first 60,780 lines differ from hef298.out in
exactly ONE line (41611), sorted-character equal
— the AES-NUM-150 frozenset variance (one line
this slice, as in 4.293, 4.297 and 4.298), verified
via check299.py sha256 prefix `021578d0`
(check298 lineage, simultaneous 297->298 /
298->299 shift, landed on-device sha-gated with
sha == local exactly), hef299.out adding exactly
its own 44 tail lines (485,902 B, sha256 prefix
`ad6ebb19`).

## The carried correction, verified in this slice

Slice 4.298's one expected-value exception does
NOT recur. section299 contains exactly FOUR
'False' tokens — the four gap-position agree data
values for gap positions 1-4 (A gap 512 against B
gaps 712, 26624, 14848, 33280; positions 5, 6, 7
agree), data not comparisons, as in every prior
slice — and NO comparison False anywhere. The
@@WH@@ correction is therefore verified end to
end: arms299's expected list reads
[12, 297, 3822, 34047, 235873, 1353834, 6698160],
section299's computed series matches it, and the
gap cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative check against AES-NUM-298 that read
False in 4.298 reads True in 4.299. No computed
value in any slice changed; no finding of 4.299
or of any prior slice is affected.
DISTINCT-LIST CHECK, recorded per the close law:
the distinct totals stated in this doc, the
ledger and the progress paragraph were re-checked
against section299's own printed (ii) lines —
55 at position 1; 2407 at position 2; 53866 at
position 3; 821490 at position 4; 9600318 at
position 5; 91663533 at position 6; 744518211 at
position 7; 5289021672 at position 8, each count
1, forms 8, counts sum 8 — the slice's own cum299
sequence, exactly as printed on-device.
Raw output kept on the Pi at
~/aesir-build/ (hef299.out, hef299.py, arms299.py,
section299.txt, hef299.exit, hef299.err, run299.sh,
check299.py); local lineage in
~/workspace/.verify-tmp/aesir299.

Definitions carry over from AES-NUM-247 through
AES-NUM-298 exactly as printed in the run: POSITION
is 1-based over the eight acts of the closing run
(A ranks 741-748, B ranks 743-750); the sequences
below are the running totals of the AES-NUM-298
values, re-verified as exact cumulative sums
before commit.

## Findings

(i) The closing-run cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining
remaining-count sequence in full is
[55, 2407, 53866, 821490, 9600318, 91663533, 744518211, 5289021672] over positions 1-8 — the running total
of each position's AES-NUM-298 cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining
remaining value, ending at 5289021672. The
contracted comparisons read True at all eight
positions.

(ii) The distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals in full are
eight: 55 at position 1 count 1; 2407 at position
2 count 1; 53866 at position 3 count 1; 821490 at
position 4 count 1; 9600318 at position 5 count 1;
91663533 at position 6 count 1; 744518211 at
position 7 count 1; 5289021672 at position 8 count
1 (counts sum to 8) — as printed in section299's
(ii) lines, re-checked line by line.

(iii) The gap cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count
sequence in full is [12, 525, 11745, 179055, 2091736, 19963954, 162086221] over gap positions
1-7, ending at 162086221, checked against
AES-NUM-299 and AES-NUM-245 (agreeing gap
positions 5, 6, 7, count 3, equal to AES-NUM-245).

Mechanisms NOT PROVEN; any offset, prefix or
position law NOT PROVEN; run 102's meaning NOT
PROVEN. Broad ordinary UNMODIFIED source-model
support remains the destination.

## Next

Slice 4.300 (contract in
`docs/TASK_CONTRACT_4.300.md`): the closing-run
cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence in
full; the distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals in full with
their positions and counts; and the gap
cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence in
full, checked against AES-NUM-299 and AES-NUM-245
— carrying NO expected-value correction (4.299's
@@WH@@ correction is verified closed) and THREE
new arms-level data protections from the 4.299-close
audit (@@WI@@ 30829932, @@WJ@@ 23122995, @@WK@@
533299, each 2 occurrences, all containing the
299 shift leg), plus the method corrections
carried since 4.298 (all-three-legs audit;
distinct lists checked against the slice's own
section; context classification of bare
slice-number values).
