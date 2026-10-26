# The varying centres as sequence members, the other single-centre anchors graded, lane 1's pairs split by cell and group, and the +597 aligned region read in full: a varying centre inside a mid/thick sequence is always a start or an interior member whose local steps already belong to the host sequence — never an end, never a step the sequence does not already take; centres 40 and 43 sit in single rigid patterns; of the other anchors {7, 11, 95, 139}, 7, 11 and 95 are constant-like (they anchor unanimity in mid/thick strata and their extras continue them inside their own unanimous triples without exception) while 139 is neither (it anchors no divergent unanimous triple, has no extras, and is absent from the mirror pair, yet twice fills a cell 28 times and twice centres a unanimous word); lane 1's 224 pairs live in only 3 groups and 16 cells — the pooled width is one group's width (group (20, 32720): 216 lanes, 216 pairs, 216 diffs, 216 XORs), the other two groups are narrow (5 pairs sharing ONE XOR in (14, 9992); 3 pairs, 1 XOR in (19, 7712)), and byte 3's difference is NOT determined by A's byte 3 (35 of 61 values carry more than one difference; only the sign-flip values 0 and 128 are single-valued); the +597 aligned region agrees at 27 of its 31 positions — exactly the three shared runs of AES-NUM-121 with nothing between them — and differs at exactly four (144 positions 195, 196, 204, 205), where both sides share components 2 and 3 and differ only in component 1; cidx 267's occurrence profile is far lonelier than cidx 144's at the top (709 of its 842 acts corpus-unique against 170 of 245; mean count 14.88 against 49.26) while both contexts carry the identical high band (30 acts at count 271, 1 at 1,058, 2 at 1,060) (AES-NUM-122)

Slice 4.122, worked under `docs/TASK_CONTRACT_4.122.md`
(contract committed first @ d8948d8b). Host/artifact analysis
only, on Mimir (purpleviking1) — no physical child, no
device run of any kind. All findings below are taken from
the sha-verified raw output; where a closing summary
drafted en route misstated a number, the raw output's
number is the one recorded here.

## Run and closing record

hef122.py (hef121 lineage: hef120 base extraction +
arms121 + the new arms122) sha256
`9ef555ac8c1385ead4ef893a6cca1b86e89e9a88a8a49a1488f4035b993b3b1f`
(309,322 B); arms122.py sha256
`9307034c16f7b8c9cbeb2b45f06ee24ef55c7629482631cde0b8a329cfc91639`
(20,138 B), its gzip sha256
`835f684fc1ee29e2ae8b43b0ab04dcf15cece18b73103409a27c0cdf31e19ec1`.
Provenance, recorded honestly (corrected at closing
from the worker's full handoff, which superseded a
garbled interim summary): the arms gzip was split into
16 binary parts (15 × 373 B + 182 B), each landed on
Mimir as its own file via file.write with its own
whole-part sha256 gate — all 16 passed first try;
concatenated on-device, the whole-gzip and decompressed
arms sha256 both matched the VM exactly. hef122.py was
assembled on-device from the verified hef121 base plus
arms122, and its on-device sha256 matched the VM-built
file exactly before anything ran. One launch fault,
recorded: the first detached launch omitted the argv
corpus paths and died at base line 150 having produced
no analysis; it was relaunched with the 7 artifact
paths, detached via setsid, and ran to DONE122,
EXIT:0. (The inherited base itself was verified before
building: the VM's hef120 + arms121 reconstruction is
byte-identical to the recorded hef121.py, and Mimir's
/tmp/hef121.py carries that same sha.) The retrieved
output is 12,231 lines / 1,929,888 B, sha256
`11e2103a8a13521ce73113eebe552c589c09f3e590b957a9726d5868d6799764`;
the retrieved gzip sha256
`1159eedba095e87f4c6bf3d0f459a00177d77b63c0421ef1a4bb3af6048e49f8`
decompresses to exactly that sha256 (verified on the VM
at closing; DONE122 at output line 12,230).

## Controls

All inherited controls reproduce exactly. Cells 55,902,
observations 527,236; divergent triples 2,171 with
verdicts CONT 12,411 / BREAK 476 / INDET 2,365; thin
population 383 (315 L1 UNANIMOUS / 58 L2 UNANIMOUS / 10 L2
AP); ≥8 cells 25,566, unanimous 18,286, 29 centres;
differing lanes 2,584 by lane {0: 1,086, 1: 354, 2: 0,
3: 406, 4: 738}, in-37 differing 535; train 48 rank 2 =
cidx 144, start 8, steady (CONST_DOM, 7), with the
recorded 8-act head; divergent strata {1: 315, 2: 68,
3–7: 674, ≥8: 1,114}; lane 1 subset 354 lanes / 224
distinct pairs with pooled 218 distinct diffs / 217
distinct XORs; acts shared by cidx 267 and cidx 144: 36.

