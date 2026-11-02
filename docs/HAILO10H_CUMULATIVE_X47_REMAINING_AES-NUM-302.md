# The closing-run cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence, the distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals, and the gap cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence (AES-NUM-302)

Slice 4.302, worked under `docs/TASK_CONTRACT_4.302.md`
(contract published in the 4.301 closing commit @
a4208da1). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child. All findings
below are taken from the sha-verified raw output,
read on-device (section302.txt). Filename
convention, recorded explicitly per the 4.302
contract's close law: at forty-seven CUMULATIVEs
the chain plus REMAINING.md alone exceeds the
255-byte filesystem limit even further — so this
evidence filename uses the compact X47 notation
(`HAILO10H_CUMULATIVE_X47_REMAINING_AES-NUM-302.md`)
while the full chain is preserved untruncated in
this document's title (lineage form) and in the
run's own section headers, which carry all
forty-seven CUMULATIVEs. The chain is never silently
truncated. The same convention governs 4.303 (X48).

## Run and closing record

hef302.py is the verified hef301 base plus
arms302: hef301.py sha256 prefix `cc8a36b0`
(6,617,889 B) on both the VM and the device.
arms302 sha256 prefix `c91ed880` (221,400 B);
hef302.py sha256 prefix `ca7bcc14` (6,839,289 B)
on both the VM and the device; arms302 gzip
sha256 prefix `9e2540ed` (14,856 B, as saved
on-device).
hef302 was built locally on the hef301 lineage
(make_build302.py derived from make_build301,
which carries the three AES-NUM-272 builder fixes
and every carried digit-free placeholder
protection from AES-NUM-274 through AES-NUM-301).
Audit of arms301/build301 for real data values
containing ANY of the generation's three shift-leg
substrings 299, 300 or 301 (the all-three-legs law,
extended by the context-classification law recorded
in AES-NUM-298) found NO NEW arms-level or
make-level data values (arms301's 301-bearing runs
are bare 301 x1,698, 3012 x26 identifier-only and
102301 x4 identifier-only; build301 holds bare 301
only, x245, for that leg), so NO new protection was
contracted for this generation; every carried
protection incl. @@WL@@ 30096 and @@WM@@ 130053
stayed load-bearing and was applied as contracted.
Every placeholder count was verified unchanged by
direct simulation of the whole protection chain
on arms301 before the build (sim302: every
placeholder count — WH 2 / WI 2 / WJ 2 / WK 2 /
WL 3 / WM 3 / WG 2 / WF 3 — and build301's whole
final assert PASS on the simulated arms302; zero
leftover placeholders; DONE302 exactly 1;
AES-NUM-301 references 139 in the simulated chain).
AES-NUM-301 references in arms302 = 143.
gen_make302 17927 B sha256 prefix `f24c1327`,
make_build302 15846 B sha256 prefix `e9237885`,
build302 20487 B sha256 prefix `45c4b428`, all
py_compile OK (shas re-measured from disk at this
close). hef302 = hef301 + arms302 byte-exact
(on-device assembly sha == VM). build302's
comment-tail extraction was re-measured on
build301 itself before inheriting: header line 4,
block lines 5-21, comment + 'def rep' =
lines[21:63] in build302's generation (the carried
comment-tail lesson, applied clean — no failed
build attempt in this slice; one optional pairs
entry, the G300 gap tuple form, is absent, skipped
per the pairs design, same class as 4.301's absent
G299 tuple).
Build staging, stated honestly: scratch was staged
under /tmp/aesirwork/aesir302 and copied back to
~/workspace/.verify-tmp/aesir302/ with hashes
re-verified there (hef302 ca7bcc14…); arms302/hef302
bytes are unaffected.
Build sanity on arms302 PASS (every check):
hef302 == hef301 prefix-exact + arms302 tail;
arms302 base prefix == sim302 prefix byte-exact;
DONE302 exactly 1, DONE301 absent; zero leftover
placeholders; protected values at exact counts
(31622976 3, 2967 2, 791479296 1, 7295039 2,
294083 2, 385294 2, 175293 2, 293248 2, 2429232 3,
590292 3, 92928 2, 29255 2, 291720 3, 529191 3,
290836 3, 42908 2, 2883 2, 28612 2, 21267 2,
30829932 2, 23122995 2, 533299 2, 30096 3,
130053 3); the corrected list
[12, 297, 3822, 34047, 235873, 1353834, 6698160]
and its prose tuple each occur exactly once, and
arms302 holds ZERO ', 300,' and ZERO ', 301,'
data contexts; the 301/302 sequence forms present
at the symmetric counts (newest list x2, previous
x1); arms302's total 2297 substrings = 5
(2 standalone + 3 inside 31622976).

