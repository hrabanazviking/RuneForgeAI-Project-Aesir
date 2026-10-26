# The mirror pair's divergent triples anatomised, the 37 broken-unanimity cells and 96 word-different cells resolved to instances and lanes, and the three unshifted exceptions settled as far as head material decides: the 2,171 membership-divergent triples are mostly both-sides-different (1,997) with about seven extra instances per triple, and inserted centres CONTINUE the shared centre sequence wherever that sequence is thick (11,795 continuations vs 373 breaks against unanimous common sequences; common instances agree on centre 15,488/15,488); the 37 A-unanimous-but-not-B cells are three exact families and all 535 breakers are shared instances differing in lane 0 or lane 3 only, never the centre lane; the 96 centre-equal word-different cells carry 1,971 differing instances with the centre lane differing in 0; the train 48 ranks 1–2 pair shares NO head material at all — two independent head anomalies, not one shared anomaly — and train 50 rank 26's head is exactly one act shorter in count but is not any steady head minus an act, so the −1 mechanism stays NOT PROVEN (AES-NUM-117)

Slice 4.117, worked under `docs/TASK_CONTRACT_4.117.md`
(contract committed first @ 7a0b5fcb). Host/artifact analysis
only, on Mimir (purpleviking1) — no physical child, no
device run of any kind.

## Run and transfer record

hef117.py was built locally as the hef116.py base
extraction (everything before the 4.116 arms marker) plus
new arms in hef117_arms.py (sha256
`5004f6fee76372072b7528e78a72a600d1905fe9ed18ac6774959f56b87a25a9`),
giving hef117.py sha256
`7c82532cb7a18a3d619c78e726faea8635484f53c2b3285ed56d288d8d35718b`.
Transfer followed the proven one-shot receiver pattern: a
397 B receiver (recv117.py, sha256
`1a5e48ff50b871d86d22ce95dcdead1c3602ddd3fe4ec4736587a24b3cda644f`)
landed by sha-verified file.write; a child subagent held
it in the foreground on the device; the VM POSTed the
62,413 B gzip through the tunnel proxy (`saved:62413`).
On-device sha256 of the gzip
(`57153163454eafef13d54f01a83fb87aaad5b33dbc471e97b3782c0404e09047`)
and of the decompressed script matched the local values
exactly; py_compile OK on-device. A first launch attempt
was killed when its invoke hit the node timeout (partial
output discarded); the run was relaunched detached
(`setsid nohup … < /dev/null &`) and completed to
DONE117. The output (11,162 lines, 1,519,941 B, sha256
`38fa606c139672fe0d343c3817b020aa4b04e1fc7d2af971eb7b54fd0cc1b614`)
was retrieved gzipped with sha256
`35652dd6b150266892ce66f16ed7ec3f01ddeb00bdd16eab6550de83ed0fd85d`
verified identical on both sides.

## Controls

All inherited controls reproduce exactly. The inherited
DONE105 / DONE106 / DONE107 / DONE108 markers sit at the
same output lines as the 4.116 run (3,576 / 3,670 / 3,701
/ 3,910). Shared enumeration: groups ≥2 54,995; groups ≥1
common 1,323; cells 55,902; observations 527,236;
distinct ladder 11,242; unanimous 39,673; AP cells 2,584
with step histogram {0: 352, 2: 26, 3: 489, 4: 741, 6:
164, 8: 350, 9: 217, 12: 200, 24: 34, 40: 11}; non-AP
4,148 (ordered 317 / multi 298 / set 174); ≥8 cells
25,566, unanimous 18,286, 29 centres, centre-1 561; the
target cell (773470cd pos 9 size 32784 off 11608) appears
in ≥8 unanimous exactly once with centre word ff010000.

## (i) The 2,171 membership-divergent triples

Cells: A 6,970, B 7,485, shared (cidx-keyed) 2,981;
triples in both 5,152 by the dict method of 4.116 and by
an independent multimap method (triples with more than
one cell on a side: 0 — every divergent pair is a
one-to-one cell pair); triples with different cidx
tuples: 2,171.

**Which side carries extras.** Over the 2,171 divergent
triples: both-sides-differ 1,997; A-only-extra 92;
B-only-extra 82. The one-extra-B anatomy of the example
triple printed in AES-NUM-116 is therefore NOT the
general case: divergence is overwhelmingly two-sided.
Net length difference (lenB − lenA): {−18: 17, −3: 99,
−1: 393, 0: 613, +1: 730, +2: 84, +3: 74, +4: 72, +5: 22,
+6: 67} — centred near zero with a +1 mode. Gross extras
per triple: {1: 157, 2: 207, 3: 43, 4: 56, 5: 66, 6: 139,
7: 461, 8: 193, 9: 479, 10: 174, 11: 112, 12: 67, 18: 17}
— mode 9, total extras 15,252 (A-side 7,164, B-side
8,088). The common instances across the divergent
triples number 15,488 and their centres agree A-vs-B on
15,488/15,488 (1.0000): the mirror property of AES-NUM-116
extends to the common instances inside divergent triples.