## (i) The varying centres as sequence members, and the other anchors

Every mid/thick (≥3 common instances) common sequence
containing a varying centre is NONAP — 137 occurrences in
137 sequences, no AP and no UNANIMOUS host. Position
classes pooled: start 33, interior 104, END ZERO. A
varying centre is never the last member of its host
sequence; its index-from-end is at least 2 in every one
of the 137. And in all 137, each local step touching the
varying centre (the step in, where it is not at the
start, and the step out, always present) already belongs
to the host sequence's own set of steps: the varying
centre introduces no foreign step into any sequence it
travels in.

Per centre:

- **32** — 80 occurrences in 80 sequences (36 mid, 44
  thick): start 33 (index 0), interior 47 (index 1 ×21,
  index 3 ×26; never index 2); index-from-end {2: 5,
  3: 13, 4: 22, 5: 14, 6: 14, 8: 12}; host lengths
  {4: 18, 6: 10, 7: 8, 8: 18, 9: 26}; previous centre
  {23: 15, 26: 26, 28: 6}; next centre {35: 51, 36: 12,
  40: 8, 44: 9}; local step pairs (in, out) {(4, 12): 6,
  (6, 3): 26, (9, 3): 15} plus starts {(–, 12): 3,
  (–, 3): 10, (–, 4): 12, (–, 8): 8}.
- **40** — 8 occurrences, ONE rigid pattern: always
  interior at index 1, index-from-end 5, host length 7,
  previous centre always 32, next always 44, steps
  (8, 4) in all 8. Centre 40 travels only immediately
  after centre 32 (the same 8 sequences are 8 of 32's
  next-40 cases above).
- **43** — 19 occurrences, one pattern shape: always
  interior at index 1, index-from-end 4, host length 6,
  next centre always 47; previous {27: 3, 31: 16}; steps
  {(12, 4): 16, (16, 4): 3} — the step out is always 4.
- **51** — 30 occurrences (29 mid, 1 thick): always
  interior; index {1: 10, 3: 19, 14: 1}; index-from-end
  {1: 10, 2: 19, 10: 1}; host lengths {3: 10, 6: 19,
  25: 1}; previous {39: 10, 47: 19, 48: 1}; next
  {54: 1, 55: 19, 59: 10}; steps {(12, 8): 10, (3, 3): 1,
  (4, 4): 19}.
- **85 and 122** — NO mid/thick common sequence contains
  either, confirming AES-NUM-121: beyond thin length 1
  they occur in no common sequence at all.

Read as distinct wholes, the hosts are few: 32's 80
occurrences ride on only **9 distinct sequences**
((32, 35, 47, 50) ×10 triples, (32, 44, 48, 56) ×3,
(23, 32, 35, 41) ×5, (32, 40, 44, 48, 52, 56, 68) ×8,
(23, 32, 35, 38, 41, 50) ×10, (20, 23, 26, 32, 35, 38,
41, 50) ×12, (32, 36, 44, 48, 52, 56, 60, 64, 68) ×12,
(20, 23, 26, 32, 35, 38, 41, 47, 50) ×14, (28, 32, 44,
48, 52, 56, 64, 68) ×6), carried by cidx 31 (47
occurrences) or cidx 126 (33). 40's eight hosts are
the single sequence (32, 40, 44, 48, 52, 56, 68). 43's
nineteen ride on two sequences only — (31, 43, 47, 51,
55, 67) ×16 and (27, 43, 47, 51, 55, 67) ×3 — and 51
co-occurs with 43 in all nineteen of those, at index 3
(prev 47, next 55, steps (4, 4)); 51's other forms are
(39, 51, 59) ×10 at index 1, and its single thick
occurrence at index 14 of a 25-long sequence (6, 12,
15, 18, …, 81) whose steps are 6 then 3 ×23 — NONAP by
the single 6 — where 51 sits on the 3-run (prev 48,
next 54, steps (3, 3)).

The other single-centre anchors, graded on AES-NUM-121's
own terms against the varying six:

- **7 — CONSTANT-LIKE.** Divergent UNANIMOUS-centre
  triples 27 (13 mid + 14 thick, none thin); ≥8 cells
  containing it 1,261, of them UNANIMOUS centred on it
  875; full cells 2,655 holding 17,690 observations, at
  most 27 per cell; UNANIMOUS-word cells centred on it
  2,122. Extras with centre 7: 41, ALL CONT, and inside
  its own UNANIMOUS-centred triples its extras equal it
  41/41 — the constant signature, at constant scale.
