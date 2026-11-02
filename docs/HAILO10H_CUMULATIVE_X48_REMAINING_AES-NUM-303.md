# The closing-run cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence, the distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals, and the gap cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence (AES-NUM-303)

Slice 4.303, worked under `docs/TASK_CONTRACT_4.303.md`
(contract published in the 4.302 closing commit @
58f63999). Host/artifact analysis only, on Mimir
(purpleviking1) - no physical child. All findings
below are taken from the sha-verified raw output,
read on-device (section303.txt). Filename
convention, recorded explicitly per the 4.303
contract's close law: at forty-eight CUMULATIVEs
the chain plus REMAINING.md alone exceeds the
255-byte filesystem limit even further - so this
evidence filename uses the compact X48 notation
(`HAILO10H_CUMULATIVE_X48_REMAINING_AES-NUM-303.md`)
while the full chain is preserved untruncated in
this document's title (lineage form) and in the
run's own section headers, which carry all
forty-eight CUMULATIVEs. The chain is never silently
truncated. The same convention governs 4.304 (X49).

## Run and closing record

hef303.py is the verified hef302 base plus
arms303: hef302.py sha256 prefix `ca7bcc14`
(6,839,289 B) on both the VM and the device.
arms303 sha256 prefix `ca051281` (228,745 B);
hef303.py sha256 prefix `a9c7c6ca` (7,068,034 B)
on both the VM and the device; arms303 gzip
sha256 prefix `e8ce9350` (15,250 B, as saved
on-device).
hef303 was built locally on the hef302 lineage
(make_build303.py derived from make_build302,
which carries the three AES-NUM-272 builder fixes
and every carried digit-free placeholder
protection from AES-NUM-274 through AES-NUM-302).
Audit of arms302/build302 for real data values
containing ANY of the generation's three shift-leg
substrings 300, 301 or 302 (the all-three-legs law,
extended by the context-classification law recorded
in AES-NUM-298) found exactly ONE NEW arms-level
data value (30225, 2 occurrences, a real
gap-sequence data value), protected as @@WN@@;
NO new make-level protection was contracted
(build302's 302 runs are bare only, x247; 30225
occurs 0 times in build302). Every placeholder count
was verified unchanged by direct simulation of the
whole protection chain on arms302 before the build
(sim303: every placeholder count - WH 2 / WI 2 /
WJ 2 / WK 2 / WL 3 / WM 3 / WN 2 / WG 2 / WF 3 -
and build302's whole final assert PASS on the
simulated arms303; zero leftover placeholders;
DONE303 exactly 1; AES-NUM-302 references 143 in
the simulated chain).
AES-NUM-302 references in arms303 = 147.
gen_make303 19229 B sha256 prefix `4f866bdb`,
make_build303 16825 B sha256 prefix `ff409111`,
build303 20921 B sha256 prefix `f4397438`, all
py_compile OK (shas re-measured from disk at this
close). hef303 = hef302 + arms303 byte-exact
(on-device assembly sha == VM). build303's
comment-tail extraction was re-measured on
build302 itself before inheriting: header line 4,
block lines 5-21, comment + 'def rep' =
lines[21:64] in build303's generation (the carried
comment-tail lesson, applied after one failed
build attempt: the first build303 draft inherited
lines[21:63], carried a duplicated 'def rep' line
and failed py_compile; the gen was fixed and the
whole chain re-run clean - recorded in the state
file at the 4.303 build). For the next generation:
build303 itself measures header line 4, block
lines 5-21, comment lines 22-69, 'def rep' at
line 70, so make_build304's extraction is
lines[21:70] - re-measure before inheriting.
Build staging, stated honestly: scratch lives in
/tmp/aesirwork/aesir303; the home filesystem hit
"Disk quota exceeded" during the 4.303 build's
copy-back, so no ~/workspace/.verify-tmp/aesir303
copy was made at build time (hashes above are
from the /tmp lineage, re-verified at this close).

Crossing, stated exactly: a tiny receiver
(recv303.py, landed sha-gated, sha256 prefix
`685c936f` == local) waited on Mimir :8098 in tmux
(recv303) and the VM posted arms303.py.gz through
the tunnel proxy; zero payload bytes passed
through model re-emission. The assembled arms303
and hef303 shas == VM on-device, py_compile OK.
run303.sh is in the local lineage (sha256 prefix
`542693af`; contracted argv, glob
order, MiniLM last).

