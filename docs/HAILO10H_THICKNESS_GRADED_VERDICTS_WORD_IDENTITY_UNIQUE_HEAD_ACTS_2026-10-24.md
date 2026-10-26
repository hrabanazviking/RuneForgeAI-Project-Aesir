# Thickness-graded continuation verdicts, the 37/96 differing words identified across artifacts, and the three unshifted heads' unique acts searched corpus-wide in cc9b9d1c: EVERY continuation break rests on a common sequence of length 1 or 2 — at common length 3 or more there are NO breaks at all (0 in 11,952 extras), all 373 unanimous breaks sit on a single shared instance and all 103 AP breaks on a two-instance sequence; B's differing word is NO other artifact's word at the same group in any of the 1,971 differing instances (0 at group, cell, same-cidx and same-idx level, the A word likewise 0 as control), the 28-instance first-instance pattern appears in no other artifact pair (indeed no other pair shares even one cell) and is wider than the 37's family inside the mirror pair itself (29 cells, 15 of them the unanimous family); 44 of the 60 27-differing cells share a group with the 37; and of the three heads' 21 unique-act entries, five acts — a 512-spaced run inside train 48 rank 2's head — occur NOWHERE else in cc9b9d1c, while only three distinct unique acts head any other context (AES-NUM-118)

Slice 4.118, worked under `docs/TASK_CONTRACT_4.118.md`
(contract committed first @ 822d84d4). Host/artifact analysis
only, on Mimir (purpleviking1) — no physical child, no
device run of any kind.

## Run and transfer record

hef118.py was built locally as the hef117.py base extraction
(everything before the 4.117 arms marker, inherited unchanged)
plus new arms in hef118_arms.py (sha256
`9e48424bcc75ca573d10f31d18bcb66706dccc920a2b7e67df1714094170e384`),
giving hef118.py sha256
`18e53031beb9117160590e63fbba1b7f5ef22899b9a248d67fa085829139b5dd`.
Transfer followed the proven one-shot receiver pattern: a
397 B receiver (recv118.py, sha256
`b12f086af1260e573f914af69f934333ba17db49ac9c1ef63ff0c5b7d521f7a6`)
landed by sha-verified file.write; a child subagent held it
in the foreground on the device; the VM POSTed the 63,134 B
gzip through the tunnel proxy (`saved:63134`). On-device
sha256 of the gzip
(`cc2bcbc24caaedae5cfafe27fb4c32b039d25322924c4a54c0dd31d34a84e392`)
and of the decompressed script matched the local values
exactly; py_compile OK on-device. The first (detached)
launch's invoke hit the node timeout, but the run itself
survived detached on-device — verified alive by process
check before any further step, never duplicated — and
completed to DONE118. The output (13,730 lines, 1,878,488 B,
sha256
`12a9e0602103484951b1d11c6063b9c85d91613467c73d44cc48087a5785f3a3`)
was retrieved gzipped (served one-shot from the device,
fetched through the proxy) with gz sha256
`192ae39d65f74b9d7d81efe99fe6aa1886e7169d7762fe992381374be91b0e5e`
verified identical on both sides.

## Controls

All inherited controls reproduce exactly. The inherited
DONE105 / DONE106 / DONE107 / DONE108 markers sit at the
same output lines as the 4.116/4.117 runs (3,576 / 3,670 /
3,701 / 3,910). Shared enumeration: groups ≥2 54,995;
groups ≥1 common 1,323; cells 55,902; observations 527,236;
distinct ladder 11,242; unanimous 39,673; AP cells 2,584
with the same step histogram {0: 352, 2: 26, 3: 489, 4:
741, 6: 164, 8: 350, 9: 217, 12: 200, 24: 34, 40: 11};
non-AP 4,148 (ordered 317 / multi 298 / set 174); ≥8 cells
25,566, unanimous 18,286, 29 centres, centre-1 561; the
target cell (773470cd pos 9 size 32784 off 11608) appears
in ≥8 unanimous exactly once with centre word ff010000.
Divergent triples 2,171 (both-differ 1,997 / A-only-extra
92 / B-only-extra 82; extras 15,252 = A 7,164 + B 8,088;
common instances 15,488, centres agreeing 15,488/15,488);
verdict totals CONT 12,411 (A 5,647 / B 6,764), BREAK 476
(A 205 / B 271), INDET 2,365 (A 1,312 / B 1,053); structure
× verdict UNANIMOUS 11,795/373, NONAP 599/0/1,500, AP
17/103, SINGLE 865 INDET; triple grades all-CONT 1,679 /
any-BREAK 72 / INDET 420. Shared cells: centres equal
2,981/2,981, words equal 2,885/2,981; the 37 reproduced
(37 / reverse 0), the 96 reproduced with 1,971 differing
instances (535 of them in the 37), centre lane differing
0/1,971. The cc9b9d1c fit reproduces exactly: union 929,
target (0, 304) refs 813, contexts 271, start distribution
{4: 1, 5: 47, 6: 31, 7: 83, 8: 56, 9: 44, 10: 9}, 217
in-train rows, the same 10 exception identities, trains
48/50 CONST_DOM 7/7.