- **11 — CONSTANT-LIKE (weaker).** Divergent
  UNANIMOUS-centre triples 14 (4 mid + 10 thick); ≥8
  containing 814, UNANIMOUS centred 287; full cells
  1,099 / 5,537 obs, max 26 per cell; UNANIMOUS-word
  cells 459. Extras 137 (121 CONT / 11 BREAK / 5 INDET);
  inside its own UNANIMOUS-centred triples its extras
  equal it 97/97.
- **95 — CONSTANT-LIKE (weakest of the three).**
  Divergent UNANIMOUS-centre triples 5 (2 mid + 3
  thick); ≥8 containing 470, UNANIMOUS centred 73; full
  cells 619 / 2,060 obs, max 26 per cell; UNANIMOUS-word
  cells 207. Extras 8, all CONT, 8/8 inside its own.
- **139 — NEITHER.** Divergent UNANIMOUS-centre triples
  ZERO at every stratum, and it is a member of NO
  divergent triple at all; extras ZERO. Yet it is not
  varying-like either: ≥8 cells containing it 79, of
  them 2 UNANIMOUS centred on it; UNANIMOUS-word cells
  centred on it 2; its full-cell distribution is
  {1 ×77, 28 ×2} — twice it fills a cell 28 times, a
  multiplicity no varying centre ever reaches (every
  varying centre's per-cell count is exactly 1 in every
  cell). It is present in only four artifacts (0856a10c
  42 cells, 76c3a8ff 35, 5ab3537d 1, 773470cd 1) and
  ABSENT from cc9b9d1c, 0a0d378c and MiniLM — the mirror
  pair's deciding skeleton never contains it. It belongs
  to neither family on any measured axis.

For reference the varying six on the same grade lines:
UNANIMOUS-centre only at thin length 1 (11/11/11/9/10/10
for 32/40/43/51/85/122), 0 at every other stratum;
UNANIMOUS ≥8 centred 0 of {490, 618, 616, 577, 389, 47}
containing; UNANIMOUS-word cells 0; per-cell count
exactly 1 in all {674, 724, 770, 848, 509, 217} cells;
extras never equal to the centre inside member triples
(0 of {802, 94, 289, 361, 30, 20}) nor inside their own
UNANIMOUS-centred triples (0 of {99, 22, 121, 81, 30,
20}). The constant nine on the same lines anchor
unanimity in every stratum and their extras equal them
inside their own UNANIMOUS-centred triples without
exception (0: 282/282, 1: 245/245, 2: 143/143, 5:
1,482/1,482, 15: 7,676/7,676, 23: 697/697, 34: 118/118,
69: 78/78, 127: 928/928). Why any centre sits in the
family it does: NOT PROVEN.

## (ii) Lane 1's 224 pairs split by cell/group; the byte-3 law

The 224 pairs are concentrated far beyond the pooled
picture: they live in only **3 groups and 16 cells**.
Occurrences per pair: 219 pairs occur exactly once; 5
pairs occur 27 times each (219 + 5×27 = 354 lanes).
Every pair occurs in exactly ONE cell and exactly ONE
group ({1: 224} both ways).

By cell (16): lanes-per-cell {1: 3, 27: 13};
pairs-per-cell {1: 8, 27: 8}. The eight cells with one
pair apiece are the five (14, 9992) cells (27 lanes each,
the SAME pair repeated at 27 centres {7, 11, 15, …, 111})
and the three (19, 7712) cells (1 lane each, centres
{87}). The eight (20, 32720) cells carry 27 lanes and 27
DISTINCT pairs each (centres {127} throughout). Of the
units with ≥2 distinct pairs (the eight (20, 32720)
cells), ZERO are narrower than one diff and one XOR per
pair.

By group (3):
- **(14, 9992)** — 135 lanes, 5 distinct pairs, only **2
  distinct diffs and 1 distinct XOR**: all five pairs
  share a single XOR. The pooled narrowness AES-NUM-121
  could not find lives here, at group level.
- **(19, 7712)** — 3 lanes, 3 distinct pairs, 2 distinct
  diffs, **1 distinct XOR**.
- **(20, 32720)** — 216 lanes, **216 distinct pairs, 216
  distinct diffs, 216 distinct XORs**: maximally wide —
  this one group IS the pooled width (218/217 pooled
  against its 216/216; the small groups add only their
  few).

Byte 3 as a function of A's byte 3, over all 224 pairs
(occurrence-level control over the 354 lanes identical):
61 distinct A byte-3 values; **determination FALSE** —
35 of the 61 values carry more than one signed
difference. Band widths per value: max 26 (A = 206:
{−10, 2, 16}), mean 6.197. The pooled difference set is
the 24 values of AES-NUM-121. Structure inside the
failure: the differences cluster in [−11, +4] for A in
the high band (roughly 174–252 — e.g. A = 225: 11 pairs,
9 diffs {−11…2}; A = 242: 11 pairs, 8 diffs {−9…2};
A = 250: 12 pairs, 6 diffs {−7…0}), and the ONLY two
single-valued A byte-3 values with more than one pair
are the extremes **0 → +128 (2 pairs) and 128 → −128
(6 pairs)** — the sign-flip pairs, whose byte-3 XOR is
0x80. No narrower law is measured: not determined, not
confined to a per-value band of width < 26 anywhere it
matters. Source of the bijection NOT PROVEN.

