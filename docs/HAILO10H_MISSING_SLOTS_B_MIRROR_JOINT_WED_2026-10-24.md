# Every missing lattice slot inside the fifteen repeating doubly-wed families is occupied — no slot is empty in artifact cc9b9d1c's gap-2 population: 28 missing slots in total across four families (the [145…] family missing 1, the [146…] family missing 4, its sister family [158, 178, 242] missing 19 by the same lattice definition, and the [140…] family missing 4), of which 22 are occupied by another repeating family's row and 6 by a singleton family's row, and none by nothing. The [146…] and sister families are mutual: three of the [146…] family's four missing slots are the sister's whole set (as AES-NUM-141 found), and 18 of the sister's 19 missing slots are the [146…] family's own rows (the nineteenth, cidx 182, is the same singleton row that also fills the [146…] family's fourth slot). The B-side mirror of the skipped positions is exact: the B-side distance equals the A-side distance in all 8 non-unit secondary gaps, the 19 B-side skipped positions carry 19 acts that are ALL B-only (not in context A at all, each occurring exactly once in the whole corpus — in context B itself), and the 19 A-side skipped acts are likewise each corpus-unique (one occurrence each, in context A). And B byte 0 against the four three-byte sub-keys wed to status AND group jointly over the full 224 pairs still earns no determination: the three byte-0-containing keys are injective (224 distinct wed values, 0 repeating), and (byte 1, byte 2, byte 3) keeps exactly the same two violating repeats (both SAME, both group (14, 9992)); inside the SAME-only subset (44 pairs) the same pattern holds at subset scale (two keys injective, (byte 0, byte 1, byte 3) one agreeing repeat, (byte 1, byte 2, byte 3) the same two violating repeats), inside the DIFF-only subset (180 pairs) all four keys are injective (180 distinct, 0 repeating), and the two violating repeats re-read against A byte 0 show B byte 0 = A byte 0 in all four pairs (SAME, diff 0) — mechanisms NOT PROVEN (AES-NUM-142)

Slice 4.142, worked under `docs/TASK_CONTRACT_4.142.md`
(contract published in the 4.141 closing commit @
d04dcf3f). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child, no device run of
any kind. All findings below are taken from the
sha-verified raw output; the few derived counts marked
as such were computed at closing from the run's own
printed tables, never sampled.

## Run and closing record

hef142.py (the hef141 file verbatim as base — itself
the hef140/hef139/hef138/hef137/hef136/hef135/hef134/
hef133/hef132/hef131/hef130 lineage — plus the new
arms142) sha256
`ed731d83579c5e30c92e69b91626f3d9120453c36e76b1074f7d3e5e861c4246`
(587,743 B); arms142 sha256
`405e0cd610fc82afe0befcbc97f3e0832b38e5e1ac537bc034201a35e193eb98`
(14,109 B), its gzip sha256
`1317b58e25c7b27909af5f8dcd70a33a47af2772d9e7dcfd0a36b9c173aa1b61`
(4,007 B). The arms were built locally by the
10-minute continuity worker. The crossing used the
per-part route banked in AES-NUM-141 as the primary
path: the gzipped arms were split into 250 B parts
(17 parts), each part crossed as its own file.write
with its own sha256 gate — every part's sha256 was
verified on-device; two parts (g_af, g_ah) were
corrupted in re-emission on their first attempts,
were rejected by their gates, and landed clean when
re-sent one part at a time copied directly from the
manifest (the gate named each bad part; nothing
unverified was ever assembled). The assembled gzip
sha256 matched on-device (sha256sum -c OK), the
decompressed arms142 sha256 matched the VM's
exactly, the on-device hef141.py base sha256 matched
the VM's (`e346f344…`), and the assembled hef142.py
sha256 matched the VM's exactly before launch; it
compiled on-device (py_compile OK). Exactly ONE
bounded host-side child was launched, in a detached
tmux session on-device with the contract corpus argv
(the six hailo-ollama blobs in glob order, then
MiniLM — the launch law recorded in the contract);
it finished on-device (DONE142 is the output's last
line; the run's exit marker is 0; the error channel
carried nothing). The output is 33,992 lines /
6,500,779 B, sha256
`5934e6550cc2adf76ab6aefa1bb8c14dc84767318f32d50c20322633524736b4`;
the first 33,787 lines are byte-identical to
hef141.out (verified with cmp on-device), the base
having reproduced line-for-line. The 4.142 section
begins at output line 33,788 and is alone 205 lines
/ 54,714 B, sha256
`e327cc78fa8afc2f90e4be46dc5444eeca2d01c6acef76ee42f64e086a1b9c9c`
(section gz sha256
`9d0120966c485be312dbb4a2db796015b2cd4703488d49b7e46dfc66eb4f8cef`).
Controls EXACT (cells 55,902; obs 527,236; divergent
triples 2,171; verdicts CONT 12,411 / BREAK 476 /
INDET 2,365; lane-1 pairs 224; shared
single-positioned acts 689; secondary runs 103,
long runs 7, internal gaps 431; gap controls 34 /
30 / 87). Raw output kept on the Pi at
~/aesir-build/ (hef142.out, hef142.py, arms142.py,
section142.txt).

