# The channel mapping is not a function of the skipped acts either — not of their sizes (the single size 32784 carries both (2→0) and (0→1) at gaps 3, 5 and 6), not of their offset residues mod 512 (residue 0 carries all three mappings at gaps 3, 5, 6 and 7), and not of their count (one skipped act carries all three mappings; four carry both the identity set and (0→1)) — while the skipped channels and the paired (size, channel) tuples earn exactly one agreeing repeat and no violating one (gaps 5 and 6, channel (0,) → (0,1)), a single repeat on eight gaps from which no determination is claimed; gaps 3 and 7's skipped acts are corpus-unique, occurring exactly once each in the whole seven-artifact corpus, in the blob 5ab3537d at their own gap positions and nowhere else. The 216 violating-cell pairs earn no rescue from the remaining record-level companions either — not one agreeing repeat among them: the per-record idx sequence (27 distinct keys, all 27 repeating and violating), the per-record in37 pattern (a single key — every record in the population is in37 False — violating over all 216), A byte 0 as a companion (33 distinct keys, 22 repeating, all violating), and the per-record (cidx, idx) sequence (27 distinct, all violating). And the two (byte1, byte2, byte3) base-group pair-pairs, read in full record by record, are twins separated by exactly two things: in each group the two pairs differ only in byte 0 (28 against 32 in group 1; 20 against 24 in group 2 — B byte 0 equal to A byte 0 in all four pairs) and in the cell (third components 1744 against 6944; 4336 against 9832), with all 27 records of a group identical in every field except the cell — 35 of 206 tabulated fields differing in each group, being the 8 pair-level byte-0/cell/records fields and the cell field of each of the 27 records — mechanisms NOT PROVEN (AES-NUM-146)

Slice 4.146, worked under `docs/TASK_CONTRACT_4.146.md`
(contract published in the 4.145 closing commit @
f7c90fc3). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child, no device run of
any kind. All findings below are taken from the
sha-verified raw output; the few derived counts marked
as such were computed at closing from the run's own
printed tables, never sampled.

## Run and closing record

hef146.py (the hef145 file verbatim as base plus the
new arms146) sha256
`81d08493bf3613a40ab63a9028edcd2d69a584ffe211de9b7f9013361d9102b0`
(663,244 B); arms146 sha256
`56e1a2991c9a3c324086553409677ecab31fa90ec7b7bb0b1d9d9dbfd5463ffe`
(12,966 B), its gzip sha256
`20d192f7373a3dd4e6c85372a0fa6e5439641ba4059b0bcdb0513fe53d8c6613`
(3,834 B). The arms were built locally by the
10-minute continuity worker. The crossing used the
per-part route banked in AES-NUM-141/142/143/144/145:
the gzipped arms were split into 440 B parts (9
parts), each part crossed as its own file.write with
its own sha256 gate — eight parts verified on-device
first try; one part (g_ah) was corrupted in
re-emission (a doubled padding character), rejected
by its gate uncommitted, and landed on verbatim
re-send. The assembled gzip, arms and hef146 sha256
all matched the VM exactly on-device, and the script
compiled on-device (py_compile OK). Exactly ONE
bounded host-side child was launched for the main
arms, in a detached tmux session with the contract
corpus argv (the six hailo-ollama blobs in glob
order, then MiniLM — the launch law recorded in the
contract). That child reproduced hef145.out
byte-for-byte (37,186 lines / 7,147,309 B, sha256
`f0613b1160e98f9f1092c2c6daf17458d6faa310fec6dd72064ef53ea4dd4310`,
cmp verified on-device) and then crashed at the
SAME inherited arms145 typo that closed the 4.145
main child (`status145(p)` for `status145(p145)` in
the separation dissection, TypeError, exit marker 1,
error channel 692 B) — the arms146 section was never
reached. Recorded here honestly, not reconstructed.
Following the labelled follow-up pattern established
by hef145b, the dissection was completed by
hef146b.py: the hef145 base with that single line
corrected (hef145fix sha256
`d7aa12fef3c0aeaa436cccce07baaff3b53955fe3afd2c6c2137c53a80600cbf`,
assembled on-device by a line-addressed sed of line
9615 only, sha256 verified on-device == VM) plus the
unchanged arms146, sha256
`879a193e4a0923fd6af8eb60326b534456a2ebf7a5762336205260803cf6a93c`
(663,253 B), compiled on-device. The follow-up child
finished with DONE146 as its output's last line,
exit marker 0, and the error channel empty. Its
output is 39,137 lines / 7,502,897 B, sha256
`4d4170c70434ece76a5294fe4930d35a14a1a519f6f49df21eb3846b133d927c`;
the first 37,186 lines are byte-identical to
hef145.out (cmp verified on-device), the corrected
arms145 dissection completes at lines 37,187–37,212
(ending DONE145), and the 4.146 section begins at
output line 37,213 and is 1,925 lines / 351,823 B,
sha256
`b0deedd8a21595e7d20b681e70f5c8c26242f613b87a47ae4b24f2e41910146a`
(section gz sha256
`88efa1d7ba5c93292c24038842dc55c4dfa9559af9c2cbefd728381437f8141f`,
kept on the Pi). Controls reproduce exactly: cells
55,902, observations 527,236, divergent triples
2,171, verdicts CONT 12,411 / BREAK 476 / INDET
2,365; lane-1 pairs 224 with 222 keys under both
control maps; shared single-positioned acts 689,
secondary runs 103, secondary long runs 7, secondary
internal gaps 431; gap controls 34 / 30 / 87; gap
records 8. Raw output kept on the Pi at
~/aesir-build/ (hef146.out, hef146.py, arms146.py,
hef146b.out, hef146b.py, hef145fix.py, section146.txt);
local lineage in ~/workspace/.verify-tmp/aesir146.

