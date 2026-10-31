# The fifteen repeating doubly-wed families carry arithmetic index sets: eight are pure step-8 progressions whose residues are exactly 0–7, one each (derived from the printed table), the step-4 families miss individual lattice slots — three of one family's four missing slots are exactly the whole index set of its sister family (derived) — the family residue is a CERTIFIED function of the doubly-wed key (86 distinct, 15 repeating, 0 violating; constant within a family by the step's own construction, the empirical content being the step/residue table itself), the quotient is NOT a function (all 15 repeating families violate), wedging the residue further repairs nothing (86 distinct, position-1 failing on 2 keys, position-2 and the whole tuple on the same 3) and wedging the quotient is vacuous (271 distinct, 0 repeating). The acts occupying the skipped A-positions inside the secondary long runs are ALL A-only: 8 non-unit gaps, 19 skipped positions, and every one of the 19 acts occurs in context A exactly once and does not occur in context B at all (19 of 19). And B byte 0 against the four three-byte sub-keys wed to the pair's status over the full 224 pairs: (byte 0, byte 1, byte 2) and (byte 0, byte 2, byte 3) are injective (224 distinct wed values, 0 repeating), (byte 0, byte 1, byte 3) has exactly one repeating value and it AGREES — ('SAME', (20, 1, 128)) -> 20, the status wed not splitting the unwed agreeing repeat because both of its pairs are SAME — while (byte 1, byte 2, byte 3) repeats the same two values as every earlier wed and violates both times, both under SAME; the unwed agreeing repeat's two pairs re-read record by record share no record at all (1 record against 27) — mechanisms NOT PROVEN (AES-NUM-141)

Slice 4.141, worked under `docs/TASK_CONTRACT_4.141.md`
(contract published in the 4.140 closing commit @
0faaddac). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child, no device run of
any kind. All findings below are taken from the
sha-verified raw output; the few derived counts marked
as such were computed at closing from the run's own
printed tables, never sampled.

## Run and closing record

hef141.py (the hef140 file verbatim as base — itself
the hef139/hef138/hef137/hef136/hef135/hef134/
hef133/hef132/hef131/hef130 lineage — plus the new
arms141) sha256
`e346f344f8703daca8c0a1c0aca1c21d24a3239e1a53447efb055e37300be6e3`
(573,634 B); arms141 sha256
`ba596dbe9226827aaf0572228b7a4e102c067504e66c95c4a8ea028fa897010c`
(10,469 B), its gzip sha256
`ab9742dfcb217e7acaf453d0ddf4a3d951fda1d6a158a7f0451da49d82776586`
(3,292 B). The arms were built locally by the
10-minute continuity worker. The crossing was hard
and is recorded in full: two whole-file chunked
file.write sessions (373 B parts, then 300 B parts)
each failed the whole-file sha256 gate on-device and
were discarded uncommitted by the gate; one
proxy-receiver hold expired with no POST and saved
nothing; the arms finally crossed as individually
sha-gated part files (250 B parts, every part's own
sha256 verified on-device — 13 parts for the first
arms version, 14 for the fixed version), were
assembled on-device, and the assembled hef141.py
sha256 matched the VM's exactly before each launch.
The FIRST bounded host-side child then exited 1 in
arm (i): the step table had been measured only for
the 15 repeating families and a singleton family's
row raised KeyError — a host-script defect, found in
the run's own error channel, not a data result. The
arms were fixed (the step is now measured for all
86 families; a singleton family has an empty
difference set and its step is recorded as 1, its
residue as 0), re-crossed as above, and the second
bounded child — launched in a detached tmux session
on-device with the contract corpus argv (the six
hailo-ollama blobs in glob order, then MiniLM — the
launch law recorded in the contract) — finished
on-device (DONE141 is the output's last line; the
run's exit marker is 0; the error channel carried
nothing). The output is 33,787 lines / 6,446,065 B,
sha256
`94e9bd8374fc156624e911d0a3a1c399f7ed3ae1685d6814cf78446492c75cca`;
the first 33,087 lines are byte-identical to
hef140.out (verified with cmp on-device), the base
having reproduced line-for-line. The 4.141 section
begins at output line 33,088 and is alone 700 lines
/ 163,881 B, sha256
`b53eebc18bbb044ab8866231ae87d0a1dee56170b2606e3222455e99f2175955`
(section gz sha256
`85a4fc1a7a915033fecfccaa976194e7ef549829afd5c18536ec3f4530303f37`).
Raw output and scripts are kept on the Pi at
~/aesir-build/hef141.out, hef141.py, arms141.py and
section141.txt.

## Controls

Inherited controls reproduce EXACTLY: cells 55,902 /
obs 527,236; divergent triples 2,171, verdicts CONT
12,411 / BREAK 476 / INDET 2,365; lane-1 pairs 224;
(byte 3, byte 1, byte 2) keys 222; (byte 3, sum) keys
222; shared single-positioned acts 689; secondary
runs 103, of length ≥ 20 exactly 7; secondary
internal gaps 431; gap between-tuple counts 34 / 30
/ 87 for gaps 0 / 1 / 2.