## (i) Thickness-graded continuation verdicts

Common-sequence lengths over the 2,171 divergent triples
take only the values {0, 1, 2, 3, 4, 6, 7, 8, 9, 10, 11,
13, 25} (166 triples at 0; 315 at 1; 68 at 2; 147 at 3–4;
1,475 at 6+). Re-grading every extra's 4.117 verdict by
the thickness of its triple's common sequence:

| stratum (common length) | extras | CONT | BREAK | INDET |
|---|---|---|---|---|
| 0 | 865 | 0 | 0 | 865 |
| 1 | 1,627 | 1,254 | 373 | 0 |
| 2 | 808 | 705 | 103 | 0 |
| 3–5 | 1,451 | 1,182 | 0 | 269 |
| 6+ | 10,501 | 9,270 | 0 | 1,231 |

**The headline: every one of the 476 breaks rests on a
common sequence of length 1 or 2.** At common length ≥3
there is not a single break in 11,952 extras (CONT 10,452,
INDET 1,500, BREAK 0). The AES-NUM-117 caveat is therefore
not a qualification on the continuation finding — it IS
the finding's boundary:

- UNANIMOUS commons: at length 1, extras continue 1,254 /
  1,627 (77.1%) and break 373; at length ≥2, extras
  continue 10,541 / 10,541 (100.0%) with zero breaks
  (length 2: 696/696; 3–5: 1,166/1,166; 6+: 8,679/8,679).
  A "unanimous break" is a property of a single shared
  instance, full stop.
- AP commons: all 120 AP extras sit at length 2 (112) or
  length 7 (8). At length 7 all 8 extras continue. At
  length 2, 103 break and 9 continue — a two-point
  "progression" is one difference, and its extrapolation
  is the weakest evidence in the arm (see below).
- NONAP commons never break at any thickness (599 CONT /
  1,500 INDET / 0 BREAK, as in 4.117).
- Triple grades by stratum: length 0 — 166 INDET; length
  1 — 253 all-CONT / 62 any-BREAK; length 2 — 58 all-CONT
  / 10 any-BREAK; length 3–5 — 119 all-CONT / 28 INDET;
  length 6+ — 1,249 all-CONT / 226 INDET. All 72 any-BREAK
  triples are length 1 (62) or length 2 (10).

**The AP breaks in full.** The 103 AP breaks live in
exactly 10 triples, all with two-instance commons:

- Nine triples in group (71, 19392) (offsets 96, 2624,
  3120, 10440, 11008, 11576, 16168, 16680, 19232), common
  centres (38, 44), step 6, lenA 5 / lenB 11. Each carries
  the same 12 extras: A-side cidx 13 (centre 14), 22 (23),
  79 (80); B-side cidx 19 (20), 25 (26), 28 (29), 31 (32),
  34 (35), 40 (41), 49 (50), 52 (53), 55 (56). Eleven break
  — e.g. B cidx 40 centre 41 vs AP-expected 44 from its
  common flanks (37→38, 43→44); A cidx 13 centre 14 vs −4
  extrapolated backwards from successor 37 (38) — and one
  continues in every triple (B cidx 49, centre 50, exactly
  the step-6 extrapolation of 44). 9 × 11 = 99 breaks.