**Insertion position.** Extras by own-list position:
first 2,906, interior 10,367, last 1,979; by merged
(common + extra) order: first 1,905, interior 12,284,
last 1,063. 5,274 extras have no common predecessor,
4,094 no common successor, 865 have neither (triples with
no common instance at all). Flanked extras' common-
neighbour cidx spans peak at 6 (1,931 extras; gaps 3+3)
and 8 (1,179; gaps 4+4), then 42 (935) and 56 (788); the
common lists' own consecutive cidx gaps peak at 3
(5,535), 4 (3,311), 6 (1,986), 8 (1,179).

**Continuation.** Each extra was graded against the
triple's common centre sequence in cidx order (rules in
the contract; AP includes two-instance sequences whose
step is their difference; NONAP judged by the flanking
interval plus the common sequence's own difference set).
Verdicts: CONTINUES 12,411 (A 5,647, B 6,764); BREAKS
476 (A 205, B 271); INDETERMINATE 2,365 (A 1,312, B
1,053). By structure of the common sequence:

- UNANIMOUS common sequence — 12,168 extras: CONT 11,795,
  BREAK 373. Where the shared sequence is a constant
  centre, the inserted centre equals it 96.9% of the time.
- NONAP common sequence — 2,099 extras: CONT 599, INDET
  1,500, BREAK 0. No NONAP extra ever falls outside its
  flanking common interval.
- AP common sequence — 120 extras only: CONT 17, BREAK
  103, with steps {6: 108, 3: 8, 38: 4}. A thin family,
  recorded with its small n; its breaks dominate its
  grade and are a named 4.118 follow-up.
- No common instance (SINGLE) — 865 extras, all INDET by
  construction.

Triple-level grades: all-CONT 1,679; any-BREAK 72; INDET
420.

**Caveat (recorded, not hidden).** The UNANIMOUS class
includes triples whose common sequence has length 1 — a
single shared instance, trivially "unanimous". The BREAK
examples printed in the run output are exactly such
thin-common triples (e.g. triple (11, 26144, *) whose one
common instance carries centre 122 while A-side extras
carry 93 and B-side extras 90; triple (15, 26064, *) with
one common centre 32 and extras carrying centres 20–53
on both sides). The continuation headline is therefore
stated for what it is — strong where the common sequence
is thick, weakest exactly where the common sequence is a
single instance — and a thickness-graded re-run is the
first arm of slice 4.118.

**Per-group summary.** 56 (pos, segsize) groups carry all
2,171 divergent triples. The largest: (11, 26144) 91
triples, extras A 91 / B 91, CONT 162 / BREAK 20; (10,
21808) 80 triples, extras A 0 / B 80 — the pure B-only
family the 4.116 example came from — CONT 80 / BREAK 0;
(9, 32344) 79 triples, extras 395/316, CONT 621; (21,
32632) 75 triples, A-only extras 75, CONT 75; (14, 32672)
72 triples, extras 216/504, CONT 620; (71, 21416) 71,
(24, 32392) 70, (15, 29984) 68, (9, 32712) 68, (71,
19392) 67 with BREAK 99. BREAK extras concentrate in
four groups: (25, 29528) 121, (71, 19392) 99, (15, 26064)
99, (25, 31160) 81. The full 56-group table is in the run
output.

**Grade.** Counts, positions and verdicts: measured, on
complete populations, under the contract's stated rules.
Why the two artifacts' membership differs at these
triples: NOT PROVEN — no cause is inferred anywhere in
this slice.

## (ii) The 37 broken-unanimity cells and the 96 word-different cells

Shared-cell controls reproduce: centres equal 2,981/2,981;
full neighbourhood words equal 2,885/2,981;
A-unanimous-but-not-B 37; B-unanimous-but-not-A 0.

**The 37 fall into three exact families.**

1. Thirteen cells of size 2 (pos 19, size 7712, A-centre
   15): exactly 1 breaker against A's word, at index 0,
   in every cell.
2. Nine cells of size 27 (pos 12, size 32728, A-centre
   127): exactly 13 breakers against A's word, at the
   SAME index set [2, 4, 8, 9, 10, 11, 12, 13, 14, 17,
   18, 24, 25] in all nine cells. B carries exactly 2
   distinct words in these cells (14 vs 13), so the
   breakers are B's own minority.