## (iii) The +597 aligned region in full; cidx 267's profile

The region (144 pos 190–220 ↔ 267 pos 787–817, offset
+597) read act by act: **AGREE 27, DIFFER 4**. The
agreeing positions are exactly the three shared runs of
AES-NUM-121 — 5 at 190–194, 7 at 197–203, 15 at 206–220
— with NO agreeing position outside them inside the
region; both flanks also disagree (144@189 vs 267@786;
144@221 vs 267@818). Every agreeing act has corpus
occurrence count 271 — the region's shared material is
the corpus-common skeleton itself.

The four differing positions, in full (144 act vs 267
act): 195: (1198581248, 248, 0) occ 27 vs (900761600,
248, 0) occ 4; 196: (1198581760, 176, 0) occ 54 vs
(900761848, 176, 0) occ 4; 204: (1198582272, 256, 0)
occ 27 vs (900762112, 256, 0) occ 4; 205: (1198582528,
176, 0) occ 27 vs (900762624, 176, 0) occ 6. At all
four, components 2 and 3 are IDENTICAL on both sides
(248/0, 176/0, 256/0, 176/0) and only component 1
differs. The differing positions form two adjacent
pairs (195–196, 204–205), each pair sitting immediately
before a shared run (197–203, 206–220). What the
component-1 values on either side are, beyond their
counts: NOT PROVEN.

Cidx 267's own occurrence profile (842 acts, all
distinct): occurrence-count distribution {1: 709,
2: 83, 4: 6, 6: 1, 15: 4, 39: 3, 47: 3, 271: 30,
1,058: 1, 1,060: 2} — 709 corpus-unique (84.2%), 83 at
count 2, ZERO at count 3, 50 at count ≥4; max 1,060;
mean 14.8824. Cidx 144 on the same terms (245 acts):
{1: 170, 2: 18, 3: 4, 7: 3, 25: 4, 26: 3, 27: 5, 28: 1,
29: 1, 44: 1, 54: 2, 271: 30, 1,058: 1, 1,060: 2} — 170
corpus-unique (69.4%), 53 at count ≥4; max 1,060; mean
49.2612. The two profiles share their high band EXACTLY
(30 acts at 271, 1 at 1,058, 2 at 1,060 in both); they
differ in the low band, where 267 is far lonelier, and
in the mid band, where 144 carries a spread (7–54) that
267 almost lacks (15/39/47 only).

267's 133 non-unique acts account for 11,689 other
occurrences across 1,059 distinct other contexts,
split by artifact {cc9b9d1c: 9,324, 76c3a8ff: 1,058,
0856a10c: 767, 0a0d378c: 540} — its own artifact
dominates; the single largest other context is
cc9b9d1c cidx 130 with 111 of the 133 acts. Of the 133,
exactly 36 also occur in cidx 144 (the AES-NUM-121
shared-36 control). By number of OTHER contexts an act
occurs in: {1: 83, 3: 6, 5: 1, 14: 4, 38: 3, 46: 3,
270: 30, 1,057: 1, 1,059: 2} — the 83 count-2 acts each
live in exactly one other context, and the 30 count-271
acts each live in 270 other contexts. Mechanism NOT
PROVEN.

## Next

Slice 4.123 — (i) centre 139 read in full: its 79 cells
(77 singletons and the two cells carrying it 28 times
each), its 2 unanimous ≥8 cells, its single
non-divergent triple, and whether its mirror-artifact
cidx tuples are identical; and the anchors 7/11/95 read
as sequence members on this slice's terms (position,
step, neighbours inside their mid/thick hosts — do
constant-like anchors sit at ends where varying centres
never do?); (ii) lane 1 split the other way: group
(20, 32720)'s 216 pairs read per offset block (offs
6796–7272, step 68 — is each 27-pair cell block a
translate of the others?), group (14, 9992)'s five
repeated pairs tabulated in full (their 2 diffs and
single shared XOR), and byte 3's difference retried as
a function of (A byte 3, group) and of A's low bytes
jointly; (iii) the region's two 2-act breaks read
against the corpus (where else the four 267-side break
acts occur; whether the 144-side break pairs occur as
pairs anywhere else) and cidx 130 — the context holding
111 of cidx 267's 133 non-unique acts — read against
cidx 267 in full (length, overlap, shared runs).
Host/artifact analysis only — no physical child.