- One triple (15, 32608, 29184), common centres (0, 38),
  step 38, lenA 3 / lenB 5: all four extras carry centre 0
  (A cidx 89; B cidx 92, 208, 213) against AP expectations
  38 / 76 / 76 / 114 — 4 breaks.

Every APBRK line (triple, group, common length and
sequence, step, side, cidx, centre, own and merged
positions, predecessor/successor cidx and centres, and
the expected-vs-actual reason) is printed in full in the
run output. The AP "breaks" grade exactly what they rest
on: a step read off ONE difference between two shared
instances. They are recorded as breaks of that two-point
extrapolation, not as breaks of any thicker sequence —
no thicker AP sequence breaks anywhere (length-7 AP:
8/8 CONT).

**The 72 any-BREAK triples in full.** All 72 are listed
in the run output with group, common length, structure,
common centres, side lengths, every extra's position and
centre, and each break's reason. By group: (25, 29528) —
11 triples, common centre (43,), 11 breaks each (121);
(15, 26064) — 11 triples, common (32,), 9 each (99);
(71, 19392) — the 9 AP triples above (99); (25, 31160) —
9 triples, common (51,), 9 each (81); (11, 26144) — 10
triples, common (122,), 2 each (20); (21, 8264) — 7
triples, common (85,), 3 each (21); (17, 32720) — 7
triples, common (40,), 2 each (14); (18, 6816) — 4
triples, common (40,), 2 each (8); (17, 5904) — 3 triples,
common (85,), 3 each (9); (15, 32608) — the 1 AP triple
(4). Total 72 triples, 476 breaks. The 62 unanimous
any-BREAK triples share the same shape: exactly ONE common
instance, and EVERY extra in the triple breaks (no mixed
triple) — e.g. (25, 29528, 10192): the single shared
instance carries centre 43 while A extras carry 3, 11, 35,
47, 63, 67 and B extras 27, 31, 39, 55, 71; or (11, 26144,
12016): common centre 122, extras 93 (A) and 90 (B), the
very triple AES-NUM-117 printed as its example. Against a
single shared centre, an extra "breaks" by merely carrying
any other centre — with 9–11 extras per triple that is
close to automatic. These verdicts are honest counts
under the contract's rules, graded here at their true
weight: thin-common verdicts are NOT evidence of the same
weight as thick ones, and the thick population (≥3) is
break-free without exception.

**Grade.** Strata, counts and the full anatomies:
measured on the complete divergent-triple population.
Why membership diverges: NOT PROVEN, as before.

## (ii) The 37/96 differing words across artifacts

Method, stated once for all four levels: a differing
instance's "word" is its full five-word neighbourhood
tuple (the unit the 4.117 anatomy compared). The other
artifacts are the five corpus artifacts outside the
mirror pair (0856a10c, 0a0d378c, 76c3a8ff, MiniLM,
cc9b9d1c). For each differing instance, B's word (and,
as control, A's word) was searched in each other
artifact (a) at group level — anywhere in that artifact's
analysable cells of the same (pos, segsize) group; (b) at
cell level — inside a cell at the same (pos, segsize,
off) coordinates; (c) at the same cidx within such a
cell; (d) at the same instance index within such a cell.

**Result: zero, at every level, for every instance.**
B's differing word occurs in another artifact at the same
group for 0 of 1,971 differing instances (per other
artifact: 0/1,971 in each of the five), at cell level
0/1,971, same-cidx 0/1,971, same-idx 0/1,971. The count
distribution of "number of other artifacts carrying the
word" is {0: 1,971} at all four levels. The A word as
control is likewise 0/1,971 at all four levels — neither
side's word is a third artifact's word; the differing
words are local to the mirror pair. The same zero holds
inside the 37 alone (0/535 at all levels, both words) and
in the other 59 cells of the 96 (0/1,436). Distinct
differing words: 1,350 distinct B words (1,354 distinct
A words; 1,354 distinct (cell, B word) pairs) over the
1,971 instances. Per differing group, B group-level ≥1 is
0 in all seven groups: (12, 32728) 623 instances, (13,
32760) 270, (14, 9992) 513, (19,
...[truncated 10216 chars]