3. Fifteen cells of size 28 (one at pos 13 size 32760,
   fourteen at pos 14 size 9992, A-centre 15): 27 breakers
   against A's word — every instance except index 0 —
   but only index 0 differs from B's modal word. In these
   cells B's word simply differs from A's word at 27 of
   28 instances; the first instance alone keeps A's word.

Total breakers: 535 (13×1 + 9×13 + 15×27); 117 of them
are also minority against B's modal word (all from family
2). Every breaker's own centre equals the A-unanimous
centre: 535/535 — unanimity breaks in the flanks, never
at the centre. Breaker lanes against A's word: lane 0
only in 431 breakers, lane 3 only in 104 — never the
centre lane (lane 2), never lanes 1 or 4. Byte-difference
magnitude against A's word: 1 byte in 470, 2 bytes in
13, 3 bytes in 52. Breaker positions: interior 507,
first 13, last 15. Membership: 0 of 535 breakers are
extra instances — shared cells carry identical cidx
tuples by construction, so the broken unanimity is
entirely a matter of word values at shared instances.
The A centres of the 37 are 15 (28 cells) and 127 (9
cells), matching the AES-NUM-116 L1 bookkeeping exactly.

**The 96 centre-equal word-different cells.** 1,971
instances differ between the two artifacts' words.
Differing instances per cell: {27: 60, 1: 16, 13: 9, 2:
2, 18: 1, 22: 2, 23: 1, 24: 1, 25: 1, 26: 2, 28: 1} —
sixty cells differ at ALL 27 instances (whole-cell word
differences), sixteen differ at exactly one instance.
Cell classes (A, B): the 96 include the 37 above
(UNANIMOUS × DISTINCT 13, UNANIMOUS × OTHER 24), 2 cells
unanimous on both sides but on different words, and 57
others (DISTINCT × DISTINCT 37, DISTINCT × OTHER 2,
OTHER × DISTINCT 4, OTHER × OTHER 14). Sizes: 27 in 48
cells, 28 in 30, 2 in 18.

Lanes (word position in the 5-word neighbourhood; lane 2
is the centre word): the centre lane differs in 0 of
1,971 differing instances — and the centre byte itself in
0 — which is exactly the centre equality of AES-NUM-116
seen at lane resolution. Pooled differing instances per
lane: lane 0: 1,086; lane 4: 738; lane 3: 406; lane 1:
354. Lane sets per differing instance: (0,) 620; (0, 4)
328; (3,) 397; (4,) 263; (1,) 216; (0, 1, 4) 138; (3, 4)
9. Differing bytes per differing instance: {1: 709, 2:
661, 3: 261, 4: 268, 5: 29, 6: 43}. Positions of
differing instances: interior 1,843, first 57, last 71 —
no positional concentration beyond cell size. The
differing B word occurs elsewhere in the corpus
neighbourhood pool (more than one occurrence) for 766 of
1,971 differing instances; the differing A word likewise
for 791 — so a substantial minority of the differing
words are words the corpus uses elsewhere, and the rest
are singletons in the pool; which artifact's word, if
either, matches a third artifact's word at the same
group is NOT tested here and is a 4.118 follow-up.

**Grade.** Families, breakers, lanes, bytes and
positions: measured on the complete shared-cell
population. Any reason for the word differences: NOT
PROVEN, none inferred.

## (iii) The three unshifted exceptions

The cc9b9d1c fit reproduces exactly: union 929 contexts;
the (0, 304) target group holds 813 contexts at origin
offset 0; contexts 271; start distribution {4: 1, 5: 47,
6: 31, 7: 83, 8: 56, 9: 44, 10: 9}; 217 in-train rows;
trains 44–51 carry the same forms as AES-NUM-116 and the
same 10 exceptions with the same identities.

**Train 48 ranks 1–2 (idx 1 cidx 140, idx 2 cidx 144;
both 7→8).** The pair's head comparison, exactly:

- Head lengths 8 and 8. Head common prefix: 0 acts.
  Head common suffix: 0 acts. Equal head positions: none.
- First acts differ ((1036991488, 24, 2) vs (961269248,
  24, 2)); opening pairs differ; prev_acts differ
  ((93162496, 24, 1) vs (1225501720, 24, 0)); the triple
  blocks are identical, as for all ten exceptions.