## (i) The mapping against the A-side skipped acts

All eight gaps were printed in full (run, step,
skipped acts on both sides, mapping set and paired
sequence). Each candidate skipped-act feature was
tested as a determinant of both the mapping set and
the full paired sequence, counted exactly over the
8 gaps; the two targets give identical verdicts for
every feature:

- A skipped sizes tuple: 6 distinct keys, 1
  repeating, 0 agreeing, 1 violating — the size
  tuple (32784,) is carried by gaps 3, 5 and 6 with
  targets ((2,0),) and ((0,1),): NOT a function.
- A skipped channels tuple: 7 distinct, 1
  repeating, 1 agreeing, 0 violating — the channel
  tuple (0,) repeats only at gaps 5 and 6, both
  ((0,1),). No violating repeat, but a single
  agreeing repeat on eight gaps earns no
  determination.
- A skipped offsets tuple: 8 distinct, 0 repeating
  — vacuous on these 8 gaps.
- A skipped offset residues mod 512: 5 distinct, 1
  repeating, 0 agreeing, 1 violating — the residue
  tuple (0,) is carried by gaps 3, 5, 6 and 7 with
  all three targets ((2,0),), ((0,1),), ((1,2),):
  NOT a function.
- A skipped offset residues mod 32784: 8 distinct,
  0 repeating — vacuous.
- A skipped paired (size, channel) tuples: 7
  distinct, 1 repeating, 1 agreeing, 0 violating —
  the pair tuple ((32784, 0),) repeats only at gaps
  5 and 6, both ((0,1),): the same single agreeing
  repeat as the channels alone.
- A skipped count: 4 distinct, 2 repeating, 0
  agreeing, 2 violating — count 1 is carried by
  gaps 3, 5, 6 and 7 with all three targets, and
  count 4 by gaps 4 and 8 with ((0,1),) against the
  identity set ((0,0), (1,1), (2,2)): NOT a
  function.
- Gap step within its run: 8 distinct, 0 repeating
  — vacuous.

Gaps 3 and 7's skipped acts read against the corpus
(a rebuilt act index over all 7 artifacts: 567,832
distinct acts, 745,849 occurrences): each of the
four acts — gap 3's A-side (788357120, 32784, 2) and
B-side (788357120, 32784, 0), gap 7's A-side
(789100544, 26128, 1) and B-side (789100544, 26128,
2) — occurs exactly once in the whole corpus, in
the blob 5ab3537d, at its own gap position (549 for
gap 3's acts, 580 for gap 7's). The skipped acts
have no second home in the corpus from which a
mapping could be read. Mechanisms NOT PROVEN.

## (ii) The 216 against the remaining companions

The eight violating cells are (20, 32720, 6796),
(6864), (6932), (7000), (7068), (7136), (7204) and
(7272) — 27 pairs each, 216 pairs in all, as in
AES-NUM-145. Over the 216, B byte 0 was tested as a
function of each remaining record-level companion
the contract named, counted exactly:

- per-record idx sequence: 27 distinct keys, 27
  repeating, 0 agreeing, 27 violating (every key
  holds exactly the 8 pairs of one idx, one per
  cell, with B byte 0 sets of 3–8 values);
- per-record in37 pattern: 1 distinct key, 1
  repeating, 0 agreeing, 1 violating — every record
  in the population carries in37 False, so the
  companion is constant here and its single key
  violates over all 216 pairs (26 distinct B byte 0
  values);
- A byte 0 as a companion: 33 distinct keys, 22
  repeating, 0 agreeing, 22 violating (the largest
  keys: A byte 0 128 with 46 pairs and 10 B byte 0
  values; 192 with 26 pairs and 11 values; 0 with
  28 pairs and 8 values);
- per-record (cidx, idx) sequence: 27 distinct
  keys, 27 repeating, 0 agreeing, 27 violating —
  the same partition shape as the idx sequence.

No companion earns a determination; no companion
earns even one agreeing repeat — the record-level
companion lane (AES-NUM-145's four and this slice's
four) is now exhausted at the single-companion
level, eight companions, zero agreeing repeats in
total. By the stated strongest-companion rule
(fewest violating keys, then most distinct keys)
the in37 pattern ranks first with its single
violating key — a ranking artefact of its
constancy, recorded as such, not a finding. The
216 pairs were printed in full once, grouped by
cell, under that companion in the raw section.
Mechanisms NOT PROVEN.

## (iii) The two base-group pair-pairs in full

The base (status, group, record count, (byte1,
byte2, byte3)) has 222 distinct values and exactly
2 multi-pair groups, both in group (14, 9992) with
status SAME and record count 27:

- Group 1, sub-key (1, 176, 128): pair 1 is
  A 1c01b080 → B 1c01b000 (byte 0 28, B byte 0 28,
  cell (14, 9992, 1744)); pair 2 is A 2001b080 →
  B 2001b000 (byte 0 32, B byte 0 32, cell
  (14, 9992, 6944)).
- Group 2, sub-key (1, 178, 128): pair 1 is
  A 1401b280 → B 1401b200 (byte 0 20, B byte 0 20,
  cell (14, 9992, 4336)); pair 2 is A 1801b280 →
  B 1801b200 (byte 0 24, B byte 0 24, cell
  (14, 9992, 9832)).

Read record by record side by side, the 27 records
of each group's two pairs are identical in every
field — cidx (101, 105, …, 205), idx (1…27), n
(28), centre (7, 11, …, 111), poscat ('interior'
through record 25, 'last' at record 26) and in37
(False) — except the cell, which differs at every
record by construction of the pairs' homes. The
differing-fields tables (206 fields each: 16
pair-level fields, the records tuple, and 27 × 7
record fields) read identically for both groups:
35 differing, 171 equal. The 35 are exactly the
A word, the B word, A byte 0, B byte 0, the cell,
the duplicated A byte 0 / B byte 0 entries, the
records tuple, and the cell field of each of the
27 records. In both groups byte 0 rises by 4 from
pair 1 to pair 2 (28→32; 20→24) and B byte 0
equals A byte 0 in all four pairs; the cell third
components rise by 5,200 (1744→6944) and 5,496
(4336→9832) respectively — two instances, recorded
as instances, never as a law. Every other field —
status, group, record count, bytes 1–3 of both
words, and all non-cell record fields — is equal.
Mechanisms NOT PROVEN.

## Next

Slice 4.147 — the per-gap channel mapping as a
function of the B-side skipped acts themselves and
of the joint A/B skipped tuples over all 8 gaps,
with gaps 3 and 7's skipped (offset, size) pairs
read against the corpus channel-blind; B byte 0
over the 216 violating-cell pairs against the
JOINT companions of the eight exhausted singles
((idx sequence, A byte 0), ((cidx, idx) sequence,
A byte 0), (in37 pattern, A byte 0), (idx sequence,
in37 pattern)); and the two pair-pairs' byte-0
step (+4 in both groups) and cell-third step
tested across every pair-pair sharing the
(byte1, byte2, byte3) sub-key alone over the full
224 pairs. Host/artifact analysis only — no
physical child.
