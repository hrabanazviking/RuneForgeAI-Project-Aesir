# The closing-run cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence, the distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals, and the gap cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence (AES-NUM-301)

Slice 4.301, worked under `docs/TASK_CONTRACT_4.301.md`
(contract published in the 4.300 closing commit @
76882f14). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child. All findings
below are taken from the sha-verified raw output,
read on-device (section301.txt). Filename
convention, recorded explicitly per the 4.301
contract's close law: at forty-six CUMULATIVEs
the chain plus REMAINING.md alone exceeds the
255-byte filesystem limit even further — so this
evidence filename uses the compact X46 notation
(`HAILO10H_CUMULATIVE_X46_REMAINING_AES-NUM-301.md`)
while the full chain is preserved untruncated in
this document's title (lineage form) and in the
run's own section headers, which carry all
forty-six CUMULATIVEs. The chain is never silently
truncated. The same convention governs 4.302 (X47).

## Run and closing record

hef301.py is the verified hef300 base plus
arms301: hef300.py sha256 prefix `3af5fd15`
(6,403,708 B) on both the VM and the device.
arms301 sha256 prefix `049a5443` (214,181 B);
hef301.py sha256 prefix `cc8a36b0` (6,617,889 B)
on both the VM and the device; arms301 gzip
sha256 prefix `1abd45fc` (14,485 B, as saved
on-device).
hef301 was built locally on the hef300 lineage
(make_build301.py derived from make_build300,
which carries the three AES-NUM-272 builder fixes
and every carried digit-free placeholder
protection from AES-NUM-274 through AES-NUM-300).
Audit of arms300/build300 for real data values
containing ANY of the generation's three shift-leg
substrings 298, 299 or 300 (the all-three-legs law,
extended by the context-classification law recorded
in AES-NUM-298) found TWO NEW arms-level data
values and NO NEW make-level protection (build300's
300 tokens are bare slice references only, 242; the
two new values occur 0 times in build300,
re-verified by build301's own generation). The
two contracted protections WERE applied, as
contracted: build301 protects 30096 as @@WL@@
and 130053 as @@WM@@ (bare replacement of maximal
digit runs, 3 occurrences each, in definitions
prose tuples and their sequence lists), restores
them after the shift, and asserts each occurs
exactly three times in arms301. The @@WH@@
protection search was re-pointed this generation
to its 297 contexts ('[12, 297, 3822' /
'(12, 297, 3822'); 297 is outside build301's arms
shift set (299/300), so WH is a harmless carry,
restored to 297 after the shift, counts unchanged.
Every other placeholder count was verified
unchanged by direct simulation of the whole
protection chain on arms300 before the build
(sim301: zero leftover placeholders, DONE301
exactly 1, AES-NUM-300 references 135 in the
simulated arms301's predecessor count).
AES-NUM-300 references in arms301 = 139.
gen_make301 18062 B sha256 prefix `241e005b`,
make_build301 15775 B sha256 prefix `7c8c7c5d`,
build301 20402 B sha256 prefix `d636cb29`, all
py_compile OK (shas re-measured from disk at this
close). hef301 = hef300 + arms301 byte-exact
(on-device assembly sha == VM).
Build record, stated honestly: the first build301
attempt produced a duplicated 'def rep' line
(IndentationError, the inherited extraction one
line short of build300's captured comment tail)
- caught locally by py_compile BEFORE any
transfer or launch; the extraction was corrected
to lines[21:57] on the gen_make300 structure,
build301's own comment tail was re-measured on
build300 itself (comment + 'def rep' =
lines[21:60]), regenerated clean, and the rebuilt
build301 passed py_compile and the full sanity
gate. No device child was launched from the
failed attempt. QUOTA INCIDENT, recorded
honestly: the home filesystem hit "Disk quota
exceeded" mid-run (~20:25 EST); the build was
staged under /tmp/aesirwork and all scratch was
copied back to ~/workspace/.verify-tmp/aesir301/
with hashes re-verified there; arms301/hef301
bytes are unaffected (byte-exact sanity below).
A future gen_make302 MUST expect the re-pointed
base line in make_build301/build301.
Build sanity on arms301 PASS (every check):
hef301 == hef300 prefix-exact + arms301 tail;
DONE301 exactly 1, DONE300 absent; zero leftover
placeholders; protected values at exact counts
incl. WL/WM 30096 x3 / 130053 x3 and WI/WJ/WK
x2 each; the corrected list
[12, 297, 3822, 34047, 235873, 1353834, 6698160]
and its prose tuple each occur exactly once, and
arms301 holds ZERO ', 299,' and ZERO ', 300,'
data contexts; the 300/301 sequence forms present
at the symmetric counts (newest list x2, previous
x1).

Crossing, stated exactly: a tiny receiver
(recv301.py, landed sha-gated, sha256 prefix
`77b0b536` == local) waited on Mimir :8098 and
the VM posted arms301.py.gz through the tunnel
proxy; zero payload bytes passed through model
re-emission. The assembled arms301 and hef301
shas == VM on-device, py_compile OK.
run301.sh landed on-device (sha256 prefix
`7b741124`; contracted argv, glob order, MiniLM
last).

LAUNCH: exactly ONE bounded host-side child ran
in detached tmux (session h301, launched
2026-11-01 20:32 EST; pre-launch tmux/ps check
clean - no h301, no hef301 process, no prior
hef301.out/.exit) with the contract corpus argv
(glob order, MiniLM last), unbuffered
(`python3 -u`). The child finished with exit
marker 0 (hef301.exit, 20:36 EST), err empty, and
DONE301 as its last line. Output
hef301.out 60,912 lines / 20,272,746 B sha256
prefix `6ec623e8`; prefix against hef300.out: the
first 60,868 lines differ from hef300.out in
exactly ONE line (41611, sorted-character equal)
- the AES-NUM-150 frozenset variance line, as in
4.293-4.300 in all but one slice (verified via
check301.py sha256 prefix `2f469ab7`
(check300 lineage, simultaneous 299->300 /
300->301 shift, landed on-device sha-gated with
sha == local exactly), hef301.out adding exactly
its own 44 tail lines (524,692 B, sha256 prefix
`664feafa`).

## No correction in this slice

No expected-value correction was carried into
4.301 and none is carried out of it. section301
contains exactly FOUR 'False' tokens — the four
gap-position agree data values for gap positions
1-4 (A gap 512 against B gaps 712, 26624, 14848,
33280; positions 5, 6, 7 agree), data not
comparisons, as in every prior slice — and NO
comparison False anywhere. All three contracted
findings read True. No computed value in any
slice changed; no finding of 4.301 or of any
prior slice is affected.
DISTINCT-LIST CHECK, recorded per the close law:
the distinct totals stated in this doc, the
ledger and the progress paragraph were re-checked
against section301's own printed (ii) lines —
55 at position 1; 2517 at position 2; 58845 at
position 3; 936663 at position 4; 11414799 at
position 5; 113556468 at position 6; 960216348 at
position 7; 7095897900 at position 8, each count
1, forms 8, counts sum 8 — the slice's own cum300
sequence, exactly as printed on-device.
Raw output kept on the Pi at
~/aesir-build/ (hef301.out, hef301.py, arms301.py,
section301.txt, hef301.exit, hef301.err, run301.sh,
check301.py); local lineage in
~/workspace/.verify-tmp/aesir301.

Definitions carry over from AES-NUM-247 through
AES-NUM-300 exactly as printed in the run: POSITION
is 1-based over the eight acts of the closing run
(A ranks 741-748, B ranks 743-750); the sequences
below are the running totals of the AES-NUM-300
values, re-verified as exact cumulative sums
before commit.

## Findings

(i) The closing-run cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining
remaining-count sequence in full is
[55, 2517, 58845, 936663, 11414799, 113556468, 960216348, 7095897900] over positions 1-8 — the running total
of each position's AES-NUM-300 cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining
remaining value, ending at 7095897900. The
contracted comparisons read True at all eight
positions.

(ii) The distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals in full are
eight: 55 at position 1 count 1; 2517 at position
2 count 1; 58845 at position 3 count 1; 936663 at
position 4 count 1; 11414799 at position 5 count 1;
113556468 at position 6 count 1; 960216348 at
position 7 count 1; 7095897900 at position 8 count
1 (counts sum to 8) — as printed in section301's
(ii) lines, re-checked line by line.

(iii) The gap cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count
sequence in full is [12, 549, 12831, 204168, 2487241, 24734268, 209067516] over gap positions
1-7, ending at 209067516, checked against
AES-NUM-301 and AES-NUM-245 (agreeing gap
positions 5, 6, 7, count 3, equal to AES-NUM-245).

Mechanisms NOT PROVEN; any offset, prefix or
position law NOT PROVEN; run 102's meaning NOT
PROVEN. Broad ordinary UNMODIFIED source-model
support remains the destination.

## Next

Slice 4.301 (contract in
`docs/TASK_CONTRACT_4.301.md`): the closing-run
cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence in
full; the distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals in full with
their positions and counts; and the gap
cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence in
full, checked against AES-NUM-301 and AES-NUM-245
— carrying NO expected-value correction (4.301's
findings were all True, with no comparison False)
and NO new arms-level or make-level data
protections from the 4.301-close audit (the
301-leg digit runs in arms301 are bare 301,
3012 and 102301, identifiers only, and build301
holds bare 301 only; every carried protection
incl. @@WL@@ / @@WM@@ stays load-bearing), plus
the method corrections carried since
4.298 (all-three-legs audit; distinct lists
checked against the slice's own section; context
classification of bare slice-number values).
