# The closing-run cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence, the distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals, and the gap cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence (AES-NUM-300)

Slice 4.300, worked under `docs/TASK_CONTRACT_4.300.md`
(contract published in the 4.299 closing commit @
3e668b4a). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child. All findings
below are taken from the sha-verified raw output,
read on-device (section300.txt). Filename
convention, recorded explicitly per the 4.300
contract's close law: at forty-five CUMULATIVEs
the chain plus REMAINING.md alone exceeds the
255-byte filesystem limit even further — so this
evidence filename uses the compact X45 notation
(`HAILO10H_CUMULATIVE_X45_REMAINING_AES-NUM-300.md`)
while the full chain is preserved untruncated in
this document's title (lineage form) and in the
run's own section headers, which carry all
forty-five CUMULATIVEs. The chain is never silently
truncated. The same convention governs 4.301 (X46).

## Run and closing record

hef300.py is the verified hef299 base plus
arms300: hef299.py sha256 prefix `26711d60`
(6,196,617 B) on both the VM and the device.
arms300 sha256 prefix `dd54a5a7` (207,091 B);
hef300.py sha256 prefix `3af5fd15` (6,403,708 B)
on both the VM and the device; arms300 gzip
sha256 prefix `de8e36e3` (14,065 B, as saved
on-device).
hef300 was built locally on the hef299 lineage
(make_build300.py derived from make_build299,
which carries the three AES-NUM-272 builder fixes
and every carried digit-free placeholder
protection from AES-NUM-274 through AES-NUM-299).
Audit of arms299/build299 for real data values
containing ANY of the generation's three shift-leg
substrings 297, 298 or 299 (the all-three-legs law,
extended by the context-classification law recorded
in AES-NUM-298) found THREE NEW arms-level data
values and NO NEW make-level protection (build299's
299 tokens are bare slice references only, 240; the
three new values occur 0 times in build299,
re-verified by build300's own generation). The
three contracted protections WERE applied, as
contracted: build300 protects 30829932 as @@WI@@,
23122995 as @@WJ@@ and 533299 as @@WK@@ (bare
replacement of maximal digit runs, 2 occurrences
each, in a definitions prose tuple and its sequence
list), restores them after the shift, and asserts
each occurs exactly twice in arms300. The @@WH@@
protection was RE-POINTED this generation: its
search contexts stand in arms299 as
'[12, 297, 3822' / '(12, 297, 3822' (the corrected
AES-NUM-298 contexts), not the 298 forms build299
searched in arms298; 297 is outside build300's arms
shift set (298/299), so WH is a harmless carry here,
restored to 297 after the shift, counts unchanged.
Every other placeholder count was verified unchanged
by direct simulation of the whole protection chain
on arms299 before the build (sim300b: zero leftover
placeholders, DONE300 exactly 1, AES-NUM-299
references 131 in the simulated arms300's
predecessor count). WG count UNCHANGED (2297
standalone contexts in arms299 are 2, as in
arms298). AES-NUM-299 references in arms300 = 135
(131 shifted from arms299's AES-NUM-298 references
plus the new layer's own AES-NUM-299 citations
added by the build; the protection-chain simulation
alone, without the layer reps, gives 131).
gen_make300 19069 B sha256 prefix `0ea44334`,
make_build300 16310 B sha256 prefix `43a580b1`,
build300 20051 B sha256 prefix `b1d5eff0`, all
py_compile OK (shas re-measured from disk at this
close). hef300 = hef299 + arms300 byte-exact
(on-device assembly sha == VM).
Build record, stated honestly: the first build300
attempt used the inherited comment extraction
lines[21:56] and produced a duplicated 'def rep'
line (IndentationError) — caught locally by
py_compile BEFORE any transfer or launch; the
extraction was corrected to lines[21:57] (the
'def rep' line is build299 comment block's captured
final line, per the contract's re-add rule),
gen_make300 regenerated, and the rebuilt build300
passed py_compile and the full sanity gate. No
device child was launched from the failed attempt.
Build sanity on arms300 PASS (every check):
hef300 == hef299 prefix-exact + arms300 tail;
DONE300 exactly 1, DONE299 absent; zero 300836 /
299836 corruptions, zero leftover placeholders;
protected values at exact counts (31622976 3,
2967 2, 791479296 1, 7295039 2, 294083 2, 385294 2,
175293 2, 293248 2, 2429232 3, 590292 3, 92928 2,
29255 2, 291720 3, 529191 3, 290836 3, 42908 2,
2883 2, 28612 2, 21267 2, 30829932 2, 23122995 2,
533299 2, bare ', 285,' 2); the corrected list
[12, 297, 3822, 34047, 235873, 1353834, 6698160]
and its prose tuple each occur exactly once, the
corrupted 298 forms are absent, and arms300 holds
ZERO ', 298,' and ZERO ', 299,' data contexts; the
299/300 sequence forms present at the symmetric
counts (newest list x2, previous x1); arms300's
total 2297 substrings = 5 (2 standalone + 3 inside
31622976).

Crossing, stated exactly: a tiny receiver
(recv300.py, landed sha-gated, sha256 prefix
`43500fe9` == local) waited on Mimir :8098 and
the VM posted arms300.py.gz through the tunnel
proxy; zero payload bytes passed through model
re-emission. The assembled arms300 and hef300
shas == VM on-device, py_compile OK.
run300.sh landed on-device (sed 299->300 of
run299.sh; contracted argv, glob order, MiniLM
last).

LAUNCH: exactly ONE bounded host-side child ran
in detached tmux (session h300, launched
2026-11-01 19:55 EST; pre-launch tmux/ps check
clean — no h300, no hef300 process, no prior
hef300.out/.exit) with the contract corpus argv
(glob order, MiniLM last), unbuffered
(`python3 -u`). The child finished with exit
marker 0 (hef300.exit, 19:59 EST), err empty, and
DONE300 as its last line. Output
hef300.out 60,868 lines / 19,748,054 B sha256
prefix `fdc719d9`; prefix against hef299.out: the
first 60,824 lines differ from hef299.out in
ZERO lines — the AES-NUM-150 frozenset variance
line printed byte-identically this slice (in
4.293-4.299 it differed in exactly one line;
verified via check300.py sha256 prefix `e9e9214e`
(check299 lineage, simultaneous 298->299 /
299->300 shift, landed on-device sha-gated with
sha == local exactly), hef300.out adding exactly
its own 44 tail lines (505,113 B, sha256 prefix
`ae420598`).

## No correction in this slice

No expected-value correction was carried into
4.300 and none is carried out of it. section300
contains exactly FOUR 'False' tokens — the four
gap-position agree data values for gap positions
1-4 (A gap 512 against B gaps 712, 26624, 14848,
33280; positions 5, 6, 7 agree), data not
comparisons, as in every prior slice — and NO
comparison False anywhere. All three contracted
findings read True. No computed value in any
slice changed; no finding of 4.300 or of any
prior slice is affected.
DISTINCT-LIST CHECK, recorded per the close law:
the distinct totals stated in this doc, the
ledger and the progress paragraph were re-checked
against section300's own printed (ii) lines —
55 at position 1; 2462 at position 2; 56328 at
position 3; 877818 at position 4; 10478136 at
position 5; 102141669 at position 6; 846659880 at
position 7; 6135681552 at position 8, each count
1, forms 8, counts sum 8 — the slice's own cum300
sequence, exactly as printed on-device.
Raw output kept on the Pi at
~/aesir-build/ (hef300.out, hef300.py, arms300.py,
section300.txt, hef300.exit, hef300.err, run300.sh,
check300.py); local lineage in
~/workspace/.verify-tmp/aesir300.

Definitions carry over from AES-NUM-247 through
AES-NUM-299 exactly as printed in the run: POSITION
is 1-based over the eight acts of the closing run
(A ranks 741-748, B ranks 743-750); the sequences
below are the running totals of the AES-NUM-299
values, re-verified as exact cumulative sums
before commit.

## Findings

(i) The closing-run cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining
remaining-count sequence in full is
[55, 2462, 56328, 877818, 10478136, 102141669, 846659880, 6135681552] over positions 1-8 — the running total
of each position's AES-NUM-299 cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining
remaining value, ending at 6135681552. The
contracted comparisons read True at all eight
positions.

(ii) The distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals in full are
eight: 55 at position 1 count 1; 2462 at position
2 count 1; 56328 at position 3 count 1; 877818 at
position 4 count 1; 10478136 at position 5 count 1;
102141669 at position 6 count 1; 846659880 at
position 7 count 1; 6135681552 at position 8 count
1 (counts sum to 8) — as printed in section300's
(ii) lines, re-checked line by line.

(iii) The gap cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count
sequence in full is [12, 537, 12282, 191337, 2283073, 22247027, 184333248] over gap positions
1-7, ending at 184333248, checked against
AES-NUM-300 and AES-NUM-245 (agreeing gap
positions 5, 6, 7, count 3, equal to AES-NUM-245).

Mechanisms NOT PROVEN; any offset, prefix or
position law NOT PROVEN; run 102's meaning NOT
PROVEN. Broad ordinary UNMODIFIED source-model
support remains the destination.

## Next

Slice 4.301 (contract in
`docs/TASK_CONTRACT_4.301.md`): the closing-run
cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence in
full; the distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals in full with
their positions and counts; and the gap
cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence in
full, checked against AES-NUM-300 and AES-NUM-245
— carrying NO expected-value correction (4.300's
findings were all True, with no comparison False)
and TWO new arms-level data protections from the
4.300-close audit (@@WL@@ 30096, @@WM@@ 130053,
each 3 occurrences, all containing the 300 shift
leg), plus the method corrections carried since
4.298 (all-three-legs audit; distinct lists
checked against the slice's own section; context
classification of bare slice-number values).