## (i) The cidx sets inside the 15 repeating doubly-wed families

The doubly-wed key is the maximal compound joint key
wed to BOTH companions (context length and gap-2
left position), as established in AES-NUM-138 (86
distinct over the 271 contexts). Its 15 repeating
families carry 200 of the 271 rows, every one of
them in artifact 'cc9b9d1c'. For each family the
run printed its full sorted cidx set, its
consecutive differences, the measured step (the gcd
of those differences), the residue set (cidx mod
step) and the quotient list (cidx // step):

- Step 8, pure progressions (no missing term,
  quotients consecutive): [13, 21, …, 109] residue
  5 (13 rows); [14, 22, …, 102] residue 6 (12);
  [16, 24, …, 104] residue 0 (12); [17, 25, …, 105]
  residue 1 (12); [18, 26, …, 106] residue 2 (12);
  [11, 19, …, 107] residue 3 (13); [15, 23, …, 103]
  residue 7 (12); [12, 20, …, 108] residue 4 (13).
  Derived from the printed table: the eight step-8
  families carry the residues 0, 1, 2, 3, 4, 5, 6, 7
  exactly once each.
- Step 4: [147, 151, …, 243] residue 3, 25 rows,
  differences all 4 — a pure progression with
  quotients 36–60 consecutive. [145, 149, …, 245]
  residue 1, 25 rows, one difference of 8: quotient
  45 missing, the slot cidx 181 unoccupied by the
  family. [146, 150, …, 246] residue 2, 22 rows,
  differences 4 with 8 / 12 / 8: quotients 39, 44,
  45, 60 missing, the slots cidx 158, 178, 182, 242
  unoccupied by the family. [140, 148, …, 240]
  residue 0, 22 rows: quotients 36, 40, 45, 46
  missing, the slots cidx 144, 160, 180, 184
  unoccupied by the family. Derived from the
  printed tables: three of the [146…] family's four
  missing slots — 158, 178, 242 — are exactly the
  whole cidx set of the [158, 178, 242] family
  below, its sister at the same gap tuples and the
  same length / left position (738 / 713) under
  different distances (7, 1) against (3, 1); and
  the [140…] family's missing slot 160 is an index
  of the [160, 244] family below.
- Two-row families: [158, 178, 242] is three rows —
  step 4 by gcd (differences 20, 64), residue 2,
  quotients [39, 44, 60] (the family named above);
  [160, 244] step 84 (its single difference),
  residue 76, quotients [1, 2]; [119, 250] step
  131 (its single difference), residue 119,
  quotients [0, 1].

Function tests over the 271 contexts:

- The cidx residue as a function of the doubly-wed
  key: CERTIFIED — 86 distinct keys, 15 repeating,
  0 violating. Recorded honestly: the residue is
  constant within a family by the step's own
  construction (the gcd of a family's differences
  divides every difference), so the certification
  is guaranteed once the step is measured; the
  empirical content of this arm is the step /
  residue table above, not the certification.
- The cidx quotient as a function of the doubly-wed
  key: NOT a function — 86 distinct, 15 repeating,
  ALL 15 repeating keys violate (each family's
  quotients are exactly its printed list).
- Doubly-wed wed further to the residue adds NO
  distinct key (86 distinct joint keys, 15
  repeating — exactly as the certification
  requires): position-1 is NOT a function (2
  violating keys), position-2 is NOT a function
  (3 violating), and the whole tuple is NOT a
  function (the same 3) — the doubly-wed violating
  families with their one certified residue value
  appended.
- Doubly-wed wed further to the quotient gives 271
  distinct joint keys, 0 repeating, 0 violating
  under all three tests — formally IS A FUNCTION
  on each, but only because the quotient separates
  every row inside its family (derived from the
  printed counts): a vacuous repair of the same
  kind as the cidx wed of AES-NUM-140.

The index inside a maximal family is therefore an
arithmetic coordinate — a residue the key already
fixes and a quotient that individuates the row —
and what fills the families' missing lattice slots
is NOT PROVEN.

## (ii) The acts occupying the skipped A-positions inside the secondary long runs

The exception pair (as in AES-NUM-137..140) is
context A = artifact 5ab3537d cidx 86, length 749,
and context B = artifact 5ab3537d cidx 210, length
751, with 689 shared distinct acts, every shared
act single-positioned in both contexts. Of the 431
internal gaps of the 7 secondary long runs, exactly
8 are non-unit (AES-NUM-140), covering 19 skipped
A-positions. Every skipped position was read in
full — the act there, its occurrences in A and in
B's context, and its classification:

- Run 62 step 5 (A 443 → 446): A 444 =
  (785868800, 1552, 1); A 445 = (785870352, 14864,
  1).
- Run 62 step 11 (A 451 → 457): A 452 =
  (786063872, 26128, 2); A 453 = (786090000, 32784,
  2); A 454 = (786122784, 26128, 2); A 455 =
  (786148912, 32784, 2); A 456 = (786181696, 18448,
  2).
- Run 74 step 24 (A 548 → 550): A 549 =
  (788357120, 32784, 2).
- Run 74 step 31 (A 556 → 561): A 557 =
  (788585984, 32784, 0); A 558 = (788618768, 26128,
  0); A 559 = (788644896, 32784, 0); A 560 =
  (788677680, 26128, 0).
- Run 74 step 33 (A 562 → 564): A 563 =
  (788721152, 32784, 0).
- Run 74 step 37 (A 567 → 569): A 568 =
  (788830208, 32784, 0).
- Run 74 step 48 (A 579 → 581): A 580 =
  (789100544, 26128, 1).
- Run 102 step 49 (A 732 → 737): A 733 =
  (791776792, 24, 0); A 734 = (791777280, 24, 1);
  A 735 = (791777792, 24, 2); A 736 =
  (791778304, 24, 0).

Classification totals, counted exactly by the run:
non-unit gaps 8; skipped A-positions 19; acts
shared with B 0; acts occurring in B's context but
not single-positioned 0; acts NOT in B's context at
all 19. Every one of the 19 acts occurs in A
exactly once (its occurrence list is its own
position). The wider gaps inside the secondary
runs are therefore, on the A side, exactly
insertions of A-only acts between shared acts —
never shared acts standing out of the run's shift.
Derived from the printed left/right positions: in
all 8 gaps the B-side distance between the same two
acts equals the A-side distance, so context B
carries the same number of skipped positions
between them; what occupies those B positions is
the mirror question, NOT measured here.

## (iii) B byte 0 against the four three-byte sub-keys wed to the pair's status

The 224 lane-1 pairs divide by status as SAME 44 /
DIFF 180 (status = whether B byte 0 equals A byte
0). Each three-byte sub-key of the A word was wed
to the pair's status (key = (status, three-byte
value)) and B byte 0 tested over the full 224:

