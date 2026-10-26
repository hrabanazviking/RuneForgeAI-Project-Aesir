# AES-NUM-105 — the second common-arm DENSE zero is also a common offset (MiniLM 9272, its group's ONLY common offset, a raw singleton), the 4.104 disjointness is itself surprising (0 of 2,000 seeded random 5-splits reproduce it), and the labels share no stated relation with ngidx / ng arithmetic (ng is constant across all 25 camp segments)

Slice 4.105, worked under `docs/TASK_CONTRACT_4.105.md`
(contract committed first @ f2dec2c2, start @ 7c1d049c).
Host/artifact analysis only, on Mimir (purpleviking1) —
no physical child, no device run of any kind.

## Run and transfer record

The prior firing published the contract and the start
commit and stopped before building any script (the
4.100/4.103/4.104 stall pattern). This firing resumed:
hef105.py built locally as the hef104.py lineage plus
hef105_arms.py (script sha256 9df6393c…, gz sha256
054919ca…), landed on Mimir by the proxy-upload
receiver (saved:32569; gz and script sha256 verified
on-device; py_compile OK), detached run over the
7-artifact corpus.

The first run crashed in arm (iii) at the PAIR print
(a `%`-precedence bug: the format tuple was appended
to the already-formatted string). Arms (i) and (ii)
had completed. The single line was patched
(hef105_arms.py sha256 f7c342a7…; patched script
sha256 3ce411f7…, gz sha256 2f6cc8f3…; re-upload
saved:32568, both hashes verified on-device,
py_compile OK) and the script was rerun in full:
DONE105 at line 3,576, output sha256 893794f7…,
retrieved byte-complete (gz sha256 bfd58c8a… matched
both sides). The on-device diff between the two runs
is exactly the first run's traceback, replaced by arm
(iii)'s output from the PAIR lines onward; arms (i)
and (ii) are identical across both runs, and the
corrected run is the one credited below.

## Controls

All controls reproduce exactly: 128,787 small actions;
79,001 bursts; 745,849 pointer actions; 1,504
contexts; 2,049 trailing pairs; 75,215 champion
bursts; whole-arm candidates 7,690, boundary 0;
non-common candidates 7,484 with form × zero splits
SPARSE 2,280/144, MID 2,306/21, DENSE 2,898/64; the
common-arm census reproduces AES-NUM-104 exactly
(206 records, forms DENSE 95 / SPARSE 65 / MID 46,
value-0 by form DENSE 2 / SPARSE 8 / MID 0, exactly 2
common-arm DENSE zeros) — AES-NUM-029/032…104
headline counts all reproduced (no arm below is
credited on a failed control, and none failed).

## (i) The second common-arm DENSE zero: MiniLM p 9272

**The exclusion pattern repeats exactly.** For the
group (MiniLM, 23, 32768) the common offsets are
exactly [9272] — 9272 is the group's ONLY common
offset, and it IS a common offset, so this word's
absence from the whole (non-common) population
follows from that population's definition alone,
exactly as at 17344. The group's instances, in group
order: (cidx 3, ng 0, ngidx 4), (cidx 5, ng 0,
ngidx 6) — only two instances, both in ng 0. The
ALLOTH object whose target offset is 9272 itself
exists; its per-ng form is {0: OTHER} — there is NO
per-ng prediction for this offset (pred None on both
records), unlike 17344 whose per-ng forms were CONST
in both ngs. The common-arm records at 9272,
verbatim:

- cidx 3 (ng 0, ngidx 4): value 127, z 1, form
  DENSE, mask 00001, prediction None, neighbourhood
  (ff7f0000, ffffff7f, ff7f0000, d30b0000, 00000000)
  — dense-zero False.
- cidx 5 (ng 0, ngidx 6): value 0, z 1, form
  DENSE, mask 01000, prediction None, neighbourhood
  (62470000, 00000000, ff000000, 02000000, 01000000)
  — **a DENSE zero in the common-arm sense: True**,
  and its mask is exactly the 01000 recorded by
  AES-NUM-104.

Raw anatomy: in cidx 5 the word at 9272 is exactly
ff000000 and its maximal raw run is 9272..9272 —
length 1, a raw singleton; its sole position
classifies as (dense-zero candidate False,
whole-population candidate False, common offset
True). In cidx 3 the word at 9272 is ff7f0000 — not
an ff word at all, no raw run. Against the 17344
case: both words are common offsets of their groups
and common-arm DENSE zeros in exactly one instance;
they differ in that 17344 sat inside a raw run of 4
(and its group had a second common offset, 13664,
and seven instances across two ngs with CONST per-ng
forms), while 9272 is a lone raw word, its group's
sole common offset, in a two-instance single-ng
group whose per-ng form at the offset is OTHER. No
mechanism beyond the population definition is
needed or credited for either exclusion.