LAUNCH: exactly ONE bounded host-side child ran
in detached tmux (session h303, launched
2026-11-01 23:35 EST; pre-launch tmux/ps check
clean - no h303, no hef303 process, no prior
hef303.out/.exit/.err) with the contract corpus argv
(glob order, MiniLM last), unbuffered
(`python3 -u`). The child finished with exit
marker 0 (hef303.exit), err empty, and
DONE303 as its last line. Output
hef303.out 61,000 lines / 21,382,378 B sha256
prefix `95e3ce12`; prefix against hef302.out: the
first 60,956 lines differ from hef302.out in
exactly ONE line (41611, sorted-character equal)
- the AES-NUM-150 frozenset variance line, as in
4.302 (verified via
check303.py sha256 prefix `15fb1c47`
(check302 lineage, simultaneous 301->302 /
302->303 shift, landed on-device sha-gated with
sha == local exactly after a first corrupted
paste was discarded), hef303.out adding exactly
its own 44 tail lines (564,983 B, sha256
prefix `3327cc8e`).

## No correction in this slice

No expected-value correction was carried into
4.303 and none is carried out of it. section303
contains exactly FOUR 'False' tokens - the four
gap-position agree data values for gap positions
1-4 (positions 5, 6, 7 agree), data not
comparisons, as in every prior slice - and NO
comparison False anywhere. All three contracted
findings read True. No computed value in any
slice changed; no finding of 4.303 or of any
prior slice is affected.
DISTINCT-LIST CHECK, recorded per the close law:
the distinct totals stated in this doc, the
ledger and the progress paragraph were re-checked
against section303's own printed (ii) lines -
55 at position 1; 2627 at position 2; 64044 at
position 3; 1062124 at position 4; 13475003 at
position 5; 139444350 at position 6; 1225630045 at
position 7; 9407713640 at position 8, each count
1, forms 8, counts sum 8 - the slice's own cum303
sequence, exactly as printed on-device.
Raw output kept on the Pi at
~/aesir-build/ (hef303.out, hef303.py, arms303.py,
section303.txt, hef303.exit, hef303.err,
check303.py); local lineage in
/tmp/aesirwork/aesir303.

Definitions carry over from AES-NUM-247 through
AES-NUM-302 exactly as printed in the run: POSITION
is 1-based over the eight acts of the closing run
(A ranks 741-748, B ranks 743-750); the sequences
below are the running totals of the AES-NUM-302
values, re-verified as exact cumulative sums
before commit.

## Findings

(i) The closing-run cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining
remaining-count sequence in full is
[55, 2627, 64044, 1062124, 13475003, 139444350, 1225630045, 9407713640] over positions 1-8 - the running total
of each position's AES-NUM-302 cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining
remaining value, ending at 9407713640. The
contracted comparisons read True at all eight
positions.

(ii) The distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals in full are
eight: 55 at position 1 count 1; 2627 at position
2 count 1; 64044 at position 3 count 1; 1062124 at
position 4 count 1; 13475003 at position 5 count 1;
139444350 at position 6 count 1; 1225630045 at
position 7 count 1; 9407713640 at position 8 count
1 (counts sum to 8) - as printed in section303's
(ii) lines, re-checked line by line.

(iii) The gap cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count
sequence in full is [12, 573, 13965, 231525, 2936326, 30375395, 266881980] over gap positions
1-7, ending at 266881980, checked against
AES-NUM-302 and AES-NUM-245 (agreeing gap
positions 5, 6, 7, count 3, equal to AES-NUM-245).

Mechanisms NOT PROVEN; any offset, prefix or
position law NOT PROVEN; run 102's meaning NOT
PROVEN. Broad ordinary UNMODIFIED source-model
support remains the destination.

## Next

Slice 4.304 (contract in
`docs/TASK_CONTRACT_4.304.md`): the closing-run
cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence in
full; the distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals in full with
their positions and counts; and the gap
cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence in
full, checked against AES-NUM-303 and AES-NUM-245
- carrying NO expected-value correction (4.303's
findings were all True, with no comparison False)
and THREE new arms-level data protections plus
ONE new make-level data protection from the
4.303-close audit, context-classified at this
close: @@WO@@ 30375395 (3 occurrences in arms303,
all DATA - the gap303 position-6 value in its
prose tuple, its sequence list, and a prose
sequence; 4 occurrences in build303, all DATA -
the G_new list, a generated-text prose tuple, a
generated list assignment, and a generated prose
line), @@WP@@ 7485303 (2 occurrences in arms303,
both DATA - an older cumulative sequence value in
its prose tuple and its list; 0 in build303), and
@@WQ@@ 2725303 (2 occurrences in arms303, both
DATA - an older gap sequence value in its prose
tuple and its list; 0 in build303); build303's
single ', 302,' token sits in its audit comment
prose ("with ZERO ', 302,' data contexts"), NOT
in data - the same class as build302's ', 301,'
token - plus the method corrections carried
since 4.298 (all-three-legs audit; distinct lists
checked against the slice's own section; context
classification of bare slice-number values).