- (byte 0, byte 1, byte 2) wed to status: 224
  distinct wed values, 0 repeating — injective;
  no agreeing or violating repeat, a function
  claim from zero repeats being vacuous and none
  made.
- (byte 0, byte 1, byte 3) wed to status: 223
  distinct wed values, exactly 1 repeating, and it
  AGREES, 0 violating: ('SAME', (20, 1, 128)) ->
  B byte 0 = 20, carried by the pairs A 1401b180 ->
  B 1401b100 (group (19, 7712)) and A 1401b280 ->
  B 1401b200 (group (14, 9992)) — the very repeat
  AES-NUM-140 found unwed. The status wed does not
  split it, because both pairs are SAME (each
  pair's B byte 0 equals its own A byte 0, diff
  0). A determination claim resting on a single
  agreeing repeat is recorded as exactly that —
  no violating repeat exists under this wed, and
  nothing stronger is claimed.
- (byte 0, byte 2, byte 3) wed to status: 224
  distinct wed values, 0 repeating — injective,
  as above.
- (byte 1, byte 2, byte 3) wed to status: 222
  distinct wed values, 2 repeating, 0 agreeing, 2
  VIOLATING — NOT a function. Both repeats sit
  under SAME: ('SAME', (1, 176, 128)) -> B set
  {28, 32} and ('SAME', (1, 178, 128)) -> B set
  {20, 24} — the same two values as under the
  group wed (AES-NUM-139) and unwed (AES-NUM-140),
  all four pairs in group (14, 9992), and in each
  pair B byte 0 again equals its own A byte 0.

The (byte 0, byte 1, byte 3) unwed agreeing
repeat's two pairs were then re-read record by
record, in full:

- A 1401b180 -> B 1401b100, group (19, 7712): ONE
  record — cell (19, 7712, 2384), cidx 86, idx 0,
  n 2, centre 87, poscat 'first', in37 False.
- A 1401b280 -> B 1401b200, group (14, 9992):
  TWENTY-SEVEN records — cell (14, 9992, 4336),
  cidx 101, 105, …, 205 (step 4), idx 1..27, n 28,
  centre 7, 11, …, 111 (step 4), poscat 'interior'
  for records 0–25 and 'last' for record 26, in37
  False throughout.

The two pairs of the campaign's one agreeing
three-byte repeat thus share no record, no cell
and no group: the first is a lone first record of
a 2-record cell in the small group, the second a
full 27-record interior run of a 28-record cell in
the other small group; their A words differ only
in byte 2 (177 against 178), their B words
likewise, and both keep B byte 0 = 20.

## Next

Slice 4.142: the missing lattice slots inside the
15 repeating families read against the whole gap-2
population (what occupies each unoccupied slot —
another family's row, a singleton family's row, or
no gap-2 row at that index at all); the B-side
mirror of the skipped positions (the acts between
the same run acts in context B, classified the
same way, with the 19 A-side skipped acts'
corpus-wide occurrence lists); and B byte 0
against the four three-byte sub-keys wed to status
AND group jointly, the status-wed tests re-run
inside the SAME-only and DIFF-only subsets, and
the two (byte 1, byte 2, byte 3) status-wed
violating repeats re-read against A byte 0.
Mechanisms NOT PROVEN.