## (ii) Disjointness control for the 4.104(ii) fact

AES-NUM-104 measured the 5 singleton DENSE zeros'
neighbourhood value sets as DISJOINT from the 59
run members' at all four relative positions
(-8, -4, +4, +8). This arm asks whether disjointness
at n=5 is itself surprising, on the same 64 DENSE
zeros with neighbourhoods re-derived identically
(the observed split reproduces first: intersections
[0, 0, 0, 0], all-disjoint True).

Deterministic control splits (5 vs the other 59,
per-position intersections in -8/-4/+4/+8 order):
first-5 sorted [2, 2, 2, 2]; last-5 sorted
[2, 1, 2, 2]; stride-13 [3, 1, 2, 2]; smallest-q 5
[2, 1, 2, 2]; largest-q 5 [3, 1, 3, 3]; group-pure
first 5 of (0a0d378c, 13, 32600) [2, 2, 2, 2];
offset-mod-16 sorted first 5 [3, 4, 1, 2]. NONE is
disjoint at even one position.

Random control: 2,000 seeded (20261025) random
5-subsets of the 64, each against its 59-complement:
all-four-positions disjoint in **0 of 2,000**
(0.0000); disjoint at >=1 position in only 1 of
2,000 (a single +8 case); per-position disjoint
counts [0, 0, 0, 1]; mean intersections per position
[2.619, 1.601, 1.853, 2.4715].

Verdict: the observed disjointness is NOT a small-n
artefact — no tested alternative 5-split and no
seeded random 5-split reproduces disjointness at
even one position, let alone all four. The
singleton/member neighbourhood separation is a real
measured feature of these two populations. This
does not retroactively create an exact separation
law: AES-NUM-104's exact-separation hunt still
found no word or mask present in all of one
population and none of the other, so a
distinguishing LAW remains NOT PROVEN; what this
arm grades is that the disjointness itself is
surprising against every stated control.

## (iii) Label values vs ngidx / ng arithmetic

The 25 camp segments and labels are exactly as in
AES-NUM-103/104 (camp A 13, camp B 12, every segment
carrying exactly one distinct family-1 and one
distinct family-2 head word; bad segments: none).
The AES-NUM-100 degeneracy ruling applies
throughout.

**ng is constant.** Every one of the 25 camp
segments lies in ng 1 of 76c3a8ff (ngs all 1 in
scopes A, B and pooled; distinct-ng 1, injective
False in every scope). As a determiner ng therefore
carries no variation at all: its as-function tests
are False (mixed) for every non-constant label byte,
and True only on constant target bytes (9 True, all
degenerate); its affine hits occur only on constant
target bytes and are excluded as degenerate.

**ngidx is injective everywhere** (camp A ngidxs
[38, 47, 56, 65, 110, 119, 128, 146, 155, 164, 173,
227, 236]; camp B [29, 74, 83, 92, 101, 137, 182,
191, 200, 209, 218, 245]; pooled 25 distinct). Every
ngidx as-function hit (24 of 24 byte/word tests per
the script's count across scopes) is therefore
degenerate under the ruling. Affine hunts for
ngidx: a!=0 hits ZERO on all 24 scope/byte
combinations; XOR-constant None everywhere;
difference and XOR distinct counts are at or near
the scope size (pooled label bytes 23–25 distinct).
Non-degenerate affine hits total: **0**.

Verdict: the labels share no stated relation with
ngidx / ng arithmetic — with cidx, segidx and
pooled rank (AES-NUM-104) and the label pair itself
(AES-NUM-103) already closed, every stated metadata
determiner is now exhausted. What the labels encode
remains NOT PROVEN.

## Next

Slice 4.106 — the singleton neighbourhood value sets
themselves (the disjoint singleton-only values at
each relative position: their identity across the 5
singletons' groups/offsets, and whether they recur
anywhere else in the corpus populations); the cidx-3
counterpart at 9272 (value 127, mask 00001 — its
neighbourhood vs the cidx-5 DENSE zero's, word by
word); label values vs the segments' own block
positional structure (the last untested in-segment
determiner class). Host/artifact analysis only —
no physical child.