- Against the 24 steady members (steady modal head acts
  held by 23/24 at each position): at every comparable
  head position 0–6, BOTH ranks differ from the steady
  modal act AND from each other. (Position 7 is not
  comparable: for the pair it is the prev_act; for steady
  members, whose start is 7, index 7 is already the
  triple's first act.) Positions where the pair agree
  with each other on a shared NON-modal act: none — the
  shared-anomaly test returns an empty set.
- Each rank's first act is shared with 0 other train
  members; its opening pair with 0; its prev_act with 0.
- Train-49-form tests fail for both ranks: prev_act is
  not the train's modal prev_act (1255554048, 24, 0), and
  the opening pair's second act is not the train's modal
  first act (60413952, 24, 1).
- Head-insertion alignment against every train member
  (the pair member's head equalling some member's head
  with exactly one act inserted) is empty for both ranks,
  as is pre-triple window equality; the pair-vs-pair
  insertion alignment fails in both directions.

Verdict: the pair shares NO head material whatsoever —
only the identical triple block, the +1 start and train
membership. ONE shared anomaly is therefore NOT PROVEN
(head-material sharing measured at zero); the evidence
fits two independent head anomalies, and any shift for
either rank remains NOT PROVEN, exactly as AES-NUM-116
left it. No shift is invented.

**Train 50 rank 26 (idx 26 cidx 247; 7→6, the −1
exception, last rank of its train).**

- Head length: start 6, against steady 7 and against its
  cidx neighbour rank 25's 7 — the head is exactly one
  act shorter IN COUNT (measured). Train 50's starts in
  rank order are [5, 7, 7, 7, 7, 7, 7, 7, 7, 7, 8, 7, 7,
  7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 6]: the leading
  5 belongs to rank 0, a head context of the train's head
  run; among the priced ranks, only rank 10 (8, explained
  in AES-NUM-116) and rank 26 (6) deviate from 7.
- BUT the deletion alignment is EMPTY: rank 26's 6-act
  head [(1513926144, 24, 1), (1170699776, 24, 2),
  (1244661248, 24, 2), (1052256256, 24, 2), (1052256768,
  24, 0), (900765184, 24, 1)] equals NO steady member's
  head with exactly one act removed. (This test is
  exactly the mirror of the insertion test that explained
  seven of the ten exceptions in AES-NUM-116.)
- Head vs rank 25's head: common prefix 0 acts, common
  suffix 0 acts, equal positions none; post-triple common
  prefix vs rank 25: 0 acts. First act (1513926144, 24, 1)
  is not the train modal first act (1244660736, 24, 1)
  and is shared with 0 members; prev_act (900765184, 24,
  1) is not the steady modal prev_act (30589440, 24, 0)
  and is shared with 0 members — consistent with
  AES-NUM-116's note that this prev_act is unique in the
  train.
- Last-rank peers: the last rank of every other cc9 train
  sits exactly at its train's steady value (train 44: 8,
  45: 9, 46: 6, 47: 7, 48: 7, 49: 9, 51: 5). Rank 26 of
  train 50 is the ONLY deviating last rank.

Verdict: the head IS one act shorter — that much is an
honest count, and it is consistent with the −1 start. It
does NOT explain the −1 in the deletion sense: the head
is not a steady head with one act deleted, it shares no
prefix, suffix or position with its neighbour's head,
and its first and prev acts are unique in the train.
The mechanism of the −1 remains NOT PROVEN; no shift is
invented.

## Grades

- Arm (i) counts, side categories, positions, gaps and
  continuation verdicts: measured on the complete
  divergent-triple population under the contract's rules,
  with the thin-common caveat stated in-line. The cause
  of membership divergence: NOT PROVEN.
- Arm (ii) families, breakers, lanes, bytes, positions
  and the zero centre-lane difference count: measured on
  the complete shared-cell population. The cause of the
  word differences: NOT PROVEN.
- Arm (iii): the pair's non-sharing and rank 26's
  non-deletion are measured exactly; one shared anomaly
  for the pair NOT PROVEN (sharing measured at zero); the
  −1 mechanism for rank 26 NOT PROVEN; any shift for any
  of the three: NOT PROVEN, none invented.

## Next (slice 4.118)

Derived from these findings, in arm order: (i)
thickness-graded continuation verdicts — re-grade the
2,171 divergent triples stratified by common-sequence
length, anatomise the AP-common extras (103 breaks in
120) and the 72 any-BREAK triples in full; (ii) identify
the 37/96 differing words across artifacts — whether B's
differing word is another artifact's word at the same
group, whether the 28-instance first-instance pattern
appears in other artifact pairs, and whether the 60
whole-cell differing cells coincide with the 37's groups;
(iii) search the three unshifted heads' unique acts
corpus-wide in cc9b9d1c — whether those acts head any
other context in the corpus. Broad ordinary UNMODIFIED
source-model support 100% remains the destination.