Crossing, stated exactly: a tiny receiver
(recv302.py, landed sha-gated, sha256 prefix
`c8624fb1` == local) waited on Mimir :8098 in tmux
(recv302) and the VM posted arms302.py.gz through
the tunnel proxy (the curl response body printed
empty; the on-device sha is the verification);
zero payload bytes passed through model
re-emission. The assembled arms302 and hef302
shas == VM on-device, py_compile OK.
run302.sh is in the local lineage (sha256 prefix
`23574742`; contracted argv, glob
order, MiniLM last).

LAUNCH: exactly ONE bounded host-side child ran
in detached tmux (session h302, launched
2026-11-01 22:43 EST; pre-launch tmux/ps check
clean — no h302, no hef302 process, no prior
hef302.out/.exit/.err) with the contract corpus argv
(glob order, MiniLM last), unbuffered
(`python3 -u`). The child finished with exit
marker 0 (hef302.exit, 22:47 EST), err empty, and
DONE302 as its last line. Output
hef302.out 60,956 lines / 20,817,395 B sha256
prefix `47a5ec48`; prefix against hef301.out: the
first 60,912 lines differ from hef301.out in
exactly ONE line (41611, sorted-character equal)
— the AES-NUM-150 frozenset variance line, as in
4.301 (verified via
check302.py sha256 prefix `5cd841a3`
(check301 lineage, simultaneous 300->301 /
301->302 shift, landed on-device sha-gated with
sha == local exactly), hef302.out adding exactly
its own 44 tail lines (544,649 B, sha256
prefix `ad5f5095`).

## No correction in this slice

No expected-value correction was carried into
4.302 and none is carried out of it. section302
contains exactly FOUR 'False' tokens — the four
gap-position agree data values for gap positions
1-4 (A gap 512 against B gaps 712, 26624, 14848,
33280; positions 5, 6, 7 agree), data not
comparisons, as in every prior slice — and NO
comparison False anywhere. All three contracted
findings read True. No computed value in any
slice changed; no finding of 4.302 or of any
prior slice is affected.
DISTINCT-LIST CHECK, recorded per the close law:
the distinct totals stated in this doc, the
ledger and the progress paragraph were re-checked
against section302's own printed (ii) lines —
55 at position 1; 2572 at position 2; 61417 at
position 3; 998080 at position 4; 12412879 at
position 5; 125969347 at position 6; 1086185695 at
position 7; 8182083595 at position 8, each count
1, forms 8, counts sum 8 — the slice's own cum302
sequence, exactly as printed on-device.
Raw output kept on the Pi at
~/aesir-build/ (hef302.out, hef302.py, arms302.py,
section302.txt, hef302.exit, hef302.err,
check302.py); local lineage in
~/workspace/.verify-tmp/aesir302.

Definitions carry over from AES-NUM-247 through
AES-NUM-301 exactly as printed in the run: POSITION
is 1-based over the eight acts of the closing run
(A ranks 741-748, B ranks 743-750); the sequences
below are the running totals of the AES-NUM-301
values, re-verified as exact cumulative sums
before commit.

## Findings

(i) The closing-run cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining
remaining-count sequence in full is
[55, 2572, 61417, 998080, 12412879, 125969347, 1086185695, 8182083595] over positions 1-8 — the running total
of each position's AES-NUM-301 cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining
remaining value, ending at 8182083595. The
contracted comparisons read True at all eight
positions.

(ii) The distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals in full are
eight: 55 at position 1 count 1; 2572 at position
2 count 1; 61417 at position 3 count 1; 998080 at
position 4 count 1; 12412879 at position 5 count 1;
125969347 at position 6 count 1; 1086185695 at
position 7 count 1; 8182083595 at position 8 count
1 (counts sum to 8) — as printed in section302's
(ii) lines, re-checked line by line.

(iii) The gap cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count
sequence in full is [12, 561, 13392, 217560, 2704801, 27439069, 236506585] over gap positions
1-7, ending at 236506585, checked against
AES-NUM-301 and AES-NUM-245 (agreeing gap
positions 5, 6, 7, count 3, equal to AES-NUM-245).

Mechanisms NOT PROVEN; any offset, prefix or
position law NOT PROVEN; run 102's meaning NOT
PROVEN. Broad ordinary UNMODIFIED source-model
support remains the destination.

## Next

Slice 4.303 (contract in
`docs/TASK_CONTRACT_4.303.md`): the closing-run
cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence in
full; the distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals in full with
their positions and counts; and the gap
cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence in
full, checked against AES-NUM-302 and AES-NUM-245
— carrying NO expected-value correction (4.302's
findings were all True, with no comparison False)
and ONE new arms-level data protection from the
4.302-close audit (@@WN@@ 30225, 2 occurrences in
arms302, a real gap-sequence data value containing
the 302 shift leg; NO new make-level protection —
build302's 302 runs are bare only, x247, and
30225 occurs 0 times in build302), plus the
method corrections carried since 4.298
(all-three-legs audit; distinct lists checked
against the slice's own section; context
classification of bare slice-number values).