## (i) The missing lattice slots, read against the whole gap-2 population

For each of the 15 repeating doubly-wed families,
every lattice position (residue + step × k, k from
the family's minimum quotient to its maximum
quotient) not occupied by the family was printed,
and for each such missing slot, what occupies that
cidx among artifact cc9b9d1c's gap-2 rows (271 rows,
271 distinct cidx values — the repeating families
are all cc9b9d1c families, AES-NUM-140).

Eleven families miss nothing: the eight step-8 pure
progressions, the pure step-4 family [147…]
(quotients 36–60 consecutive), and the two two-row
families (steps 84 and 131 over quotient ranges of
width 1). Four families miss slots, 28 in total:

- [145…] residue 1, step 4: 1 missing slot, quotient
  45 = cidx 181 — occupied by a SINGLETON family's
  row (its key in full in the raw output; the row
  shares the family's gap-2 first tuple act and its
  length/left 256/231, differing in the loose
  distances (2, 10) against (2, 5)).
- [146…] residue 2, step 4: 4 missing slots,
  quotients 39/44/45/60 = cidx 158/178/182/242 —
  158, 178 and 242 occupied by rows of its sister
  family [158, 178, 242] (repeating), 182 occupied
  by a singleton row.
- The sister family [158, 178, 242] itself (3 rows,
  step 4 by gcd of differences 20 and 64, quotients
  39/44/60): 19 missing slots between its extreme
  quotients (162, 166, 170, 174, 182, 186, 190, 194,
  198, 202, 206, 210, 214, 218, 222, 226, 230, 234,
  238) — 18 of them occupied by the [146…] family's
  own rows (repeating), and 182 by the same
  singleton row that fills the [146…] family's
  fourth slot. (Derived: the sister's missing set is
  exactly the [146…] family's cidx set minus the
  three shared points, plus 182.)
- [140…] residue 0, step 4: 4 missing slots,
  quotients 36/40/45/46 = cidx 144/160/180/184 —
  160 occupied by the [160, 244] repeating family's
  row, 144/180/184 by singleton rows.

Totals over the 28 missing slots: another repeating
family's row 22, a singleton family's row 6, no
gap-2 row at that cidx 0. No missing slot is empty:
every unoccupied lattice position of every
repeating family is another family's context in the
same artifact. Any mechanism behind the mutual
[146…] ↔ sister occupation is NOT PROVEN.

## (ii) The B-side mirror of the skipped positions

Context A is artifact 5ab3537d cidx 86 (length 749);
context B is the same artifact's cidx 210 (length
751); 689 shared distinct acts (all controls as in
AES-NUM-139…141). For each of the 8 non-unit gaps
of the secondary long runs, every B-position
strictly between the same run acts was read exactly
as the A side was in AES-NUM-141.

The B-side distance between the gap's left and right
acts equals the A-side distance in all 8 gaps
(3, 6, 2, 5, 2, 2, 2, 5). The 19 B-side skipped
positions carry 19 acts, and the classification is
the perfect mirror of the A side: shared
single-positioned 0, in-A-but-not-single 0, not in
context A at all 19. Each of the 19 B-side acts
occurs exactly once in context B and — printed in
full in the raw output — exactly once in the whole
loaded corpus (its B occurrence is its only one).

The 19 A-side skipped acts' corpus-wide occurrence
lists, printed in full: every one of the 19 occurs
exactly once in the whole corpus, at its own
skipped position in context A (cidx 86, positions
444, 445, 452–456, 549, 557–560, 563, 568, 580,
733–736). So the skipped-position acts on both
sides are one-context, one-occurrence insertions:
the gaps in the shared-act runs are places where
each context carries its own private acts, never
shared acts displaced. Any mechanism is NOT PROVEN.

## (iii) B byte 0 wed to status and group jointly; the subsets; the re-read

Over the full 224 lane-1 pairs (status totals SAME
44 / DIFF 180; group sizes (20, 32720) 216,
(14, 9992) 5, (19, 7712) 3):

Joint (status, group) wed:
- (byte 0, byte 1, byte 2): 224 distinct wed values,
  0 repeating — injective.
- (byte 0, byte 1, byte 3): 224 distinct, 0
  repeating — injective.
- (byte 0, byte 2, byte 3): 224 distinct, 0
  repeating — injective.
- (byte 1, byte 2, byte 3): 222 distinct, 2
  repeating, both VIOLATING, both under
  (SAME, (14, 9992)): (1, 176, 128) -> {28, 32} and
  (1, 178, 128) -> {20, 24} — the same two repeats
  as under every earlier wed; neither the status
  wed nor the group wed nor both jointly split them.

Status-wed inside the SAME-only subset (44 pairs):
(byte 0, byte 1, byte 2) and (byte 0, byte 2, byte 3)
injective (44 distinct, 0 repeating);
(byte 0, byte 1, byte 3) 43 distinct, exactly 1
repeating and AGREEING — ('SAME', (20, 1, 128)) ->
20, the campaign's one agreeing repeat, both of
whose pairs live in this subset; (byte 1, byte 2,
byte 3) 42 distinct, 2 repeating, both VIOLATING —
the same two values as above.

Status-wed inside the DIFF-only subset (180 pairs):
all four keys injective (180 distinct wed values,
0 repeating each). Every repeat in the status-wed
tests lives in the SAME subset.

The two (byte 1, byte 2, byte 3) status-wed
violating repeats re-read against A byte 0, all
four pairs printed in full: in every pair B byte 0
equals its own A byte 0 (28 -> 28, 32 -> 32,
20 -> 20, 24 -> 24; status SAME, diff 0, group
(14, 9992), 27 records each). The violating repeats
are pairs whose A words differ only in byte 0
itself: the key that excludes byte 0 cannot see
the one byte that differs, and the value it must
predict is exactly that byte. No determination of
B byte 0 by any tested three-byte sub-key, under
any tested wed, exists. Mechanisms NOT PROVEN.

## Next

Slice 4.143: the missing-slot occupants as a
population (each occupant row's own gap-2 tuple
against its slot family's tuple — shared acts,
length/left, loose distances; the six singleton
occupants' keys against their slot families; the
shared slot 182 read in full); the gap-by-gap
insertion comparison (the A-side and B-side
skipped acts at the same gap side by side — offset
and size/channel patterns per gap); and B byte 0
against the four three-byte sub-keys wed to status,
group AND the pair's record count jointly, the
joint-wed tests inside the SAME-only subset, and
the two violating repeats re-read against their
records' cells and centres. Mechanisms NOT PROVEN.
